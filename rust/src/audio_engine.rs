use crate::{
    decoder::Decoder, eq::Equalizer, logger, output::AudioOutput, resampler::Resampler,
    stereo_enhance::StereoEnhancer, PlaybackPosition,
};
use anyhow::{anyhow, Result};
use realfft::RealFftPlanner;
use ringbuf::traits::Producer;
use std::sync::{
    atomic::{AtomicBool, AtomicU64, Ordering},
    Arc, Mutex, OnceLock,
};
use std::thread;
use std::time::Duration;

static ENGINE: OnceLock<Arc<Mutex<AudioEngine>>> = OnceLock::new();
static FFT_PLAN: OnceLock<Arc<dyn realfft::RealToComplex<f32>>> = OnceLock::new();

fn fft_plan() -> &'static Arc<dyn realfft::RealToComplex<f32>> {
    FFT_PLAN.get_or_init(|| {
        let mut p = RealFftPlanner::<f32>::new();
        p.plan_fft_forward(FFT_SIZE)
    })
}

#[derive(Clone)]
pub struct DspConfig {
    pub replay_gain: f32,
    pub soft_clip: bool,
    pub skip_silence: bool,
    pub gapless: bool,
    pub crossfade_secs: f32,
    pub stereo_width: f32,
    pub haas_ms: f32,
}

