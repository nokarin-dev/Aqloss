use crate::{
    decoder::Decoder, eq::Equalizer, output::AudioOutput, resampler::Resampler, PlaybackPosition,
};
use anyhow::{anyhow, Result};
use ringbuf::traits::Producer;
use std::sync::{
    atomic::{AtomicBool, AtomicU64, Ordering},
    Arc, Mutex, OnceLock,
};
use std::thread;
use std::time::Duration;

static ENGINE: OnceLock<Arc<Mutex<AudioEngine>>> = OnceLock::new();

#[derive(Clone)]
pub struct DspConfig {
    pub replay_gain: f32,
    pub soft_clip: bool,
    pub skip_silence: bool,
    pub gapless: bool,
    pub crossfade_secs: f32,
}

impl Default for DspConfig {
    fn default() -> Self {
        Self {
            replay_gain: 1.0,
            soft_clip: true,
            skip_silence: false,
            gapless: true,
            crossfade_secs: 0.0,
        }
    }
}

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

const SPECTRUM_BUF: usize = 4096;
const VOL_RAMP: f32 = 0.003;
const SILENCE_THR: f32 = 0.0002;
const SILENCE_MIN: usize = 512;

pub struct AudioEngine {
    output: AudioOutput,
    decoder: Option<Arc<Mutex<Decoder>>>,
    next_decoder: Option<Arc<Mutex<Decoder>>>,
    resampler: Option<Resampler>,
    volume: f32,
    smooth_volume: f32,
    dec_sample_rate: u32,
    dec_channels: u32,
    flags: Arc<PlayFlags>,
    spectrum_buf: Arc<Mutex<Vec<f32>>>,
    spectrum_pos: Arc<AtomicU64>,
    dsp: Arc<Mutex<DspConfig>>,
    eq: Arc<Mutex<Equalizer>>,
}

unsafe impl Send for AudioEngine {}
unsafe impl Sync for AudioEngine {}

impl AudioEngine {
    // Init
    pub fn init_default() -> Result<()> {
        Self::store(AudioOutput::new_default()?)
    }

    pub fn init_with_device(device_id: &str, exclusive: bool) -> Result<()> {
        Self::store(AudioOutput::new_with_device(device_id, exclusive)?)
    }

    pub fn reinit(device_id: &str, exclusive: bool) -> Result<()> {
        let arc = ENGINE
            .get()
            .ok_or_else(|| anyhow!("Engine not initialized"))?;
        let mut e = arc.lock().unwrap();
        e.stop_thread();
        e.output.start_drain();
        let new_out = AudioOutput::new_with_device(device_id, exclusive)?;
        if let Some(ref dec) = e.decoder {
            let sr = dec.lock().unwrap().sample_rate();
            let ch = dec.lock().unwrap().channels();
            e.resampler = if sr != new_out.sample_rate {
                Some(Resampler::new(sr, new_out.sample_rate, ch)?)
            } else {
                None
            };
        }
        {
            let mut eq = e.eq.lock().unwrap();
            eq.reset_sample_rate(new_out.sample_rate, new_out.channels as usize);
        }
        e.output = new_out;
        e.smooth_volume = e.volume;
        Ok(())
    }

    fn store(output: AudioOutput) -> Result<()> {
        let sr = output.sample_rate;
        let ch = output.channels as usize;
        let engine = Self {
            output,
            decoder: None,
            next_decoder: None,
            resampler: None,
            volume: 1.0,
            smooth_volume: 1.0,
            dec_sample_rate: 44100,
            dec_channels: 2,
            flags: PlayFlags::new(),
            spectrum_buf: Arc::new(Mutex::new(vec![0.0f32; SPECTRUM_BUF])),
            spectrum_pos: Arc::new(AtomicU64::new(0)),
            dsp: Arc::new(Mutex::new(DspConfig::default())),
            eq: Arc::new(Mutex::new(Equalizer::new(sr, ch))),
        };
        ENGINE
            .set(Arc::new(Mutex::new(engine)))
            .map_err(|_| anyhow!("Already initialized"))
    }

    // Accessors
    pub fn global() -> Arc<Mutex<Self>> {
        ENGINE.get().expect("AudioEngine not initialized").clone()
    }
    pub fn global_opt() -> Option<Arc<Mutex<Self>>> {
        ENGINE.get().cloned()
    }
    pub fn is_exclusive(&self) -> bool {
        self.output.exclusive
    }

    // DSP setters
    pub fn set_replay_gain(&mut self, linear_gain: f32) {
        self.dsp.lock().unwrap().replay_gain = linear_gain.clamp(0.0, 64.0);
    }

    pub fn set_soft_clip(&mut self, enabled: bool) {
        self.dsp.lock().unwrap().soft_clip = enabled;
    }

