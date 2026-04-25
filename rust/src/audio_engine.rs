use crate::{decoder::Decoder, output::AudioOutput, resampler::Resampler, PlaybackPosition};
use anyhow::{anyhow, Result};
use ringbuf::traits::Producer;
use std::sync::{
    atomic::{AtomicBool, AtomicU64, Ordering},
    Arc, Mutex, OnceLock,
};
use std::thread;
use std::time::Duration;

static ENGINE: OnceLock<Arc<Mutex<AudioEngine>>> = OnceLock::new();

// Play flags
struct PlayFlags {
    alive: AtomicBool,
    playing: AtomicBool,
    seek_pending: AtomicBool,
}

impl PlayFlags {
    fn new() -> Arc<Self> {
        Arc::new(Self {
            alive: AtomicBool::new(false),
            playing: AtomicBool::new(false),
            seek_pending: AtomicBool::new(false),
        })
    }
}

// Spectrum ring
const SPECTRUM_BUF_FRAMES: usize = 4096;

pub struct AudioEngine {
    output: AudioOutput,
    decoder: Option<Arc<Mutex<Decoder>>>,
    resampler: Option<Resampler>,
    volume: f32,
    smooth_volume: f32,
    dec_sample_rate: u32,
    dec_channels: u32,
    flags: Arc<PlayFlags>,
    spectrum_buf: Arc<Mutex<Vec<f32>>>,
    spectrum_write_pos: Arc<AtomicU64>,
}

unsafe impl Send for AudioEngine {}
unsafe impl Sync for AudioEngine {}

const VOLUME_RAMP_RATE: f32 = 0.002;

impl AudioEngine {
    pub fn init() -> Result<()> {
        let output = AudioOutput::new()?;
        let mode = if output.exclusive {
            "WASAPI Exclusive (bit-perfect)"
        } else {
            "Shared (system mixer)"
        };
        eprintln!(
            "[aqloss] audio output: {mode} @ {}Hz {}ch",
            output.sample_rate, output.channels
        );

        let engine = Self {
            output,
            decoder: None,
            resampler: None,
            volume: 1.0,
            smooth_volume: 1.0,
            dec_sample_rate: 44100,
            dec_channels: 2,
            flags: PlayFlags::new(),
            spectrum_buf: Arc::new(Mutex::new(vec![0.0f32; SPECTRUM_BUF_FRAMES])),
            spectrum_write_pos: Arc::new(AtomicU64::new(0)),
        };
        ENGINE
            .set(Arc::new(Mutex::new(engine)))
            .map_err(|_| anyhow!("AudioEngine already initialized"))?;
        Ok(())
    }

    // Spectrum analysis
    pub fn get_spectrum_data(&self, n: usize) -> Vec<f32> {
        if n == 0 {
            return vec![];
        }

        let buf = self.spectrum_buf.lock().unwrap();
        let len = buf.len();

        let ch = self.output.channels as usize;
        let frames = len / ch;
        let mono: Vec<f32> = (0..frames)
            .map(|f| {
                let base = f * ch;
                buf[base..base + ch].iter().sum::<f32>() / ch as f32
            })
            .collect();

        let global_rms = (mono.iter().map(|s| s * s).sum::<f32>() / mono.len() as f32).sqrt();
        if global_rms < 1e-6 {
            return vec![0.0; n];
        }

        let frames_f = frames as f32;
        (0..n)
            .map(|i| {
                let t0 = (i as f32 / n as f32).powf(1.8);
                let t1 = ((i + 1) as f32 / n as f32).powf(1.8);
                let start = (t0 * frames_f) as usize;
                let end = ((t1 * frames_f) as usize).min(frames);

                if start >= end {
                    return 0.0;
                }

                let rms = (mono[start..end].iter().map(|s| s * s).sum::<f32>()
                    / (end - start) as f32)
                    .sqrt();

                (rms / (global_rms * 2.0 + 1e-9)).clamp(0.0, 1.0)
            })
            .collect()
    }

    pub fn global() -> Arc<Mutex<Self>> {
        ENGINE.get().expect("AudioEngine not initialized").clone()
    }

    pub fn global_opt() -> Option<Arc<Mutex<Self>>> {
        ENGINE.get().cloned()
    }

    pub fn is_exclusive(&self) -> bool {
        self.output.exclusive
    }

    // Load
    pub fn load(&mut self, path: &str) -> Result<()> {
        self.stop_thread();
        let dec = Decoder::open(path)?;
        let src_rate = dec.sample_rate();
        let src_ch = dec.channels();
        let dst_rate = self.output.sample_rate;

        self.dec_sample_rate = src_rate;
        self.dec_channels = src_ch;

        self.resampler = if src_rate != dst_rate {
            Some(Resampler::new(src_rate, dst_rate, src_ch)?)
        } else {
            None
        };

        {
            let mut sb = self.spectrum_buf.lock().unwrap();
            sb.fill(0.0);
        }
        self.spectrum_write_pos.store(0, Ordering::Relaxed);

        self.decoder = Some(Arc::new(Mutex::new(dec)));
        Ok(())
    }