impl Default for DspConfig {
    fn default() -> Self {
        Self {
            replay_gain: 1.0,
            soft_clip: true,
            skip_silence: false,
            gapless: true,
            crossfade_secs: 0.0,
            stereo_width: 1.0,
            haas_ms: 0.0,
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

const SPECTRUM_BUF: usize = 131072;
const FFT_SIZE: usize = 4096;
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
    stereo_enhance: Arc<Mutex<StereoEnhancer>>,
    pub decode_thread_died: Arc<AtomicBool>,
    prev_output: Mutex<Vec<f32>>,
    dynamic_ceil: Mutex<f32>,
}

unsafe impl Send for AudioEngine {}
unsafe impl Sync for AudioEngine {}

impl AudioEngine {
    // Init
    pub fn init_default() -> Result<()> {
        logger::init();
        logger::info_audio("AudioEngine::init_default");
        Self::store(AudioOutput::new_default()?)
    }

    pub fn init_with_device(device_id: &str, exclusive: bool) -> Result<()> {
        logger::init();
        logger::info_audio(format!(
            "AudioEngine::init_with_device id={device_id} exclusive={exclusive}"
        ));
        Self::store(AudioOutput::new_with_device(device_id, exclusive)?)
    }

    pub fn reinit(device_id: &str, exclusive: bool) -> Result<()> {
        logger::info_audio(format!(
            "AudioEngine::reinit id={device_id} exclusive={exclusive}"
        ));
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
        e.stereo_enhance
            .lock()
            .unwrap()
            .reset_sample_rate(new_out.sample_rate);
        e.output = new_out;
        e.smooth_volume = e.volume;
        e.decode_thread_died.store(false, Ordering::SeqCst);
        logger::info_audio("AudioEngine::reinit complete");
        Ok(())
    }

    pub fn recover_engine() -> Result<()> {
        logger::warn_audio("AudioEngine::recover_engine - attempting audio recovery");
        let arc = ENGINE
            .get()
            .ok_or_else(|| anyhow!("Engine not initialized"))?;
        let mut e = arc.lock().unwrap();
        e.stop_thread();
        e.output.start_drain();
        let new_out = AudioOutput::new_default()?;
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
        e.stereo_enhance
            .lock()
            .unwrap()
            .reset_sample_rate(new_out.sample_rate);
        e.output = new_out;
        e.smooth_volume = e.volume;
        e.flags = PlayFlags::new();
        e.decode_thread_died.store(false, Ordering::SeqCst);
        logger::info_audio("AudioEngine::recover_engine - output re-opened");
        Ok(())
    }

    fn store(output: AudioOutput) -> Result<()> {
        let sr = output.sample_rate;
        let ch = output.channels as usize;
        logger::info_audio(format!(
            "AudioOutput opened: {}Hz {}ch exclusive={}",
            sr, ch, output.exclusive
        ));
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
            stereo_enhance: Arc::new(Mutex::new(StereoEnhancer::new(sr))),
            decode_thread_died: Arc::new(AtomicBool::new(false)),
            prev_output: Mutex::new(Vec::new()),
            dynamic_ceil: Mutex::new(-12.0),
        };
        let arc = Arc::new(Mutex::new(engine));
        if ENGINE.set(arc.clone()).is_err() {
            if let Some(existing) = ENGINE.get() {
                let mut e = existing.lock().unwrap();
                let new_e = arc.lock().unwrap();
                unsafe {
                    let new_ptr = &*new_e as *const AudioEngine as *mut AudioEngine;
                    let old_ptr = &mut *e as *mut AudioEngine;
                    std::ptr::swap(old_ptr, new_ptr);
                }
                logger::info_audio("AudioEngine re-initialized in place");
            }
        }
        Ok(())
    }

    // Accessors
    pub fn global() -> Arc<Mutex<Self>> {
        ENGINE.get().expect("AudioEngine not initialized").clone()
    }
    pub fn global_opt() -> Option<Arc<Mutex<Self>>> {
        ENGINE.get().cloned()
    }
    pub fn global_safe() -> Result<Arc<Mutex<Self>>> {
        ENGINE
            .get()
            .cloned()
            .ok_or_else(|| anyhow!("AudioEngine not initialized"))
    }
    pub fn is_exclusive(&self) -> bool {
        self.output.exclusive
    }
    pub fn is_decode_thread_dead(&self) -> bool {
        self.decode_thread_died.load(Ordering::SeqCst)
    }

    // DSP setters
    pub fn set_replay_gain(&mut self, linear_gain: f32) {
        let v = linear_gain.clamp(0.0, 64.0);
        logger::debug_audio(format!("set_replay_gain linear={v:.4}"));
        self.dsp.lock().unwrap().replay_gain = v;
    }
    pub fn set_soft_clip(&mut self, enabled: bool) {
        logger::debug_audio(format!("set_soft_clip enabled={enabled}"));
        self.dsp.lock().unwrap().soft_clip = enabled;
    }
    pub fn set_skip_silence(&mut self, enabled: bool) {
        logger::debug_audio(format!("set_skip_silence enabled={enabled}"));
        self.dsp.lock().unwrap().skip_silence = enabled;
    }
    pub fn set_gapless(&mut self, enabled: bool) {
        logger::debug_audio(format!("set_gapless enabled={enabled}"));
        self.dsp.lock().unwrap().gapless = enabled;
    }
    pub fn set_crossfade_secs(&mut self, secs: f32) {
        let v = secs.clamp(0.0, 12.0);
        logger::debug_audio(format!("set_crossfade_secs secs={v:.2}"));
        self.dsp.lock().unwrap().crossfade_secs = v;
    }

    // EQ setters
    pub fn set_eq_enabled(&mut self, enabled: bool) {
        logger::debug_audio(format!("set_eq_enabled enabled={enabled}"));
        self.eq.lock().unwrap().set_enabled(enabled);
    }
    pub fn set_eq_gains(&mut self, gains: Vec<f32>) {
        logger::debug_audio(format!("set_eq_gains {:?}", gains));
        self.eq.lock().unwrap().set_all_gains(&gains);
    }
    pub fn set_eq_band(&mut self, band: usize, gain_db: f32) {
        logger::debug_audio(format!("set_eq_band band={band} gain={gain_db:.1}dB"));
        self.eq.lock().unwrap().set_gain(band, gain_db);
    }
    pub fn get_eq_gains(&self) -> Vec<f32> {
        self.eq.lock().unwrap().gains_db().to_vec()
    }

    // Stereo enhance setters
    pub fn set_stereo_width(&mut self, width: f32) {
        let v = width.clamp(0.0, 2.0);
        logger::debug_audio(format!("set_stereo_width {v:.2}"));
        self.dsp.lock().unwrap().stereo_width = v;
        self.stereo_enhance.lock().unwrap().set_width(v);
    }
    pub fn set_haas_ms(&mut self, ms: f32) {
        let v = ms.clamp(0.0, 25.0);
        logger::debug_audio(format!("set_haas_ms {v:.1}ms"));
        self.dsp.lock().unwrap().haas_ms = v;
        self.stereo_enhance.lock().unwrap().set_haas_ms(v);
    }
    pub fn get_stereo_width(&self) -> f32 {
        self.stereo_enhance.lock().unwrap().width
    }
    pub fn get_haas_ms(&self) -> f32 {
        self.stereo_enhance.lock().unwrap().haas_ms
    }

    pub fn get_spectrum_data(&self, n: usize) -> Vec<f32> {
        if n == 0 {
            return vec![];
        }

        let buf = self.spectrum_buf.lock().unwrap();
        let ch = self.output.channels as usize;
        let sample_rate = self.output.sample_rate as f32;

        let total_frames = buf.len() / ch;
        if total_frames < FFT_SIZE {
            return vec![0.0; n];
        }

        let ring_occupied_samples = self.output.ring_occupied_samples();
        let cpal_latency_samples = 4096 * ch;
        let latency_samples = ring_occupied_samples + cpal_latency_samples;
        let latency_frames = latency_samples / ch;

        let write_sample = self.spectrum_pos.load(Ordering::Relaxed) as usize;
        let write_frame = write_sample / ch;

        let ideal_lookback = latency_frames + FFT_SIZE;
        let lookback = ideal_lookback.min(total_frames - 1);

        let start_frame = (write_frame + total_frames - lookback) % total_frames;

        let mut mono = vec![0.0f32; FFT_SIZE];
        for i in 0..FFT_SIZE {
            let frame_idx = (start_frame + i) % total_frames;
            let base = frame_idx * ch;
            mono[i] = buf[base..base + ch].iter().sum::<f32>() / ch as f32;
        }

        // Gate on signal energy
        let rms = (mono.iter().map(|s| s * s).sum::<f32>() / FFT_SIZE as f32).sqrt();
        if rms < 5e-6 {
            if let Ok(mut prev_out) = self.prev_output.lock() {
                if prev_out.len() == n {
                    prev_out.fill(0.0);
                } else {
                    *prev_out = vec![0.0; n];
                }
            }
            return vec![0.0; n];
        }

        // Hann window
        let scale = 2.0 / FFT_SIZE as f32;
        for (i, s) in mono.iter_mut().enumerate() {
            let w = 0.5 * (1.0 - (std::f32::consts::TAU * i as f32 / FFT_SIZE as f32).cos());
            *s *= w * scale;
        }

        let fft = fft_plan();
        let mut spectrum = fft.make_output_vec();
        fft.process(&mut mono, &mut spectrum).ok();

        let num_bins = spectrum.len();
        let bin_hz = sample_rate / FFT_SIZE as f32;

        // Precompute magnitudes in dB
        let mag_db: Vec<f32> = spectrum
            .iter()
            .map(|c| {
                let mag = (c.re * c.re + c.im * c.im).sqrt();
                20.0 * (mag + 1e-9).log10()
            })
            .collect();

        // Dynamic Autogain
        let frame_max_db = mag_db.iter().cloned().fold(f32::NEG_INFINITY, f32::max);
        let mut db_ceil = *self.dynamic_ceil.lock().unwrap();

        if frame_max_db > db_ceil {
            db_ceil = db_ceil * 0.3 + frame_max_db * 0.7;
        } else {
            db_ceil = db_ceil * 0.995 + (-12.0 * 0.005);
        }
        db_ceil = db_ceil.clamp(-42.0, -6.0);
        *self.dynamic_ceil.lock().unwrap() = db_ceil;

        let hz_to_mel = |hz: f32| 2595.0 * (1.0 + hz / 700.0).log10();
        let mel_to_hz = |mel: f32| 700.0 * (10.0_f32.powf(mel / 2595.0) - 1.0);

        let nyquist = sample_rate / 2.0;
        let display_max_hz = nyquist.min(20000.0);
        let mel_min = hz_to_mel(20.0);
        let mel_max = hz_to_mel(display_max_hz);

        const DB_FLOOR: f32 = -80.0;

        // Prepare for temporal smoothing
        let mut prev_out = self.prev_output.lock().unwrap();
        if prev_out.len() != n {
            *prev_out = vec![0.0; n];
        }

        let current_frame_bars: Vec<f32> = (0..n)
            .map(|i| {
                let t0 = i as f32 / n as f32;
                let t1 = (i + 1) as f32 / n as f32;
                let hz0 = mel_to_hz(mel_min + t0 * (mel_max - mel_min)).max(20.0);
                let hz1 = mel_to_hz(mel_min + t1 * (mel_max - mel_min)).min(display_max_hz);

                if hz1 <= hz0 {
                    return 0.0;
                }

                let b0 = ((hz0 / bin_hz) as usize).clamp(1, num_bins - 1);
                let b1 = ((hz1 / bin_hz) as usize).clamp(b0 + 1, num_bins);

                // Energy averaging
                let sum_db: f32 = mag_db[b0..b1].iter().cloned().sum();
                let count = (b1 - b0) as f32;
                let energy_db = if count > 0.0 {
                    sum_db / count
                } else {
                    DB_FLOOR
                };

                ((energy_db - DB_FLOOR) / (db_ceil - DB_FLOOR)).clamp(0.0, 1.0)
            })
            .collect();

        // Temporal Smoothing
        let decay_factor = 0.82;
        for i in 0..n {
            let current_val = current_frame_bars[i];
            let prev_val = prev_out[i];

            if current_val > prev_val {
                prev_out[i] = current_val;
            } else {
                prev_out[i] = prev_val * decay_factor + current_val * (1.0 - decay_factor);
            }
        }

        prev_out.clone()
    }

    // Playback
    pub fn load(&mut self, path: &str) -> Result<()> {
        logger::info_audio(format!("load: {path}"));
        let gapless = self.dsp.lock().unwrap().gapless;
        let crossfade_secs = self.dsp.lock().unwrap().crossfade_secs;

        if crossfade_secs > 0.0
            && self.decoder.is_some()
            && self.flags.playing.load(Ordering::SeqCst)
        {
            logger::debug_audio(format!(
                "crossfade queued next track ({crossfade_secs:.2}s)"
            ));
            let next = Decoder::open(path, gapless)?;
            let shared_next = Arc::new(Mutex::new(next));
            *self.next_decoder.get_or_insert_with(|| shared_next.clone()) = shared_next.clone();
            return Ok(());
        }

        self.stop_thread();
        self.flags = PlayFlags::new();
        self.output.stop_drain();
        self.next_decoder = None;
        self.decode_thread_died.store(false, Ordering::SeqCst);

        let dec = Decoder::open(path, gapless)?;
        let src_rate = dec.sample_rate();
        let src_ch = dec.channels();

        if src_rate != self.output.sample_rate && !self.output.exclusive {
            logger::debug_audio(format!(
                "stream rate mismatch ({} → {}Hz), reopening output",
                self.output.sample_rate, src_rate
            ));
            match AudioOutput::new_default_with_rate(Some(src_rate)) {
                Ok(new_out) => {
                    self.output = new_out;
                    self.smooth_volume = self.volume;
                    self.decode_thread_died.store(false, Ordering::SeqCst);
                    self.eq
                        .lock()
                        .unwrap()
                        .reset_sample_rate(self.output.sample_rate, self.output.channels as usize);
                    logger::info_audio(format!(
                        "output reopened at {}Hz (no resampling needed)",
                        src_rate
                    ));
                }
                Err(e) => {
                    logger::warn_audio(format!(
                        "could not reopen at {src_rate}Hz ({e}), keeping current stream"
                    ));
                }
            }
        }

        logger::debug_audio(format!(
            "decoder opened: {src_rate}Hz {src_ch}ch → output {}Hz {}ch",
            self.output.sample_rate, self.output.channels
        ));

        if src_ch != self.output.channels {
            logger::warn_audio(format!(
                "channel mismatch: decoder {}ch → output {}ch, adapt_channels will upmix",
                src_ch, self.output.channels
            ));
        }

        self.dec_sample_rate = src_rate;
        self.dec_channels = src_ch;
        self.resampler = if src_rate != self.output.sample_rate {
            logger::debug_audio(format!(
                "resampler: {}→{}Hz",
                src_rate, self.output.sample_rate
            ));
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
        logger::info_audio("load: OK");
        Ok(())
    }

    pub fn play(&mut self) -> Result<()> {
        if self.decoder.is_none() {
            logger::warn_audio("play() called with no track loaded");
            return Err(anyhow!("No track loaded"));
        }
        self.output.stop_drain();
        if self.flags.alive.load(Ordering::SeqCst) {
            logger::debug_audio("play() - thread alive, resuming");
            self.flags.playing.store(true, Ordering::SeqCst);
            self.output.stop_drain();
            return Ok(());
        }
        logger::info_audio("play() - starting decode thread");
        self.flags.alive.store(true, Ordering::SeqCst);
        self.flags.playing.store(true, Ordering::SeqCst);
        let flags = self.flags.clone();
        let died_flag = self.decode_thread_died.clone();
        logger::debug_audio("spawning decode thread");
        let arc = Self::global();
        thread::spawn(move || decode_loop(arc, flags, died_flag));

        let ring_cap = self.output.sample_rate as usize * self.output.channels as usize + 4096;
        let prefill_target = ring_cap / 4;
        let deadline = std::time::Instant::now() + Duration::from_millis(300);
        while std::time::Instant::now() < deadline {
            if self.output.ring_vacant() <= ring_cap - prefill_target {
                break;
            }
            thread::sleep(Duration::from_millis(4));
        }
        logger::debug_audio("pre-fill done, audio output active");
        Ok(())
    }

    pub fn pause(&mut self) -> Result<()> {
        logger::info_audio("pause()");
        self.flags.playing.store(false, Ordering::SeqCst);
        self.output.start_drain();
        Ok(())
    }

    pub fn stop(&mut self) -> Result<()> {
        logger::info_audio("stop()");
        self.stop_thread();
        self.output.stop_drain();
        self.decoder = None;
        self.next_decoder = None;
        self.resampler = None;
        self.decode_thread_died.store(false, Ordering::SeqCst);
        self.spectrum_buf.lock().unwrap().fill(0.0);
        Ok(())
    }

    pub fn seek(&mut self, position_secs: f64) -> Result<()> {
        logger::info_audio(format!("seek({position_secs:.3}s)"));
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

        if let Ok(mut prev_out) = self.prev_output.lock() {
            prev_out.fill(0.0);
        }

        self.smooth_volume = self.volume;
        self.flags.seek_pending.store(false, Ordering::SeqCst);
        if was_playing {
            self.output.stop_drain();
            self.flags.playing.store(true, Ordering::SeqCst);
        }
        Ok(())
    }

    pub fn set_volume(&mut self, volume: f32) -> Result<()> {
        let v = volume.clamp(0.0, 1.0);
        logger::debug_audio(format!("set_volume {v:.3}"));
        self.volume = v;
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
            logger::debug_audio("stopping decode thread...");
            self.flags.playing.store(false, Ordering::SeqCst);
            self.flags.alive.store(false, Ordering::SeqCst);
            let mut waited = 0u32;
            while self.flags.alive.load(Ordering::SeqCst) && waited < 500 {
                thread::sleep(Duration::from_millis(5));
                waited += 5;
            }
            logger::debug_audio(format!("decode thread stopped (waited {waited}ms)"));
        }
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

fn decode_loop(
    engine_arc: Arc<Mutex<AudioEngine>>,
    flags: Arc<PlayFlags>,
    died_flag: Arc<AtomicBool>,
) {
    logger::info_audio("decode_loop: started");

    let (out_ch, out_sr, is_exclusive, spec_buf, spec_pos, dec_arc, dsp_arc, eq_arc, se_arc) = {
        let e = engine_arc.lock().unwrap();
        let dec = match e.decoder.as_ref() {
            Some(d) => d.clone(),
            None => {
                logger::error_audio("decode_loop: no decoder - aborting");
                died_flag.store(true, Ordering::Release);
                flags.playing.store(false, Ordering::Release);
                flags.alive.store(false, Ordering::Release);
                return;
            }
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
            e.stereo_enhance.clone(),
        )
    };

    let ring_cap = out_sr * out_ch as usize + 4096;
    let throttle_threshold = ring_cap / 4;
    let underrun_threshold = (out_sr as usize * out_ch as usize * 50) / 1000;
    let mut leading_silent = 0usize;
    let mut leading_done = false;

    // Crossfade state
    let mut fade_in_dec: Option<Arc<Mutex<Decoder>>> = None;
    let mut crossfade_ramp = 0usize;
    let crossfade_total_frames = {
        let secs = dsp_arc.lock().unwrap().crossfade_secs;
        (secs * out_sr as f32) as usize
    };

    let mut underrun_count = 0u32;
    let mut last_underrun_log = std::time::Instant::now();

    loop {
        if !flags.alive.load(Ordering::Acquire) {
            logger::info_audio("decode_loop: clean exit (alive=false)");
            flags.playing.store(false, Ordering::Release);
            break;
        }
        if !flags.playing.load(Ordering::Acquire) {
            thread::sleep(Duration::from_millis(5));
            continue;
        }

        let vacant = engine_arc.lock().unwrap().output.ring_vacant();

        if vacant > ring_cap.saturating_sub(underrun_threshold) {
            underrun_count += 1;
            if last_underrun_log.elapsed().as_secs() >= 1 {
                if underrun_count > 5 {
                    logger::warn_audio(format!("buffer underrun x{underrun_count} in last second"));
                }
                underrun_count = 0;
                last_underrun_log = std::time::Instant::now();
            }
        } else if last_underrun_log.elapsed().as_secs() >= 1 {
            underrun_count = 0;
            last_underrun_log = std::time::Instant::now();
        }

        if vacant < throttle_threshold {
            thread::sleep(Duration::from_millis(2));
            continue;
        }

        // Check if a next decoder was queued for crossfade
        if fade_in_dec.is_none() && crossfade_total_frames > 0 {
            let next = engine_arc.lock().unwrap().next_decoder.clone();
            if next.is_some() {
                logger::info_audio("decode_loop: crossfade starting");
                fade_in_dec = next;
                crossfade_ramp = crossfade_total_frames;
            }
        }

        let decode_result = dec_arc.lock().unwrap().next_packet();

        match decode_result {
            Ok(Some(raw)) => {
                let mut e = engine_arc.lock().unwrap();
                if !flags.playing.load(Ordering::Acquire) {
                    continue;
                }
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
                        Ok(_) => continue,
                        Err(err) => {
                            logger::error_audio(format!("resampler error: {err}"));
                            continue;
                        }
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
                                    let next_s = next_conv.get(i).copied().unwrap_or(0.0);
                                    converted[i] = converted[i] * (1.0 - t) + next_s * t;
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

                // Stereo enhance
                se_arc
                    .lock()
                    .unwrap()
                    .process(&mut converted, out_ch as usize);

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
                logger::info_audio("decode_loop: end of stream, flushing tail");
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
                        se_arc
                            .lock()
                            .unwrap()
                            .process(&mut converted, out_ch as usize);
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
                logger::info_audio("decode_loop: track finished - clean exit");
                flags.playing.store(false, Ordering::Release);
                flags.alive.store(false, Ordering::Release);
                break;
            }

            Err(e) => {
                logger::error_audio(format!("decode_loop: fatal decoder error: {e}"));
                died_flag.store(true, Ordering::Release);
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
    let src = src as usize;
    let dst = dst as usize;
    match (src, dst) {
        (1, d) => {
            // mono → any
            let frames = input.len();
            let mut out = Vec::with_capacity(frames * d);
            for &s in input {
                for _ in 0..d {
                    out.push(s);
                }
            }
            out
        }
        (2, 1) => input
            .chunks_exact(2)
            .map(|c| (c[0] + c[1]) * std::f32::consts::FRAC_1_SQRT_2)
            .collect(),
        (2, d) => {
            // stereo → any
            let frames = input.len() / 2;
            let mut out = vec![0f32; frames * d];
            for (f, chunk) in input.chunks_exact(2).enumerate() {
                out[f * d] = chunk[0];
                if d > 1 {
                    out[f * d + 1] = chunk[1];
                }
            }
            out
        }
        (s, 2) if s > 2 => {
            // surround → stereo
            input
                .chunks_exact(s)
                .flat_map(|frame| {
                    let l = frame.iter().step_by(2).sum::<f32>() / (s as f32 / 2.0);
                    let r = frame.iter().skip(1).step_by(2).sum::<f32>() / (s as f32 / 2.0);
                    [l, r]
                })
                .collect()
        }
        (s, d) if s > 2 && d > 2 => {
            // surround → surround
            let frames = input.len() / s;
            let mut out = vec![0f32; frames * d];
            for f in 0..frames {
                let copy = s.min(d);
                out[f * d..f * d + copy].copy_from_slice(&input[f * s..f * s + copy]);
            }
            out
        }
        _ => input.to_vec(),
    }
}