    pub fn set_skip_silence(&mut self, enabled: bool) {
        self.dsp.lock().unwrap().skip_silence = enabled;
    }
    pub fn set_gapless(&mut self, enabled: bool) {
        self.dsp.lock().unwrap().gapless = enabled;
    }
    pub fn set_crossfade_secs(&mut self, secs: f32) {
        self.dsp.lock().unwrap().crossfade_secs = secs.clamp(0.0, 12.0);
    }

    // EQ setters
    pub fn set_eq_enabled(&mut self, enabled: bool) {
        self.eq.lock().unwrap().set_enabled(enabled);
    }
    pub fn set_eq_gains(&mut self, gains: Vec<f32>) {
        self.eq.lock().unwrap().set_all_gains(&gains);
    }
    pub fn set_eq_band(&mut self, band: usize, gain_db: f32) {
        self.eq.lock().unwrap().set_gain(band, gain_db);
    }
    pub fn get_eq_gains(&self) -> Vec<f32> {
        self.eq.lock().unwrap().gains_db().to_vec()
    }

    pub fn get_spectrum_data(&self, n: usize) -> Vec<f32> {
        if n == 0 {
            return vec![];
        }
        let buf = self.spectrum_buf.lock().unwrap();
        let ch = self.output.channels as usize;
        let frames = buf.len() / ch;
        let mono: Vec<f32> = (0..frames)
            .map(|f| {
                let base = f * ch;
                buf[base..base + ch].iter().sum::<f32>() / ch as f32
            })
            .collect();
        let rms = (mono.iter().map(|s| s * s).sum::<f32>() / mono.len() as f32).sqrt();
        if rms < 1e-6 {
            return vec![0.0; n];
        }
        (0..n)
            .map(|i| {
                let t0 = (i as f32 / n as f32).powf(1.8);
                let t1 = ((i + 1) as f32 / n as f32).powf(1.8);
                let start = (t0 * frames as f32) as usize;
                let end = ((t1 * frames as f32) as usize).min(frames);
                if start >= end {
                    return 0.0;
                }
                let band_rms = (mono[start..end].iter().map(|s| s * s).sum::<f32>()
                    / (end - start) as f32)
                    .sqrt();
                (band_rms / (rms * 2.0 + 1e-9)).clamp(0.0, 1.0)
            })
            .collect()
    }

    // Playback
    pub fn load(&mut self, path: &str) -> Result<()> {
        let gapless = self.dsp.lock().unwrap().gapless;
        let crossfade_secs = self.dsp.lock().unwrap().crossfade_secs;

        if crossfade_secs > 0.0
            && self.decoder.is_some()
            && self.flags.playing.load(Ordering::SeqCst)
        {
            let next = Decoder::open(path, gapless)?;
            let shared_next = Arc::new(Mutex::new(next));

            *self.next_decoder.get_or_insert_with(|| shared_next.clone()) = shared_next.clone();

            return Ok(());
        }

        self.stop_thread();
        self.flags = PlayFlags::new();
        self.output.stop_drain();
        self.next_decoder = None;

        let dec = Decoder::open(path, gapless)?;
        let src_rate = dec.sample_rate();
        let src_ch = dec.channels();

        self.dec_sample_rate = src_rate;
        self.dec_channels = src_ch;
        self.resampler = if src_rate != self.output.sample_rate {
            Some(Resampler::new(src_rate, self.output.sample_rate, src_ch)?)
        } else {
            None
        };

        {
            let mut eq = self.eq.lock().unwrap();
            eq.reset_sample_rate(self.output.sample_rate, self.output.channels as usize);
        }

        self.spectrum_buf.lock().unwrap().fill(0.0);
        self.spectrum_pos.store(0, Ordering::Relaxed);
        self.smooth_volume = self.volume;
        self.decoder = Some(Arc::new(Mutex::new(dec)));
        Ok(())
    }

    pub fn play(&mut self) -> Result<()> {
        if self.decoder.is_none() {
            return Err(anyhow!("No track loaded"));
        }
        self.output.stop_drain();
        if self.flags.alive.load(Ordering::SeqCst) {
            self.flags.playing.store(true, Ordering::SeqCst);
            return Ok(());
        }
        self.start_thread();
        Ok(())
    }

    pub fn pause(&mut self) -> Result<()> {
        self.flags.playing.store(false, Ordering::SeqCst);
        self.output.start_drain();
        Ok(())
    }

    pub fn stop(&mut self) -> Result<()> {
        self.stop_thread();
        self.output.stop_drain();
        self.decoder = None;
        self.next_decoder = None;
        self.resampler = None;
        self.spectrum_buf.lock().unwrap().fill(0.0);
        Ok(())
    }

