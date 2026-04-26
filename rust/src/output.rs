use anyhow::{anyhow, Result};
use ringbuf::{
    traits::{Consumer, Observer, Split},
    HeapRb,
};
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc,
};

pub type SharedProducer = Arc<std::sync::Mutex<ringbuf::HeapProd<f32>>>;

pub struct AudioOutput {
    _stream: AudioStream,
    pub producer: SharedProducer,
    pub draining: Arc<AtomicBool>,
    pub sample_rate: u32,
    pub channels: u32,
    pub exclusive: bool,
}

#[allow(dead_code)]
enum AudioStream {
    Cpal(cpal::Stream),
    #[cfg(target_os = "windows")]
    WasapiExclusive(wasapi_exclusive::ExclusiveStream),
}

const RING_EXTRA_FRAMES: usize = 4096;
const CPAL_BUFFER_FRAMES: usize = 512;

impl AudioOutput {
    pub fn new() -> Result<Self> {
        #[cfg(target_os = "windows")]
        {
            match wasapi_exclusive::ExclusiveStream::open() {
                Ok(exc) => {
                    let sample_rate = exc.sample_rate;
                    let channels = exc.channels;
                    let producer = exc.producer.clone();
                    let draining = exc.draining.clone();
                    return Ok(Self {
                        _stream: AudioStream::WasapiExclusive(exc),
                        producer,
                        draining,
                        sample_rate,
                        channels,
                        exclusive: true,
                    });
                }
                Err(e) => {
                    eprintln!("[wasapi-exclusive] falling back to shared: {e}");
                }
            }
        }

        Self::new_cpal_shared()
    }

    fn new_cpal_shared() -> Result<Self> {
        use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};

        let host = cpal::default_host();
        let device = host
            .default_output_device()
            .ok_or_else(|| anyhow!("No audio output device found"))?;

        let supported = device.default_output_config()?;
        let sample_rate = supported.sample_rate().0;
        let channels = supported.channels() as u32;

        let config = cpal::StreamConfig {
            channels: supported.channels(),
            sample_rate: supported.sample_rate(),
            buffer_size: cpal::BufferSize::Fixed(CPAL_BUFFER_FRAMES as u32),
        };

        let ring_cap = (sample_rate as usize * channels as usize / 2) + RING_EXTRA_FRAMES;
        let rb = HeapRb::<f32>::new(ring_cap);
        let (prod, mut cons) = rb.split();

        let producer: SharedProducer = Arc::new(std::sync::Mutex::new(prod));
        let draining = Arc::new(AtomicBool::new(false));
        let draining_cb = draining.clone();

        let stream = device.build_output_stream(
            &config,
            move |output: &mut [f32], _info| {
                if draining_cb.load(Ordering::Relaxed) {
                    let avail = cons.occupied_len();
                    let mut tmp = vec![0f32; avail];
                    cons.pop_slice(&mut tmp);
                    output.fill(0.0);
                } else {
                    let n = cons.occupied_len().min(output.len());
                    cons.pop_slice(&mut output[..n]);
                    output[n..].fill(0.0);
                }
            },
            |err| eprintln!("[cpal] stream error: {err}"),
            None,
        )?;

        stream.play()?;

        eprintln!(
            "[aqloss] shared-mode output: {}Hz {}ch (buffer={} frames)",
            sample_rate, channels, CPAL_BUFFER_FRAMES
        );

        Ok(Self {
            _stream: AudioStream::Cpal(stream),
            producer,
            draining,
            sample_rate,
            channels,
            exclusive: false,
        })
    }

    pub fn ring_vacant(&self) -> usize {
        self.producer.lock().unwrap().vacant_len()
    }

    pub fn start_drain(&self) {
        self.draining.store(true, Ordering::SeqCst);
    }

    pub fn stop_drain(&self) {
        self.draining.store(false, Ordering::SeqCst);
    }
}