    pub fn play(&mut self) -> Result<()> {
        if self.decoder.is_none() {
            return Err(anyhow!("No track loaded"));
        }
        if self.flags.alive.load(Ordering::SeqCst) {
            self.flags.playing.store(true, Ordering::SeqCst);
            return Ok(());
        }
        self.start_thread();
        Ok(())
    }

    pub fn pause(&mut self) -> Result<()> {
        self.flags.playing.store(false, Ordering::SeqCst);
        Ok(())
    }

    pub fn stop(&mut self) -> Result<()> {
        self.stop_thread();
        self.decoder = None;
        self.resampler = None;
        self.spectrum_buf.lock().unwrap().fill(0.0);
        Ok(())
    }

    pub fn seek(&mut self, position_secs: f64) -> Result<()> {
        let dec = self
            .decoder
            .as_ref()
            .ok_or_else(|| anyhow!("No track loaded"))?;

        let was_playing = self.flags.playing.load(Ordering::SeqCst);
        self.flags.playing.store(false, Ordering::SeqCst);
        self.flags.seek_pending.store(true, Ordering::SeqCst);

        thread::sleep(Duration::from_millis(15));

        dec.lock().unwrap().seek(position_secs)?;

        if let Some(ref mut rs) = self.resampler {
            rs.reset();
        }

        self.spectrum_buf.lock().unwrap().fill(0.0);

        self.flags.seek_pending.store(false, Ordering::SeqCst);

        if was_playing {
            self.flags.playing.store(true, Ordering::SeqCst);
        }
        Ok(())
    }

    pub fn set_volume(&mut self, volume: f32) -> Result<()> {
        self.volume = volume.clamp(0.0, 1.0);
        Ok(())
    }

    pub fn get_position(&self) -> Result<PlaybackPosition> {
        let dec = self
            .decoder
            .as_ref()
            .ok_or_else(|| anyhow!("No track loaded"))?;
        let dec = dec.lock().unwrap();
        Ok(PlaybackPosition {
            position_secs: dec.position_secs(),
            duration_secs: dec.duration_secs(),
            sample_rate: dec.sample_rate(),
            bit_depth: dec.bit_depth(),
        })
    }

    pub fn is_playing(&self) -> bool {
        self.flags.playing.load(Ordering::SeqCst)
    }

    fn stop_thread(&mut self) {
        if self.flags.alive.load(Ordering::SeqCst) {
            self.flags.playing.store(false, Ordering::SeqCst);
            self.flags.alive.store(false, Ordering::SeqCst);
            let mut waited_ms = 0u32;
            while self.flags.alive.load(Ordering::SeqCst) && waited_ms < 500 {
                thread::sleep(Duration::from_millis(5));
                waited_ms += 5;
            }
        }
    }

    fn start_thread(&mut self) {
        let engine_arc = Self::global();
        self.flags.alive.store(true, Ordering::SeqCst);
        self.flags.playing.store(true, Ordering::SeqCst);
        let flags = self.flags.clone();
        thread::spawn(move || decode_loop(engine_arc, flags));
    }
}

// Soft-clipping
#[inline(always)]
fn soft_clip(x: f32) -> f32 {
    if x >= 3.0 {
        return 1.0;
    }
    if x <= -3.0 {
        return -1.0;
    }
    let x2 = x * x;
    x * (27.0 + x2) / (27.0 + 9.0 * x2)
}

