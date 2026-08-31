use crate::{
    audio_io::{ring_cap, SharedProducer},
    convert::{adapt_channels_into, apply_gain},
    decoder::Decoder,
    eq::Equalizer,
    logger,
    output::{AudioOutput, FormatHint},
    resampler::Resampler,
    stereo_enhance::StereoEnhancer,
    PlaybackPosition,
};
use anyhow::{anyhow, Result};
use realfft::RealFftPlanner;
use ringbuf::traits::{Observer, Producer};
use std::sync::{
    atomic::{AtomicBool, AtomicU64, Ordering},
    Arc, Mutex, OnceLock,
};
use std::thread;
use std::time::Duration;

static ENGINE: OnceLock<Arc<Mutex<AudioEngine>>> = OnceLock::new();
static EXCLUSIVE: AtomicBool = AtomicBool::new(false);
static PLAYING: AtomicBool = AtomicBool::new(false);
static FFT_PLAN: OnceLock<Arc<dyn realfft::RealToComplex<f32>>> = OnceLock::new();

fn set_playing_flag(flags: &PlayFlags, playing: bool) {
    flags.playing.store(playing, Ordering::SeqCst);
    PLAYING.store(playing, Ordering::SeqCst);
}

fn wait_stopped(flags: &PlayFlags) {
    let mut waited = 0u32;
    while flags.alive.load(Ordering::SeqCst) && waited < 500 {
        thread::sleep(Duration::from_millis(5));
        waited += 5;
    }
    logger::debug_audio(format!("decode thread stopped (waited {waited}ms)"));
}

