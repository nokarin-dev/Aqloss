use crate::{decoder::Decoder, output::AudioOutput, resampler::Resampler, PlaybackPosition};
use anyhow::{anyhow, Result};
use std::sync::{
    atomic::{AtomicBool, AtomicU64, Ordering},
    Arc, Mutex, OnceLock,
};
use std::thread;
use std::time::Duration;

static ENGINE: OnceLock<Arc<Mutex<AudioEngine>>> = OnceLock::new();

struct PlayFlags {
    alive: AtomicBool,
    playing: AtomicBool,
    seek_us: AtomicU64,
    seek_done: AtomicBool,
}

impl PlayFlags {
    fn new() -> Arc<Self> {
        Arc::new(Self {
            alive: AtomicBool::new(false),
            playing: AtomicBool::new(false),
            seek_us: AtomicU64::new(0),
            seek_done: AtomicBool::new(true),
        })
    }
}

pub struct AudioEngine {
    output: AudioOutput,
    decoder: Option<Arc<Mutex<Decoder>>>,
    resampler: Option<Resampler>,
    volume: f32,
    dec_sample_rate: u32,
    dec_channels: u32,
    flags: Arc<PlayFlags>,
}

unsafe impl Send for AudioEngine {}
unsafe impl Sync for AudioEngine {}

impl AudioEngine {
    pub fn init() -> Result<()> {
        let output = AudioOutput::new()?;
        let mode = if output.exclusive { "WASAPI Exclusive (bit-perfect)" } else { "Shared (system mixer)" };
        eprintln!("[aqloss] audio output: {mode} @ {}Hz {}ch", output.sample_rate, output.channels);

        let engine = Self {
            output,
            decoder: None,
            resampler: None,
            volume: 1.0,
            dec_sample_rate: 44100,
            dec_channels: 2,
            flags: PlayFlags::new(),
        };
        ENGINE
            .set(Arc::new(Mutex::new(engine)))
            .map_err(|_| anyhow!("AudioEngine already initialized"))?;
        Ok(())
    }

    pub fn get_spectrum_data(&self, n: usize) -> Vec<f32> {
        if n == 0 { return vec![]; }
        let ring = self.output.ring.lock().unwrap();
        let samples: Vec<f32> = ring.iter().copied().collect();
        drop(ring);
        if samples.is_empty() { return vec![0.0; n]; }

        let chunk = (samples.len() / n).max(1);
        (0..n)
            .map(|i| {
                let start = i * chunk;
                let end = ((i + 1) * chunk).min(samples.len());
                if start >= end { return 0.0; }
                let rms = (samples[start..end]
                    .iter()
                    .map(|s| s * s)
                    .sum::<f32>()
                    / (end - start) as f32)
                    .sqrt();
                rms.clamp(0.0, 1.0)
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

        self.output.ring.lock().unwrap().clear();
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
        self.output.ring.lock().unwrap().clear();
        Ok(())
    }

    pub fn seek(&mut self, position_secs: f64) -> Result<()> {
        let dec = self.decoder.as_ref().ok_or_else(|| anyhow!("No track loaded"))?;
        let was_playing = self.flags.playing.load(Ordering::SeqCst);
        self.flags.playing.store(false, Ordering::SeqCst);
        thread::sleep(Duration::from_millis(20));
        dec.lock().unwrap().seek(position_secs)?;
        if let Some(ref mut rs) = self.resampler {
            rs.reset();
        }
        self.output.ring.lock().unwrap().clear();
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
        let dec = self.decoder.as_ref().ok_or_else(|| anyhow!("No track loaded"))?;
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
            // Poll until the decode thread actually exits instead of a fixed sleep.
            // Prevents the race where play() fires before the old thread fully stops.
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

fn decode_loop(engine_arc: Arc<Mutex<AudioEngine>>, flags: Arc<PlayFlags>) {
    let (target_fill, out_channels) = {
        let e = engine_arc.lock().unwrap();
        let fill = e.output.sample_rate as usize * e.output.channels as usize / 5;
        (fill, e.output.channels)
    };

    loop {
        if !flags.alive.load(Ordering::SeqCst) { break; }
        if !flags.playing.load(Ordering::SeqCst) {
            thread::sleep(Duration::from_millis(10));
            continue;
        }

        let ring_len = {
            let e = engine_arc.lock().unwrap();
            let x = e.output.ring.lock().unwrap().len(); x
        };
        if ring_len >= target_fill {
            thread::sleep(Duration::from_millis(5));
            continue;
        }

        let result = {
            let e = engine_arc.lock().unwrap();
            if let Some(ref dec_arc) = e.decoder {
                let dec_arc = dec_arc.clone();
                drop(e);
                let mut dec = dec_arc.lock().unwrap();
                dec.next_packet()
            } else {
                break;
            }
        };

        match result {
            Ok(Some(raw_samples)) => {
                let mut e = engine_arc.lock().unwrap();
                let volume = e.volume;
                let dec_ch = e.dec_channels;

                let resampled = if let Some(ref mut rs) = e.resampler {
                    rs.process(&raw_samples).unwrap_or(raw_samples)
                } else {
                    raw_samples
                };

                let converted = adapt_channels(&resampled, dec_ch, out_channels);
                let mut ring = e.output.ring.lock().unwrap();
                ring.reserve(converted.len());
                for s in converted {
                    ring.push(s * volume);
                }
            }

            Ok(None) => {
                let mut e = engine_arc.lock().unwrap();
                let volume = e.volume;
                let dec_ch = e.dec_channels;

                if let Some(ref mut rs) = e.resampler {
                    if let Ok(tail) = rs.flush() {
                        if !tail.is_empty() {
                            let converted = adapt_channels(&tail, dec_ch, out_channels);
                            let mut ring = e.output.ring.lock().unwrap();
                            for s in converted { ring.push(s * volume); }
                        }
                    }
                }
                drop(e);

                loop {
                    let rem = engine_arc.lock().unwrap().output.ring.lock().unwrap().len();
                    if rem == 0 { break; }
                    thread::sleep(Duration::from_millis(10));
                }

                flags.playing.store(false, Ordering::SeqCst);
                // Mark alive=false LAST so stop_thread() polling detects exit correctly
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

fn adapt_channels(input: &[f32], src: u32, dst: u32) -> Vec<f32> {
    if src == dst || input.is_empty() { return input.to_vec(); }
    match (src, dst) {
        (1, 2) => input.iter().flat_map(|&s| [s, s]).collect(),
        (2, 1) => input.chunks_exact(2).map(|c| (c[0] + c[1]) * 0.5).collect(),
        _ => input.to_vec(),
    }
}