    pub fn seek(&mut self, position_secs: f64) -> Result<()> {
        let dec = self
            .decoder
            .as_ref()
            .ok_or_else(|| anyhow!("No track loaded"))?
            .clone();

        let was_playing = self.flags.playing.load(Ordering::SeqCst);

        self.flags.playing.store(false, Ordering::SeqCst);
        self.output.start_drain();
        self.flags.seek_pending.store(true, Ordering::SeqCst);

        thread::sleep(Duration::from_millis(20));
        dec.lock().unwrap().seek(position_secs)?;

        if let Some(rs) = self.resampler.as_mut() {
            rs.reset();
        }

        self.spectrum_buf.lock().unwrap().fill(0.0);
        self.smooth_volume = self.volume;
        self.flags.seek_pending.store(false, Ordering::SeqCst);

        if was_playing {
            self.output.stop_drain();
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
        let d = dec.lock().unwrap();
        Ok(PlaybackPosition {
            position_secs: d.position_secs(),
            duration_secs: d.duration_secs(),
            sample_rate: d.sample_rate(),
            bit_depth: d.bit_depth(),
        })
    }

    pub fn is_playing(&self) -> bool {
        self.flags.playing.load(Ordering::SeqCst)
    }

    // Thread
    fn stop_thread(&mut self) {
        if self.flags.alive.load(Ordering::SeqCst) {
            self.flags.playing.store(false, Ordering::SeqCst);
            self.flags.alive.store(false, Ordering::SeqCst);
            let mut waited = 0u32;
            while self.flags.alive.load(Ordering::SeqCst) && waited < 500 {
                thread::sleep(Duration::from_millis(5));
                waited += 5;
            }
        }
    }

    fn start_thread(&mut self) {
        let arc = Self::global();
        self.flags.alive.store(true, Ordering::SeqCst);
        self.flags.playing.store(true, Ordering::SeqCst);
        let flags = self.flags.clone();
        thread::spawn(move || decode_loop(arc, flags));
    }
}

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
    let (out_ch, out_sr, is_exclusive, spec_buf, spec_pos, dec_arc, dsp_arc, eq_arc) = {
        let e = engine_arc.lock().unwrap();
        let dec = match e.decoder.as_ref() {
            Some(d) => d.clone(),
            None => return,
        };
        (
            e.output.channels as u32,
            e.output.sample_rate as usize,
            e.output.exclusive,
            e.spectrum_buf.clone(),
            e.spectrum_pos.clone(),
            dec,
            e.dsp.clone(),
            e.eq.clone(),
        )
    };

    let target_samples = out_sr * out_ch as usize / 4;
    let ring_cap = out_sr * out_ch as usize / 2 + 4096;
    let mut leading_silent = 0usize;
    let mut leading_done = false;

    // Crossfade state
    let mut fade_in_dec: Option<Arc<Mutex<Decoder>>> = None;
    let mut crossfade_ramp = 0usize; // frames remaining in crossfade
    let crossfade_total_frames = {
        let secs = dsp_arc.lock().unwrap().crossfade_secs;
        (secs * out_sr as f32) as usize
    };