fn decoder_hint(dec: &Option<Arc<Mutex<Decoder>>>) -> Option<FormatHint> {
    let d = dec.as_ref()?.lock().unwrap();
    Some(FormatHint {
        sample_rate: d.sample_rate(),
        channels: d.channels(),
        bit_depth: d.bit_depth(),
    })
}

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
    resampler: Arc<Mutex<Option<Resampler>>>,
    next_resampler: Arc<Mutex<Option<Resampler>>>,
    volume: f32,
    smooth_volume: f32,
    dec_sample_rate: u32,
    dec_channels: u32,
    dec_bit_depth: u32,
    flags: Arc<PlayFlags>,
    spectrum_buf: Arc<Mutex<Vec<f32>>>,
    spectrum_pos: Arc<AtomicU64>,
    dsp: Arc<Mutex<DspConfig>>,
    eq: Arc<Mutex<Equalizer>>,
    stereo_enhance: Arc<Mutex<StereoEnhancer>>,
    pub decode_thread_died: Arc<AtomicBool>,
    prev_output: Arc<Mutex<Vec<f32>>>,
    dynamic_ceil: Arc<Mutex<f32>>,
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
        let (wait, dec, old_out, prev_id, prev_excl) = {
            let mut e = arc.lock().unwrap();
            let wait = e.signal_stop();
            e.output.start_drain();
            let prev_id = e.output.device_id.clone();
            let prev_excl = e.output.exclusive;
            let old_out = std::mem::replace(&mut e.output, AudioOutput::closed());
            (wait, e.decoder.clone(), old_out, prev_id, prev_excl)
        };
        if let Some(f) = wait {
            wait_stopped(&f);
        }
        drop(old_out);
        #[cfg(target_os = "windows")]
        if exclusive {
            thread::sleep(Duration::from_millis(50));
        }
        let hint = decoder_hint(&dec);
        let new_out = match AudioOutput::open(Some(device_id), exclusive, hint) {
            Ok(o) => o,
            Err(err) => {
                logger::error_audio(format!("reinit open failed: {err}"));
                let fallback = AudioOutput::open(prev_id.as_deref(), prev_excl, hint)
                    .or_else(|_| AudioOutput::open(prev_id.as_deref(), false, hint))
                    .or_else(|_| AudioOutput::new_default())
                    .map_err(|_| anyhow!("{err}"))?;
                let mut e = arc.lock().unwrap();
                Self::apply_output(&mut e, fallback, &dec)?;
                return Err(err);
            }
        };
        let mut e = arc.lock().unwrap();
        Self::apply_output(&mut e, new_out, &dec)?;
        logger::info_audio("AudioEngine::reinit complete");
        Ok(())
    }

    pub fn recover_engine() -> Result<()> {
        logger::warn_audio("AudioEngine::recover_engine - attempting audio recovery");
        let arc = ENGINE
            .get()
            .ok_or_else(|| anyhow!("Engine not initialized"))?;
        let (wait, exclusive, id, dec, old_out) = {
            let mut e = arc.lock().unwrap();
            let wait = e.signal_stop();
            e.output.start_drain();
            let exclusive = e.output.exclusive;
            let id = e.output.device_id.clone();
            let dec = e.decoder.clone();
            let old_out = std::mem::replace(&mut e.output, AudioOutput::closed());
            (wait, exclusive, id, dec, old_out)
        };
        if let Some(f) = wait {
            wait_stopped(&f);
        }
        drop(old_out);
        #[cfg(target_os = "windows")]
        if exclusive {
            thread::sleep(Duration::from_millis(50));
        }
        let hint = decoder_hint(&dec);
        let new_out = match AudioOutput::open(id.as_deref(), exclusive, hint) {
            Ok(o) => o,
            Err(err) => {
                logger::error_audio(format!("recover open failed: {err}"));
                let fallback = AudioOutput::open(id.as_deref(), false, hint)
                    .or_else(|_| AudioOutput::new_default())
                    .map_err(|_| anyhow!("{err}"))?;
                let mut e = arc.lock().unwrap();
                Self::apply_output(&mut e, fallback, &dec)?;
                e.flags = PlayFlags::new();
                PLAYING.store(false, Ordering::Release);
                return Err(err);
            }
        };
        let mut e = arc.lock().unwrap();
        Self::apply_output(&mut e, new_out, &dec)?;
        e.flags = PlayFlags::new();
        PLAYING.store(false, Ordering::Release);
        logger::info_audio("AudioEngine::recover_engine - output re-opened");
        Ok(())
    }

    fn apply_output(
        e: &mut Self,
        new_out: AudioOutput,
        dec: &Option<Arc<Mutex<Decoder>>>,
    ) -> Result<()> {
        let (sr, ch) = if let Some(d) = dec {
            let g = d.lock().unwrap();
            (g.sample_rate(), g.channels())
        } else {
            (new_out.sample_rate, new_out.channels)
        };
        *e.resampler.lock().unwrap() = if e.decoder.is_some() && sr != new_out.sample_rate {
            Some(Resampler::new(sr, new_out.sample_rate, ch)?)
        } else {
            None
        };
        e.eq
            .lock()
            .unwrap()
            .reset_sample_rate(new_out.sample_rate, new_out.channels as usize);
        e.stereo_enhance
            .lock()
            .unwrap()
            .reset_sample_rate(new_out.sample_rate);
        EXCLUSIVE.store(new_out.exclusive, Ordering::Release);
        e.output = new_out;
        e.smooth_volume = e.volume;
        e.decode_thread_died.store(false, Ordering::SeqCst);
        Ok(())
    }

    fn store(output: AudioOutput) -> Result<()> {
        let sr = output.sample_rate;
        let ch = output.channels as usize;
        let exclusive = output.exclusive;
        logger::info_audio(format!(
            "AudioOutput opened: {sr}Hz {ch}ch exclusive={exclusive}"
        ));
        let engine = Self {
            output,
            decoder: None,
            next_decoder: None,
            resampler: Arc::new(Mutex::new(None)),
            next_resampler: Arc::new(Mutex::new(None)),
            volume: 1.0,
            smooth_volume: 1.0,
            dec_sample_rate: 44100,
            dec_channels: 2,
            dec_bit_depth: 16,
            flags: PlayFlags::new(),
            spectrum_buf: Arc::new(Mutex::new(vec![0.0f32; SPECTRUM_BUF])),
            spectrum_pos: Arc::new(AtomicU64::new(0)),
            dsp: Arc::new(Mutex::new(DspConfig::default())),
            eq: Arc::new(Mutex::new(Equalizer::new(sr, ch))),
            stereo_enhance: Arc::new(Mutex::new(StereoEnhancer::new(sr))),
            decode_thread_died: Arc::new(AtomicBool::new(false)),
            prev_output: Arc::new(Mutex::new(Vec::new())),
            dynamic_ceil: Arc::new(Mutex::new(-12.0)),
        };
        EXCLUSIVE.store(exclusive, Ordering::Release);
        PLAYING.store(false, Ordering::Release);
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
    pub fn exclusive_now() -> bool {
        EXCLUSIVE.load(Ordering::Acquire)
    }
    pub fn playing_now() -> bool {
        PLAYING.load(Ordering::Acquire)
    }
    pub fn decode_dead_now() -> bool {
        Self::global_opt()
            .map(|a| {
                a.try_lock()
                    .map(|e| e.decode_thread_died.load(Ordering::Relaxed))
                    .unwrap_or(false)
            })
            .unwrap_or(false)
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

    pub fn spectrum_bars(n: usize) -> Vec<f32> {
        if n == 0 {
            return vec![];
        }
        let Some(arc) = Self::global_opt() else {
            return vec![0.0; n];
        };
        let (spec_buf, spec_pos, ch, sample_rate, prev_output, dynamic_ceil) = {
            let e = arc.lock().unwrap();
            (
                e.spectrum_buf.clone(),
                e.spectrum_pos.clone(),
                e.output.channels.max(1) as usize,
                e.output.sample_rate as f32,
                e.prev_output.clone(),
                e.dynamic_ceil.clone(),
            )
        };

        let mut mono = vec![0.0f32; FFT_SIZE];
        {
            let buf = spec_buf.lock().unwrap();
            let total_frames = buf.len() / ch;
            if total_frames < FFT_SIZE {
                return vec![0.0; n];
            }
            let write_sample = spec_pos.load(Ordering::Relaxed) as usize;
            let write_frame = write_sample / ch;
            let lookback = (FFT_SIZE + 4096).min(total_frames - 1);
            let start_frame = (write_frame + total_frames - lookback) % total_frames;
            for i in 0..FFT_SIZE {
                let frame_idx = (start_frame + i) % total_frames;
                let base = frame_idx * ch;
                mono[i] = buf[base..base + ch].iter().sum::<f32>() / ch as f32;
            }
        }

        let rms = (mono.iter().map(|s| s * s).sum::<f32>() / FFT_SIZE as f32).sqrt();
        if rms < 5e-6 {
            if let Ok(mut prev_out) = prev_output.lock() {
                if prev_out.len() == n {
                    prev_out.fill(0.0);
                } else {
                    *prev_out = vec![0.0; n];
                }
            }
            return vec![0.0; n];
        }

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

        let mag_db: Vec<f32> = spectrum
            .iter()
            .map(|c| {
                let mag = (c.re * c.re + c.im * c.im).sqrt();
                20.0 * (mag + 1e-9).log10()
            })
            .collect();

        let frame_max_db = mag_db.iter().cloned().fold(f32::NEG_INFINITY, f32::max);
        let mut db_ceil = *dynamic_ceil.lock().unwrap();

        if frame_max_db > db_ceil {
            db_ceil = db_ceil * 0.3 + frame_max_db * 0.7;
        } else {
            db_ceil = db_ceil * 0.995 + (-12.0 * 0.005);
        }
        db_ceil = db_ceil.clamp(-42.0, -6.0);
        *dynamic_ceil.lock().unwrap() = db_ceil;

        let hz_to_mel = |hz: f32| 2595.0 * (1.0 + hz / 700.0).log10();
        let mel_to_hz = |mel: f32| 700.0 * (10.0_f32.powf(mel / 2595.0) - 1.0);

        let nyquist = sample_rate / 2.0;
        let display_max_hz = nyquist.min(20000.0);
        let mel_min = hz_to_mel(20.0);
        let mel_max = hz_to_mel(display_max_hz);

        const DB_FLOOR: f32 = -80.0;

        let mut prev_out = prev_output.lock().unwrap();
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
    pub fn load_path(path: &str) -> Result<()> {
        logger::info_audio(format!("load: {path}"));
        let arc = Self::global_safe()?;
        let (gapless, crossfade_secs, playing, has_decoder, exclusive) = {
            let e = arc.lock().unwrap();
            let dsp = e.dsp.lock().unwrap();
            (
                dsp.gapless,
                dsp.crossfade_secs,
                e.flags.playing.load(Ordering::SeqCst),
                e.decoder.is_some(),
                e.output.exclusive,
            )
        };

        if !exclusive && crossfade_secs > 0.0 && has_decoder && playing {
            logger::debug_audio(format!(
                "crossfade queued next track ({crossfade_secs:.2}s)"
            ));
            let next = Decoder::open(path, gapless)?;
            let nsr = next.sample_rate();
            let nch = next.channels();
            let mut e = arc.lock().unwrap();
            *e.next_resampler.lock().unwrap() = if nsr != e.output.sample_rate {
                Some(Resampler::new(nsr, e.output.sample_rate, nch)?)
            } else {
                None
            };
            let shared_next = Arc::new(Mutex::new(next));
            *e.next_decoder.get_or_insert_with(|| shared_next.clone()) = shared_next.clone();
            return Ok(());
        }

        let wait = {
            let mut e = arc.lock().unwrap();
            e.signal_stop()
        };
        if let Some(f) = wait {
            wait_stopped(&f);
        }

        let dec = Decoder::open(path, gapless)?;
        let src_rate = dec.sample_rate();
        let src_ch = dec.channels();
        let src_bits = dec.bit_depth();

        let reopen = {
            let e = arc.lock().unwrap();
            if e.output.exclusive
                && (e.output.sample_rate != src_rate || e.output.channels != src_ch)
            {
                Some((e.output.exclusive, e.output.device_id.clone()))
            } else {
                None
            }
        };
        let new_out = if let Some((exclusive, id)) = reopen {
            let old = {
                let mut e = arc.lock().unwrap();
                std::mem::replace(&mut e.output, AudioOutput::closed())
            };
            drop(old);
            match AudioOutput::open(
                id.as_deref(),
                exclusive,
                Some(FormatHint {
                    sample_rate: src_rate,
                    channels: src_ch,
                    bit_depth: src_bits,
                }),
            ) {
                Ok(o) => Some(o),
                Err(err) => {
                    logger::warn_audio(format!(
                        "could not reopen at {src_rate}Hz ({err}), restoring previous rate"
                    ));
                    match AudioOutput::open(id.as_deref(), exclusive, None)
                        .or_else(|_| AudioOutput::open(id.as_deref(), false, None))
                        .or_else(|_| AudioOutput::new_default())
                    {
                        Ok(o) => Some(o),
                        Err(e2) => {
                            logger::error_audio(format!("could not restore output: {e2}"));
                            None
                        }
                    }
                }
            }
        } else {
            None
        };

        let mut e = arc.lock().unwrap();
        e.flags = PlayFlags::new();
        PLAYING.store(false, Ordering::Release);
        e.output.stop_drain();
        e.next_decoder = None;
        *e.next_resampler.lock().unwrap() = None;
        e.decode_thread_died.store(false, Ordering::SeqCst);
        if let Some(out) = new_out {
            EXCLUSIVE.store(out.exclusive, Ordering::Release);
            e.output = out;
            e.eq
                .lock()
                .unwrap()
                .reset_sample_rate(e.output.sample_rate, e.output.channels as usize);
            e.stereo_enhance
                .lock()
                .unwrap()
                .reset_sample_rate(e.output.sample_rate);
            logger::info_audio(format!(
                "output reopened at {}Hz {}ch",
                e.output.sample_rate, e.output.channels
            ));
        }

        logger::debug_audio(format!(
            "decoder opened: {src_rate}Hz {src_ch}ch {src_bits}bit → output {}Hz {}ch",
            e.output.sample_rate, e.output.channels
        ));
        if src_ch != e.output.channels {
            logger::warn_audio(format!(
                "channel mismatch: decoder {}ch → output {}ch, adapt_channels will upmix",
                src_ch, e.output.channels
            ));
        }

        e.dec_sample_rate = src_rate;
        e.dec_channels = src_ch;
        e.dec_bit_depth = src_bits;
        *e.resampler.lock().unwrap() = if src_rate != e.output.sample_rate {
            logger::debug_audio(format!(
                "resampler: {}→{}Hz",
                src_rate, e.output.sample_rate
            ));
            Some(Resampler::new(src_rate, e.output.sample_rate, src_ch)?)
        } else {
            None
        };
        e.eq
            .lock()
            .unwrap()
            .reset_sample_rate(e.output.sample_rate, e.output.channels as usize);
        e.spectrum_buf.lock().unwrap().fill(0.0);
        e.spectrum_pos.store(0, Ordering::Relaxed);
        e.smooth_volume = e.volume;
        e.decoder = Some(Arc::new(Mutex::new(dec)));
        logger::info_audio("load: OK");
        Ok(())
    }

    pub fn play_now() -> Result<()> {
        let arc = Self::global_safe()?;
        let (producer, cap, spawned) = {
            let mut e = arc.lock().unwrap();
            if e.decoder.is_none() {
                logger::warn_audio("play() called with no track loaded");
                return Err(anyhow!("No track loaded"));
            }
            e.output.set_paused(false);
            e.output.stop_drain();
            if e.flags.alive.load(Ordering::SeqCst) {
                logger::debug_audio("play() - thread alive, resuming");
                if !e.flags.playing.load(Ordering::SeqCst) {
                    e.smooth_volume = 0.0;
                }
                set_playing_flag(&e.flags, true);
                e.output.set_paused(false);
                e.output.stop_drain();
                return Ok(());
            }
            logger::info_audio("play() - starting decode thread");
            e.flags.alive.store(true, Ordering::SeqCst);
            set_playing_flag(&e.flags, true);
            let flags = e.flags.clone();
            let died_flag = e.decode_thread_died.clone();
            let producer = e.output.producer.clone();
            let cap = e.output.ring_capacity();
            logger::debug_audio("spawning decode thread");
            thread::spawn(move || decode_loop(Self::global(), flags, died_flag));
            (producer, cap, true)
        };
        if spawned {
            let prefill_target = cap / 4;
            let deadline = std::time::Instant::now() + Duration::from_millis(300);
            while std::time::Instant::now() < deadline {
                if producer.lock().unwrap().vacant_len() <= cap - prefill_target {
                    break;
                }
                thread::sleep(Duration::from_millis(4));
            }
            logger::debug_audio("pre-fill done, audio output active");
        }
        Ok(())
    }

    pub fn pause(&mut self) -> Result<()> {
        logger::info_audio("pause()");
        set_playing_flag(&self.flags, false);
        self.output.set_paused(true);
        Ok(())
    }

    pub fn stop_now() -> Result<()> {
        logger::info_audio("stop()");
        let arc = Self::global_safe()?;
        let wait = {
            let mut e = arc.lock().unwrap();
            e.signal_stop()
        };
        if let Some(f) = wait {
            wait_stopped(&f);
        }
        let mut e = arc.lock().unwrap();
        e.output.stop_drain();
        e.decoder = None;
        e.next_decoder = None;
        *e.resampler.lock().unwrap() = None;
        *e.next_resampler.lock().unwrap() = None;
        e.decode_thread_died.store(false, Ordering::SeqCst);
        e.spectrum_buf.lock().unwrap().fill(0.0);
        PLAYING.store(false, Ordering::Release);
        Ok(())
    }

    pub fn seek_now(position_secs: f64) -> Result<()> {
        logger::info_audio(format!("seek({position_secs:.3}s)"));
        let arc = Self::global_safe()?;
        let (dec, resampler, spec_buf, prev_output, was_playing) = {
            let e = arc.lock().unwrap();
            let dec = e
                .decoder
                .as_ref()
                .ok_or_else(|| anyhow!("No track loaded"))?
                .clone();
            let was_playing = e.flags.playing.load(Ordering::SeqCst);
            set_playing_flag(&e.flags, false);
            e.output.set_paused(false);
            e.output.start_drain();
            e.flags.seek_pending.store(true, Ordering::SeqCst);
            (
                dec,
                e.resampler.clone(),
                e.spectrum_buf.clone(),
                e.prev_output.clone(),
                was_playing,
            )
        };
        thread::sleep(Duration::from_millis(20));
        dec.lock().unwrap().seek(position_secs)?;
        if let Some(rs) = resampler.lock().unwrap().as_mut() {
            rs.reset();
        }
        spec_buf.lock().unwrap().fill(0.0);
        if let Ok(mut prev_out) = prev_output.lock() {
            prev_out.fill(0.0);
        }
        let mut e = arc.lock().unwrap();
        e.smooth_volume = 0.0;
        e.flags.seek_pending.store(false, Ordering::SeqCst);
        e.output.stop_drain();
        if was_playing {
            e.output.set_paused(false);
            set_playing_flag(&e.flags, true);
        } else {
            e.output.set_paused(true);
        }
        Ok(())
    }

    pub fn set_volume(&mut self, volume: f32) -> Result<()> {
        let v = volume.clamp(0.0, 1.0);
        logger::debug_audio(format!("set_volume {v:.3}"));
        self.volume = v;
        Ok(())
    }

    pub fn position_now() -> Result<PlaybackPosition> {
        let arc = Self::global_safe()?;
        let (dec, occupied, ch, sr) = {
            let e = arc.lock().unwrap();
            let dec = e
                .decoder
                .as_ref()
                .ok_or_else(|| anyhow!("No track loaded"))?
                .clone();
            (
                dec,
                e.output.ring_occupied_samples() as f64,
                e.output.channels.max(1) as f64,
                e.output.sample_rate.max(1) as f64,
            )
        };
        let d = dec.lock().unwrap();
        let raw = d.position_secs();
        let buffered = occupied / ch / sr;
        Ok(PlaybackPosition {
            position_secs: (raw - buffered).max(0.0),
            duration_secs: d.duration_secs(),
            sample_rate: d.sample_rate(),
            bit_depth: d.bit_depth(),
        })
    }

    pub fn is_playing(&self) -> bool {
        self.flags.playing.load(Ordering::SeqCst)
    }

    fn signal_stop(&mut self) -> Option<Arc<PlayFlags>> {
        if !self.flags.alive.load(Ordering::SeqCst) {
            return None;
        }
        logger::debug_audio("stopping decode thread...");
        set_playing_flag(&self.flags, false);
        self.flags.alive.store(false, Ordering::SeqCst);
        Some(self.flags.clone())
    }
}

fn push_pcm(producer: &SharedProducer, pcm: &[f32], channels: u32, flags: &PlayFlags) {
    let ch = channels.max(1) as usize;
    let mut offset = 0;
    while offset < pcm.len() {
        if !flags.alive.load(Ordering::Acquire) || flags.seek_pending.load(Ordering::Acquire) {
            return;
        }
        let vacant = producer.lock().unwrap().vacant_len();
        let n = vacant - vacant % ch;
        if n == 0 {
            thread::sleep(Duration::from_millis(1));
            continue;
        }
        let take = (pcm.len() - offset).min(n);
        let take = take - take % ch;
        if take == 0 {
            thread::sleep(Duration::from_millis(1));
            continue;
        }
        let wrote = producer.lock().unwrap().push_slice(&pcm[offset..offset + take]);
        offset += wrote;
        if wrote == 0 {
            thread::sleep(Duration::from_millis(1));
        }
    }
}

fn ensure_resampler(
    slot: &std::sync::Arc<Mutex<Option<Resampler>>>,
    src_rate: u32,
    dst_rate: u32,
    ch: u32,
) -> Result<()> {
    let ch = ch.max(1);
    let src_rate = src_rate.max(1);
    let dst_rate = dst_rate.max(1);
    let mut g = slot.lock().unwrap();
    let aligned = match g.as_ref() {
        None => src_rate == dst_rate,
        Some(rs) => src_rate != dst_rate && rs.matches(src_rate, dst_rate, ch),
    };
    if aligned {
        return Ok(());
    }
    *g = if src_rate == dst_rate {
        None
    } else {
        logger::debug_audio(format!("resampler: {src_rate}→{dst_rate}Hz {ch}ch"));
        Some(Resampler::new(src_rate, dst_rate, ch)?)
    };
    Ok(())
}

fn decode_loop(
    engine_arc: Arc<Mutex<AudioEngine>>,
    flags: Arc<PlayFlags>,
    died_flag: Arc<AtomicBool>,
) {
    logger::info_audio("decode_loop: started");

    let (
        out_ch,
        out_sr,
        is_exclusive,
        spec_buf,
        spec_pos,
        dec_arc,
        dsp_arc,
        eq_arc,
        se_arc,
        producer,
        resampler,
        next_resampler,
    ) = {
        let e = engine_arc.lock().unwrap();
        let dec = match e.decoder.as_ref() {
            Some(d) => d.clone(),
            None => {
                logger::error_audio("decode_loop: no decoder - aborting");
                died_flag.store(true, Ordering::Release);
                set_playing_flag(&flags, false);
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
            e.output.producer.clone(),
            e.resampler.clone(),
            e.next_resampler.clone(),
        )
    };
    let mut dec_arc = dec_arc;

    let cap = ring_cap(out_sr as u32, out_ch);
    let throttle_threshold = cap / 4;
    let underrun_threshold = (out_sr * out_ch as usize * 50) / 1000;
    let mut leading_silent = 0usize;
    let mut leading_done = false;
    let mut fade_in_dec: Option<Arc<Mutex<Decoder>>> = None;
    let mut fade_in_ch = out_ch;
    let mut crossfade_ramp = 0usize;
    let crossfade_total_frames = {
        let secs = dsp_arc.lock().unwrap().crossfade_secs;
        (secs * out_sr as f32) as usize
    };
    let mut underrun_count = 0u32;
    let mut last_underrun_log = std::time::Instant::now();
    let mut smooth = { engine_arc.lock().unwrap().smooth_volume };

    let mut raw = Vec::new();
    let mut resampled = Vec::new();
    let mut work = Vec::new();
    let mut next_raw = Vec::new();
    let mut next_resampled = Vec::new();
    let mut next_work = Vec::new();

    loop {
        if !flags.alive.load(Ordering::Acquire) {
            logger::info_audio("decode_loop: clean exit (alive=false)");
            set_playing_flag(&flags, false);
            break;
        }
        if !flags.playing.load(Ordering::Acquire) {
            thread::sleep(Duration::from_millis(5));
            continue;
        }

        let vacant = producer.lock().unwrap().vacant_len();

        if vacant > cap.saturating_sub(underrun_threshold) {
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

        if !is_exclusive && fade_in_dec.is_none() && crossfade_total_frames > 0 {
            let next = engine_arc.lock().unwrap().next_decoder.clone();
            if let Some(n) = next {
                logger::info_audio("decode_loop: crossfade starting");
                fade_in_dec = Some(n);
                crossfade_ramp = crossfade_total_frames;
            }
        }

        let decode_ok = dec_arc.lock().unwrap().next_packet_into(&mut raw);

        match decode_ok {
            Ok(true) => {
                if !flags.playing.load(Ordering::Acquire)
                    || flags.seek_pending.load(Ordering::Acquire)
                {
                    continue;
                }

                let (dec_ch, dec_rate) = {
                    let d = dec_arc.lock().unwrap();
                    (d.channels().max(1), d.sample_rate().max(1))
                };
                let target_vol = {
                    let mut e = engine_arc.lock().unwrap();
                    e.dec_channels = dec_ch;
                    e.dec_sample_rate = dec_rate;
                    e.volume
                };
                if let Err(err) = ensure_resampler(&resampler, dec_rate, out_sr as u32, dec_ch) {
                    logger::error_audio(format!("resampler: {err}"));
                    continue;
                }
                let dsp = dsp_arc.lock().unwrap().clone();

                let use_rs = {
                    let mut rs = resampler.lock().unwrap();
                    if let Some(rs) = rs.as_mut() {
                        match rs.process_into(&raw, &mut resampled) {
                            Ok(()) => true,
                            Err(err) => {
                                logger::error_audio(format!("resampler error: {err}"));
                                continue;
                            }
                        }
                    } else {
                        false
                    }
                };
                if use_rs && resampled.is_empty() {
                    continue;
                }
                let pcm: &[f32] = if use_rs { &resampled } else { &raw };
                adapt_channels_into(pcm, dec_ch, out_ch, &mut work);

                if !is_exclusive && dsp.skip_silence && !leading_done {
                    let silent = work.iter().all(|s| s.abs() < SILENCE_THR);
                    if silent {
                        leading_silent += work.len();
                        if leading_silent < SILENCE_MIN * out_ch as usize {
                            continue;
                        }
                    } else {
                        leading_done = true;
                    }
                }

                if crossfade_ramp > 0 {
                    if let Some(ref next_dec) = fade_in_dec {
                        if let Ok(true) = next_dec.lock().unwrap().next_packet_into(&mut next_raw) {
                            let (fade_ch, fade_rate) = {
                                let n = next_dec.lock().unwrap();
                                (n.channels().max(1), n.sample_rate().max(1))
                            };
                            fade_in_ch = fade_ch;
                            if ensure_resampler(
                                &next_resampler,
                                fade_rate,
                                out_sr as u32,
                                fade_ch,
                            )
                            .is_err()
                            {
                                continue;
                            }
                            let use_nrs = {
                                let mut nrs = next_resampler.lock().unwrap();
                                if let Some(rs) = nrs.as_mut() {
                                    rs.process_into(&next_raw, &mut next_resampled).is_ok()
                                        && !next_resampled.is_empty()
                                } else {
                                    false
                                }
                            };
                            let next_pcm: &[f32] =
                                if use_nrs { &next_resampled } else { &next_raw };
                            adapt_channels_into(next_pcm, fade_in_ch, out_ch, &mut next_work);
                            let total = crossfade_total_frames;
                            let pos = total - crossfade_ramp;
                            let frames = work.len() / out_ch as usize;
                            for f in 0..frames {
                                let t = ((pos + f) as f32 / total as f32).clamp(0.0, 1.0);
                                let phase = t * std::f32::consts::FRAC_PI_2;
                                let (fade_in, fade_out) = (phase.sin(), phase.cos());
                                for c in 0..out_ch as usize {
                                    let i = f * out_ch as usize + c;
                                    let next_s = next_work.get(i).copied().unwrap_or(0.0);
                                    work[i] = work[i] * fade_out + next_s * fade_in;
                                }
                            }
                            crossfade_ramp = crossfade_ramp.saturating_sub(frames);
                        }
                    }
                }

                {
                    let mut sb = spec_buf.lock().unwrap();
                    let len = sb.len();
                    let pos = spec_pos.load(Ordering::Relaxed) as usize;
                    for (k, &s) in work.iter().enumerate() {
                        sb[(pos + k) % len] = s;
                    }
                    spec_pos.store(((pos + work.len()) % len) as u64, Ordering::Relaxed);
                }

                if !is_exclusive {
                    eq_arc.lock().unwrap().process_interleaved(&mut work);
                    se_arc.lock().unwrap().process(&mut work, out_ch as usize);
                    apply_gain(
                        &mut work,
                        target_vol,
                        &mut smooth,
                        dsp.replay_gain,
                        dsp.soft_clip,
                        VOL_RAMP,
                    );
                }
                push_pcm(&producer, &work, out_ch, &flags);
                engine_arc.lock().unwrap().smooth_volume = smooth;
            }

            Ok(false) => {
                let next = engine_arc.lock().unwrap().next_decoder.take();
                if let Some(n) = next {
                    logger::info_audio("decode_loop: taking next decoder");
                    {
                        let mut e = engine_arc.lock().unwrap();
                        e.decoder = Some(n.clone());
                        let nr = e.next_resampler.lock().unwrap().take();
                        *e.resampler.lock().unwrap() = nr;
                    }
                    dec_arc = n;
                    fade_in_dec = None;
                    crossfade_ramp = 0;
                    leading_silent = 0;
                    leading_done = false;
                    continue;
                }
                logger::info_audio("decode_loop: end of stream, flushing tail");
                let (dec_ch, target_vol) = {
                    let e = engine_arc.lock().unwrap();
                    (e.dec_channels.max(1), e.volume)
                };
                let dsp = dsp_arc.lock().unwrap().clone();
                {
                    let mut rs = resampler.lock().unwrap();
                    if let Some(rs) = rs.as_mut() {
                        let _ = rs.flush_into(&mut resampled);
                    } else {
                        resampled.clear();
                    }
                }
                if !resampled.is_empty() {
                    adapt_channels_into(&resampled, dec_ch, out_ch, &mut work);
                    if !is_exclusive {
                        eq_arc.lock().unwrap().process_interleaved(&mut work);
                        se_arc.lock().unwrap().process(&mut work, out_ch as usize);
                        apply_gain(
                            &mut work,
                            target_vol,
                            &mut smooth,
                            dsp.replay_gain,
                            dsp.soft_clip,
                            VOL_RAMP,
                        );
                    }
                    push_pcm(&producer, &work, out_ch, &flags);
                    engine_arc.lock().unwrap().smooth_volume = smooth;
                }
                let mut waited = 0u32;
                while waited < 1000 {
                    if !flags.alive.load(Ordering::Acquire) {
                        break;
                    }
                    if producer.lock().unwrap().vacant_len() >= cap {
                        break;
                    }
                    thread::sleep(Duration::from_millis(5));
                    waited += 5;
                }
                logger::info_audio("decode_loop: track finished - clean exit");
                set_playing_flag(&flags, false);
                flags.alive.store(false, Ordering::Release);
                break;
            }

            Err(e) => {
                logger::error_audio(format!("decode_loop: fatal decoder error: {e}"));
                died_flag.store(true, Ordering::Release);
                set_playing_flag(&flags, false);
                flags.alive.store(false, Ordering::Release);
                break;
            }
        }
    }
}