// Decode loop
fn decode_loop(engine_arc: Arc<Mutex<AudioEngine>>, flags: Arc<PlayFlags>) {
    let (target_fill, out_channels, is_exclusive, ring_capacity, spectrum_buf, spectrum_pos) = {
        let e = engine_arc.lock().unwrap();
        let sr = e.output.sample_rate as usize;
        let ch = e.output.channels as usize;
        (
            sr * ch,
            ch as u32,
            e.output.exclusive,
            sr * ch * 2,
            e.spectrum_buf.clone(),
            e.spectrum_write_pos.clone(),
        )
    };

    loop {
        if !flags.alive.load(Ordering::SeqCst) {
            break;
        }

        if !flags.playing.load(Ordering::SeqCst) {
            thread::sleep(Duration::from_millis(10));
            continue;
        }

        let vacant = engine_arc.lock().unwrap().output.ring_vacant();
        let filled = ring_capacity.saturating_sub(vacant);

        if filled >= target_fill {
            thread::sleep(Duration::from_millis(5));
            continue;
        }

        let dec_arc = {
            let e = engine_arc.lock().unwrap();
            match e.decoder.as_ref() {
                Some(d) => d.clone(),
                None => break,
            }
        };

        let result = dec_arc.lock().unwrap().next_packet();

        match result {
            Ok(Some(raw_samples)) => {
                let mut e = engine_arc.lock().unwrap();

                let target_vol = e.volume;
                let dec_ch = e.dec_channels;

                let resampled = if let Some(rs) = e.resampler.as_mut() {
                    rs.process(&raw_samples).unwrap_or(raw_samples)
                } else {
                    raw_samples
                };

                let converted = adapt_channels(&resampled, dec_ch, out_channels);

                {
                    let mut sb = spectrum_buf.lock().unwrap();
                    let buf_len = sb.len();
                    let pos = spectrum_pos.load(Ordering::Relaxed) as usize;
                    for (k, &s) in converted.iter().enumerate() {
                        sb[(pos + k) % buf_len] = s;
                    }
                    spectrum_pos.store(
                        ((pos + converted.len()) % buf_len) as u64,
                        Ordering::Relaxed,
                    );
                }

                let mut smooth = e.smooth_volume;

                let pure_passthrough =
                    is_exclusive || (target_vol >= 1.0 && (smooth - 1.0).abs() < VOLUME_RAMP_RATE);

                {
                    let mut prod = e.output.producer.lock().unwrap();

                    if pure_passthrough {
                        prod.push_slice(&converted);
                    } else {
                        let mut tmp = Vec::with_capacity(converted.len());
                        for s in &converted {
                            if (smooth - target_vol).abs() > VOLUME_RAMP_RATE {
                                smooth += if target_vol > smooth {
                                    VOLUME_RAMP_RATE
                                } else {
                                    -VOLUME_RAMP_RATE
                                };
                            } else {
                                smooth = target_vol;
                            }
                            tmp.push(soft_clip(s * smooth));
                        }
                        prod.push_slice(&tmp);
                    }
                }

                e.smooth_volume = smooth;
            }

            Ok(None) => {
                let tail = {
                    let mut e = engine_arc.lock().unwrap();
                    let dec_ch = e.dec_channels;
                    let raw_tail = if let Some(rs) = e.resampler.as_mut() {
                        rs.flush().unwrap_or_default()
                    } else {
                        vec![]
                    };
                    if raw_tail.is_empty() {
                        vec![]
                    } else {
                        adapt_channels(&raw_tail, dec_ch, out_channels)
                    }
                };

                if !tail.is_empty() {
                    let mut e = engine_arc.lock().unwrap();
                    let target_vol = e.volume;
                    let mut smooth = e.smooth_volume;
                    let pure_passthrough = is_exclusive
                        || (target_vol >= 1.0 && (smooth - 1.0).abs() < VOLUME_RAMP_RATE);

                    let mut prod = e.output.producer.lock().unwrap();
                    if pure_passthrough {
                        prod.push_slice(&tail);
                    } else {
                        let mut tmp = Vec::with_capacity(tail.len());
                        for s in &tail {
                            if (smooth - target_vol).abs() > VOLUME_RAMP_RATE {
                                smooth += if target_vol > smooth {
                                    VOLUME_RAMP_RATE
                                } else {
                                    -VOLUME_RAMP_RATE
                                };
                            } else {
                                smooth = target_vol;
                            }
                            tmp.push(soft_clip(s * smooth));
                        }
                        prod.push_slice(&tmp);
                    }
                    drop(prod);
                    e.smooth_volume = smooth;
                }

                loop {
                    let vacant = engine_arc.lock().unwrap().output.ring_vacant();
                    if vacant >= ring_capacity {
                        break;
                    }
                    thread::sleep(Duration::from_millis(5));
                }

                flags.playing.store(false, Ordering::SeqCst);
                flags.alive.store(false, Ordering::SeqCst);
                break;
            }

            Err(e) => {
                eprintln!("[decoder] error: {e}");
                flags.playing.store(false, Ordering::SeqCst);
                flags.alive.store(false, Ordering::SeqCst);
                break;
            }
        }
    }
}

// Channel layout conversion
fn adapt_channels(input: &[f32], src: u32, dst: u32) -> Vec<f32> {
    if src == dst || input.is_empty() {
        return input.to_vec();
    }
    match (src, dst) {
        (1, 2) => input.iter().flat_map(|&s| [s, s]).collect(),
        (2, 1) => input
            .chunks_exact(2)
            .map(|c| (c[0] + c[1]) * std::f32::consts::FRAC_1_SQRT_2)
            .collect(),
        (src_ch, 2) if src_ch > 2 => {
            let ch = src_ch as usize;
            input
                .chunks_exact(ch)
                .flat_map(|frame| {
                    let l = frame.iter().step_by(2).sum::<f32>() / (ch as f32 / 2.0);
                    let r = frame.iter().skip(1).step_by(2).sum::<f32>() / (ch as f32 / 2.0);
                    [l, r]
                })
                .collect()
        }
        _ => input.to_vec(),
    }
}