    loop {
        if !flags.alive.load(Ordering::Acquire) {
            break;
        }
        if !flags.playing.load(Ordering::Acquire) {
            thread::sleep(Duration::from_millis(5));
            continue;
        }

        let vacant = engine_arc.lock().unwrap().output.ring_vacant();
        if ring_cap.saturating_sub(vacant) >= target_samples {
            thread::sleep(Duration::from_millis(2));
            continue;
        }

        // Check if a next decoder was queued for crossfade
        if fade_in_dec.is_none() && crossfade_total_frames > 0 {
            let next = engine_arc.lock().unwrap().next_decoder.clone();
            if next.is_some() {
                fade_in_dec = next;
                crossfade_ramp = crossfade_total_frames;
            }
        }

        let decode_result = dec_arc.lock().unwrap().next_packet();

        match decode_result {
            Ok(Some(raw)) => {
                let mut e = engine_arc.lock().unwrap();
                if flags.seek_pending.load(Ordering::Acquire) {
                    continue;
                }

                let dec_ch = e.dec_channels;
                let target_vol = e.volume;
                let dsp = dsp_arc.lock().unwrap().clone();

                // Resample
                let resampled = if let Some(rs) = e.resampler.as_mut() {
                    match rs.process(&raw) {
                        Ok(r) if !r.is_empty() => r,
                        _ => continue,
                    }
                } else {
                    raw
                };

                let mut converted = adapt_channels(&resampled, dec_ch, out_ch);

                // Skip leading silence
                if dsp.skip_silence && !leading_done {
                    let silent = converted.iter().all(|s| s.abs() < SILENCE_THR);
                    if silent {
                        leading_silent += converted.len();
                        if leading_silent < SILENCE_MIN * out_ch as usize {
                            continue;
                        }
                    } else {
                        leading_done = true;
                    }
                }

                // Crossfade blend with next track
                if crossfade_ramp > 0 {
                    if let Some(ref next_dec) = fade_in_dec {
                        if let Ok(Some(next_raw)) = next_dec.lock().unwrap().next_packet() {
                            let next_conv = adapt_channels(&next_raw, dec_ch, out_ch);
                            let total = crossfade_total_frames;
                            let pos = total - crossfade_ramp;
                            let frames = converted.len() / out_ch as usize;
                            for f in 0..frames {
                                let t = ((pos + f) as f32 / total as f32).clamp(0.0, 1.0);
                                for c in 0..out_ch as usize {
                                    let i = f * out_ch as usize + c;
                                    let fade_out = 1.0 - t;
                                    let fade_in = t;
                                    let next_s = next_conv.get(i).copied().unwrap_or(0.0);
                                    converted[i] = converted[i] * fade_out + next_s * fade_in;
                                }
                            }
                            crossfade_ramp = crossfade_ramp.saturating_sub(frames);
                        }
                    }
                }

                // Spectrum
                {
                    let mut sb = spec_buf.lock().unwrap();
                    let len = sb.len();
                    let pos = spec_pos.load(Ordering::Relaxed) as usize;
                    for (k, &s) in converted.iter().enumerate() {
                        sb[(pos + k) % len] = s;
                    }
                    spec_pos.store(((pos + converted.len()) % len) as u64, Ordering::Relaxed);
                }

                // EQ
                eq_arc.lock().unwrap().process_interleaved(&mut converted);

                // Volume & ReplayGain & soft-clip
                let mut smooth = e.smooth_volume;
                {
                    let mut prod = e.output.producer.lock().unwrap();
                    if is_exclusive {
                        prod.push_slice(&converted);
                    } else {
                        let mut tmp = Vec::with_capacity(converted.len());
                        for s in &converted {
                            let diff = target_vol - smooth;
                            if diff.abs() > VOL_RAMP {
                                smooth += diff.signum() * VOL_RAMP;
                            } else {
                                smooth = target_vol;
                            }
                            let gained = s * smooth * dsp.replay_gain;
                            tmp.push(if dsp.soft_clip {
                                soft_clip(gained)
                            } else {
                                gained.clamp(-1.0, 1.0)
                            });
                        }
                        prod.push_slice(&tmp);
                    }
                }
                e.smooth_volume = smooth;
            }

            Ok(None) => {
                // Flush resampler tail
                {
                    let mut e = engine_arc.lock().unwrap();
                    let dec_ch = e.dec_channels;
                    let target_vol = e.volume;
                    let mut smooth = e.smooth_volume;
                    let dsp = dsp_arc.lock().unwrap().clone();

                    let raw_tail = e
                        .resampler
                        .as_mut()
                        .and_then(|rs| rs.flush().ok())
                        .unwrap_or_default();

                    if !raw_tail.is_empty() {
                        let mut converted = adapt_channels(&raw_tail, dec_ch, out_ch);
                        eq_arc.lock().unwrap().process_interleaved(&mut converted);
                        let mut prod = e.output.producer.lock().unwrap();
                        if is_exclusive {
                            prod.push_slice(&converted);
                        } else {
                            let mut tmp = Vec::with_capacity(converted.len());
                            for s in &converted {
                                let diff = target_vol - smooth;
                                if diff.abs() > VOL_RAMP {
                                    smooth += diff.signum() * VOL_RAMP;
                                } else {
                                    smooth = target_vol;
                                }
                                let gained = s * smooth * dsp.replay_gain;
                                tmp.push(if dsp.soft_clip {
                                    soft_clip(gained)
                                } else {
                                    gained.clamp(-1.0, 1.0)
                                });
                            }
                            prod.push_slice(&tmp);
                        }
                        drop(prod);
                        e.smooth_volume = smooth;
                    }
                }

                // Wait for ring to drain before signalling end
                let mut waited = 0u32;
                while waited < 1000 {
                    if !flags.alive.load(Ordering::Acquire) {
                        break;
                    }
                    if engine_arc.lock().unwrap().output.ring_vacant() >= ring_cap {
                        break;
                    }
                    thread::sleep(Duration::from_millis(5));
                    waited += 5;
                }
                flags.playing.store(false, Ordering::Release);
                flags.alive.store(false, Ordering::Release);
                break;
            }

            Err(e) => {
                eprintln!("[decoder] fatal: {e}");
                flags.playing.store(false, Ordering::Release);
                flags.alive.store(false, Ordering::Release);
                break;
            }
        }
    }
}

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
        (sc, 2) if sc > 2 => {
            let ch = sc as usize;
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