#[cfg(target_os = "windows")]
mod wasapi_exclusive {
    use super::{SharedProducer, RING_EXTRA_FRAMES};
    use anyhow::{anyhow, Result};
    use ringbuf::{
        traits::{Consumer, Observer, Producer, Split},
        HeapRb,
    };
    use std::sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex,
    };
    use std::thread;
    use windows::{
        core::PCWSTR,
        Win32::{
            Media::Audio::{
                eConsole, eRender, IAudioClient, IAudioRenderClient, IMMDeviceEnumerator,
                MMDeviceEnumerator, AUDCLNT_SHAREMODE_EXCLUSIVE, AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
                WAVEFORMATEX,
            },
            System::Com::{CoCreateInstance, CoInitializeEx, CLSCTX_ALL, COINIT_MULTITHREADED},
            System::Threading::{CreateEventW, WaitForSingleObject},
        },
    };

    const WAVE_FORMAT_IEEE_FLOAT: u16 = 3;
    const WAVE_FORMAT_PCM: u16 = 1;

    pub struct ExclusiveStream {
        pub producer: SharedProducer,
        pub draining: Arc<AtomicBool>,
        pub sample_rate: u32,
        pub channels: u32,
        _thread: Option<thread::JoinHandle<()>>,
        alive: Arc<AtomicBool>,
    }

    impl ExclusiveStream {
        pub fn open() -> Result<Self> {
            unsafe { Self::open_inner() }
        }

        unsafe fn open_inner() -> Result<Self> {
            let _ = CoInitializeEx(None, COINIT_MULTITHREADED);

            let enumerator: IMMDeviceEnumerator =
                CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL)?;
            let device = enumerator.GetDefaultAudioEndpoint(eRender, eConsole)?;

            let audio_client: IAudioClient = {
                let mut obj: Option<windows::core::IUnknown> = None;
                device.Activate(
                    &IAudioClient::IID,
                    CLSCTX_ALL,
                    None,
                    &mut obj as *mut _ as *mut _,
                )?;
                obj.ok_or_else(|| anyhow!("IAudioClient activation returned null"))?
                    .cast::<IAudioClient>()?
            };

            let candidates: &[(u32, u16, u16, u16)] = &[
                (192000, 32, 2, WAVE_FORMAT_IEEE_FLOAT),
                (96000, 32, 2, WAVE_FORMAT_IEEE_FLOAT),
                (88200, 32, 2, WAVE_FORMAT_IEEE_FLOAT),
                (48000, 32, 2, WAVE_FORMAT_IEEE_FLOAT),
                (44100, 32, 2, WAVE_FORMAT_IEEE_FLOAT),
                (192000, 24, 2, WAVE_FORMAT_PCM),
                (96000, 24, 2, WAVE_FORMAT_PCM),
                (88200, 24, 2, WAVE_FORMAT_PCM),
                (48000, 24, 2, WAVE_FORMAT_PCM),
                (44100, 24, 2, WAVE_FORMAT_PCM),
                (48000, 16, 2, WAVE_FORMAT_PCM),
                (44100, 16, 2, WAVE_FORMAT_PCM),
            ];

            let mut chosen_fmt: Option<WAVEFORMATEX> = None;
            let mut chosen_sr = 48000u32;
            let mut chosen_ch = 2u32;

            for &(sr, bits, ch, fmt_tag) in candidates {
                let fmt = make_waveformat(sr, bits, ch, fmt_tag);
                let mut closest: *mut WAVEFORMATEX = std::ptr::null_mut();
                let hr = audio_client.IsFormatSupported(
                    AUDCLNT_SHAREMODE_EXCLUSIVE,
                    &fmt,
                    Some(&mut closest),
                );
                if hr.is_ok() {
                    chosen_fmt = Some(fmt);
                    chosen_sr = sr;
                    chosen_ch = ch as u32;
                    eprintln!(
                        "[wasapi-exclusive] chosen format: {}Hz {}ch {}bit (tag={})",
                        sr, ch, bits, fmt_tag
                    );
                    break;
                }
            }

            let fmt = chosen_fmt.ok_or_else(|| {
                anyhow!(
                    "No WASAPI exclusive format supported — driver may not support exclusive mode.\n\
                     Falling back to shared mode automatically."
                )
            })?;

            let event = CreateEventW(None, false, false, PCWSTR::null())?;

            let buffer_dur = 100_000i64;
            audio_client.Initialize(
                AUDCLNT_SHAREMODE_EXCLUSIVE,
                AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
                buffer_dur,
                buffer_dur,
                &fmt,
                None,
            )?;

            audio_client.SetEventHandle(event)?;

            let render_client: IAudioRenderClient = audio_client.GetService()?;
            let buffer_frames = audio_client.GetBufferSize()? as usize;
            audio_client.Start()?;

            let ring_cap = (chosen_sr as usize * chosen_ch as usize / 2) + RING_EXTRA_FRAMES;
            let rb = HeapRb::<f32>::new(ring_cap);
            let (prod, mut cons) = rb.split();

            let producer: SharedProducer = Arc::new(Mutex::new(prod));
            let alive = Arc::new(AtomicBool::new(true));
            let draining = Arc::new(AtomicBool::new(false));
            let alive_cb = alive.clone();
            let draining_cb = draining.clone();

            let _thread = thread::spawn(move || loop {
                if !alive_cb.load(Ordering::SeqCst) {
                    break;
                }
                WaitForSingleObject(event, 100);

                let buf_ptr = match render_client.GetBuffer(buffer_frames as u32) {
                    Ok(p) => p,
                    Err(_) => break,
                };
                let output = std::slice::from_raw_parts_mut(
                    buf_ptr as *mut f32,
                    buffer_frames * chosen_ch as usize,
                );
                if draining_cb.load(Ordering::Relaxed) {
                    let avail = cons.occupied_len();
                    let mut tmp = vec![0f32; avail];
                    cons.pop_slice(&mut tmp);
                    output.fill(0.0);
                } else {
                    let n = cons.occupied_len().min(output.len());
                    cons.pop_slice(&mut output[..n]);
                    output[n..].fill(0.0);
                }
                let _ = render_client.ReleaseBuffer(buffer_frames as u32, 0);
            });

            Ok(Self {
                producer,
                draining,
                sample_rate: chosen_sr,
                channels: chosen_ch,
                _thread: Some(_thread),
                alive,
            })
        }
    }

    impl Drop for ExclusiveStream {
        fn drop(&mut self) {
            self.alive.store(false, Ordering::SeqCst);
        }
    }

    unsafe fn make_waveformat(
        sample_rate: u32,
        bits_per_sample: u16,
        channels: u16,
        format_tag: u16,
    ) -> WAVEFORMATEX {
        let block_align = channels * bits_per_sample / 8;
        WAVEFORMATEX {
            wFormatTag: format_tag,
            nChannels: channels,
            nSamplesPerSec: sample_rate,
            nAvgBytesPerSec: sample_rate * block_align as u32,
            nBlockAlign: block_align,
            wBitsPerSample: bits_per_sample,
            cbSize: 0,
        }
    }
}
