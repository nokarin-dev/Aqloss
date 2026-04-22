use anyhow::{anyhow, Result};
pub type RingBuffer = std::sync::Arc<std::sync::Mutex<Vec<f32>>>;

#[allow(dead_code)]
enum AudioStream {
    Cpal(cpal::Stream),
    #[cfg(target_os = "windows")]
    WasapiExclusive(wasapi_exclusive::ExclusiveStream),
}

pub struct AudioOutput {
    _stream: AudioStream,
    pub ring: RingBuffer,
    pub sample_rate: u32,
    pub channels: u32,
    pub exclusive: bool,
}

impl AudioOutput {
    pub fn new() -> Result<Self> {
        // WASAPI Exclusive Mode (Windows)
        #[cfg(target_os = "windows")]
        {
            match wasapi_exclusive::ExclusiveStream::open() {
                Ok(exc) => {
                    let sample_rate = exc.sample_rate;
                    let channels = exc.channels;
                    let ring = exc.ring.clone();
                    return Ok(Self {
                        _stream: AudioStream::WasapiExclusive(exc),
                        ring,
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

        // CPAL shared mode
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
        let buffer_size = cpal::BufferSize::Fixed(256);

        let config = cpal::StreamConfig {
            channels: supported.channels(),
            sample_rate: supported.sample_rate(),
            buffer_size,
        };

        let ring_cap = sample_rate as usize * channels as usize * 2;
        let ring: RingBuffer =
            std::sync::Arc::new(std::sync::Mutex::new(Vec::with_capacity(ring_cap)));
        let ring_cb = ring.clone();

        let stream = device.build_output_stream(
            &config,
            move |output: &mut [f32], _info| {
                let mut buf = ring_cb.lock().unwrap();
                let n = buf.len().min(output.len());
                output[..n].copy_from_slice(&buf[..n]);
                output[n..].fill(f32::default());
                buf.drain(..n);
            },
            |err| eprintln!("[cpal] stream error: {err}"),
            None,
        )?;

        stream.play()?;

        eprintln!(
            "[aqloss] shared-mode output: {}Hz {}ch (buffer=256 frames)",
            sample_rate, channels
        );

        Ok(Self {
            _stream: AudioStream::Cpal(stream),
            ring,
            sample_rate,
            channels,
            exclusive: false,
        })
    }
}

// WASAPI Exclusive Mode (Windows)
#[cfg(target_os = "windows")]
mod wasapi_exclusive {
    use anyhow::{anyhow, Result};
    use std::sync::{Arc, Mutex};
    use std::thread;
    use std::time::Duration;
    use windows::{
        core::PCWSTR,
        Win32::{
            Foundation::HANDLE,
            Media::Audio::{
                eConsole, eRender, IMMDeviceEnumerator, MMDeviceEnumerator,
                AUDCLNT_SHAREMODE_EXCLUSIVE, AUDCLNT_STREAMFLAGS_EVENTCALLBACK, WAVEFORMATEX,
                WAVE_FORMAT_PCM,
            },
            System::Com::{CoCreateInstance, CoInitializeEx, CLSCTX_ALL, COINIT_MULTITHREADED},
        },
    };

    pub struct ExclusiveStream {
        pub ring: super::RingBuffer,
        pub sample_rate: u32,
        pub channels: u32,
        _thread: Option<thread::JoinHandle<()>>,
        alive: Arc<std::sync::atomic::AtomicBool>,
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
            let audio_client: windows::Win32::Media::Audio::IAudioClient =
                device.Activate(CLSCTX_ALL, None)?;

            let candidates: &[(u32, u16, u16)] = &[
                (192000, 32, 2),
                (96000, 32, 2),
                (88200, 32, 2),
                (48000, 32, 2),
                (44100, 32, 2),
                (192000, 24, 2),
                (96000, 24, 2),
                (88200, 24, 2),
                (48000, 24, 2),
                (44100, 24, 2),
                (48000, 16, 2),
                (44100, 16, 2),
            ];

            let mut chosen_fmt: Option<WAVEFORMATEX> = None;
            let mut chosen_sr = 48000u32;
            let mut chosen_ch = 2u32;

            for &(sr, bits, ch) in candidates {
                let fmt = make_waveformat(sr, bits, ch);
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
                    break;
                }
            }

            let fmt = chosen_fmt.ok_or_else(|| {
                anyhow!(
                    "No exclusive format supported by this device.\n\
                    Possible causes:\n\
                    - Another app is using exclusive mode (Spotify, Foobar2000, etc.)\n\
                    - Driver does not support WASAPI Exclusive\n\
                    - Device is a Bluetooth/USB headset with limited format support"
                )
            })?;

            let event = windows::Win32::System::Threading::CreateEventW(
                None,
                false,
                false,
                PCWSTR::null(),
            )?;

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
            let render_client: windows::Win32::Media::Audio::IAudioRenderClient =
                audio_client.GetService()?;
            let buffer_frames = audio_client.GetBufferSize()? as usize;
            audio_client.Start()?;

            let ring: super::RingBuffer = Arc::new(Mutex::new(Vec::with_capacity(
                chosen_sr as usize * chosen_ch as usize,
            )));
            let ring_cb = ring.clone();
            let alive = Arc::new(std::sync::atomic::AtomicBool::new(true));
            let alive_cb = alive.clone();

            let _thread = thread::spawn(move || loop {
                if !alive_cb.load(std::sync::atomic::Ordering::SeqCst) {
                    break;
                }
                windows::Win32::System::Threading::WaitForSingleObject(event, 100);

                let buf_ptr = match render_client.GetBuffer(buffer_frames as u32) {
                    Ok(p) => p,
                    Err(_) => break,
                };
                let output = std::slice::from_raw_parts_mut(
                    buf_ptr as *mut f32,
                    buffer_frames * chosen_ch as usize,
                );
                let mut ring_lock = ring_cb.lock().unwrap();
                let n = ring_lock.len().min(output.len());
                output[..n].copy_from_slice(&ring_lock[..n]);
                output[n..].fill(0.0);
                ring_lock.drain(..n);
                drop(ring_lock);
                let _ = render_client.ReleaseBuffer(buffer_frames as u32, 0);
            });

            Ok(Self {
                ring,
                sample_rate: chosen_sr,
                channels: chosen_ch,
                _thread: Some(_thread),
                alive,
            })
        }
    }

    impl Drop for ExclusiveStream {
        fn drop(&mut self) {
            self.alive.store(false, std::sync::atomic::Ordering::SeqCst);
        }
    }

    unsafe fn make_waveformat(
        sample_rate: u32,
        bits_per_sample: u16,
        channels: u16,
    ) -> WAVEFORMATEX {
        let block_align = channels * bits_per_sample / 8;
        WAVEFORMATEX {
            wFormatTag: WAVE_FORMAT_PCM,
            nChannels: channels,
            nSamplesPerSec: sample_rate,
            nAvgBytesPerSec: sample_rate * block_align as u32,
            nBlockAlign: block_align,
            wBitsPerSample: bits_per_sample,
            cbSize: 0,
        }
    }
}
