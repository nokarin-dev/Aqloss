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
    pub fn new_default() -> Result<Self> {
        #[cfg(target_os = "windows")]
        {
            if let Ok(exc) = wasapi_exclusive::ExclusiveStream::open_default() {
                return Ok(Self::from_exclusive(exc));
            }
            eprintln!("[aqloss] WASAPI exclusive not available on default device, using shared");
        }
        Self::new_cpal_shared(None)
    }

    pub fn new_with_device(device_id: &str, exclusive: bool) -> Result<Self> {
        #[cfg(target_os = "windows")]
        if exclusive {
            let exc = wasapi_exclusive::ExclusiveStream::open_device(device_id)?;
            return Ok(Self::from_exclusive(exc));
        }
        Self::new_cpal_shared(Some(device_id))
    }

    #[cfg(target_os = "windows")]
    fn from_exclusive(exc: wasapi_exclusive::ExclusiveStream) -> Self {
        let producer = exc.producer.clone();
        let draining = exc.draining.clone();
        let sample_rate = exc.sample_rate;
        let channels = exc.channels;
        Self {
            _stream: AudioStream::WasapiExclusive(exc),
            producer,
            draining,
            sample_rate,
            channels,
            exclusive: true,
        }
    }

    fn new_cpal_shared(device_id: Option<&str>) -> Result<Self> {
        use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};

        let host = cpal::default_host();
        let device = if let Some(_id) = device_id {
            host.default_output_device()
                .ok_or_else(|| anyhow!("No audio output device found"))?
        } else {
            host.default_output_device()
                .ok_or_else(|| anyhow!("No audio output device found"))?
        };

        let supported = device.default_output_config()?;
        let sample_rate: u32 = supported.sample_rate();
        let channels: u32 = supported.channels() as u32;

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
            "[aqloss] shared-mode: {}Hz {}ch (buffer={} frames)",
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

// WASAPI exclusive (Windows)
#[cfg(target_os = "windows")]
pub mod wasapi_exclusive {
    use super::{SharedProducer, RING_EXTRA_FRAMES};
    use anyhow::{anyhow, Result};
    use ringbuf::{
        traits::{Consumer, Observer, Split},
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
            Devices::Properties::DEVPKEY_Device_FriendlyName,
            Foundation::HANDLE,
            Media::Audio::{
                eConsole, eRender, IAudioClient, IAudioRenderClient, IMMDevice,
                IMMDeviceCollection, IMMDeviceEnumerator, MMDeviceEnumerator,
                AUDCLNT_SHAREMODE_EXCLUSIVE, AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
                DEVICE_STATE_ACTIVE, WAVEFORMATEX,
            },
            System::Com::{
                CoCreateInstance, CoInitializeEx, CoTaskMemFree, CoUninitialize, CLSCTX_ALL,
                COINIT_MULTITHREADED, STGM_READ,
            },
            System::Threading::{CreateEventW, WaitForSingleObject},
            UI::Shell::PropertiesSystem::IPropertyStore,
        },
    };

    const WAVE_FORMAT_IEEE_FLOAT: u16 = 3;

    const CANDIDATES: &[(u32, u16)] = &[
        (192_000, 2),
        (96_000, 2),
        (88_200, 2),
        (48_000, 2),
        (44_100, 2),
    ];

    // Public device info struct
    #[derive(Debug, Clone)]
    pub struct DeviceInfo {
        pub id: String,
        pub name: String,
        pub is_default: bool,
        pub supports_exclusive: bool,
    }

    pub fn enumerate_devices() -> Result<Vec<DeviceInfo>> {
        unsafe {
            let _ = CoInitializeEx(None, COINIT_MULTITHREADED).ok();

            let enumerator: IMMDeviceEnumerator =
                CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL)?;

            let default_id = get_default_id(&enumerator);

            let collection: IMMDeviceCollection =
                enumerator.EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE)?;
            let count = collection.GetCount()?;

            let mut infos = Vec::with_capacity(count as usize);
            for i in 0..count {
                let device = collection.Item(i)?;
                if let Some(info) = build_device_info(&device, &default_id) {
                    infos.push(info);
                }
            }

            CoUninitialize();
            Ok(infos)
        }
    }

    pub fn probe_exclusive(device_id: &str) -> bool {
        unsafe {
            let _ = CoInitializeEx(None, COINIT_MULTITHREADED).ok();

            let result = (|| -> Result<bool> {
                let enumerator: IMMDeviceEnumerator =
                    CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL)?;
                let wide = to_wide(device_id);
                let device = enumerator.GetDevice(PCWSTR::from_raw(wide.as_ptr()))?;
                let client: IAudioClient = device.Activate(CLSCTX_ALL, None)?;

                for &(sr, ch) in CANDIDATES {
                    let fmt = make_waveformat_f32(sr, ch);
                    let mut closest: *mut WAVEFORMATEX = std::ptr::null_mut();
                    if client
                        .IsFormatSupported(AUDCLNT_SHAREMODE_EXCLUSIVE, &fmt, Some(&mut closest))
                        .is_ok()
                    {
                        return Ok(true);
                    }
                }
                Ok(false)
            })();

            CoUninitialize();
            result.unwrap_or(false)
        }
    }

    // ExclusiveStream
    pub struct ExclusiveStream {
        pub producer: SharedProducer,
        pub draining: Arc<AtomicBool>,
        pub sample_rate: u32,
        pub channels: u32,
        _thread: Option<thread::JoinHandle<()>>,
        alive: Arc<AtomicBool>,
    }

    impl ExclusiveStream {
        pub fn open_default() -> Result<Self> {
            unsafe {
                let _ = CoInitializeEx(None, COINIT_MULTITHREADED).ok();
                let enumerator: IMMDeviceEnumerator =
                    CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL)?;
                let device = enumerator.GetDefaultAudioEndpoint(eRender, eConsole)?;
                let id = get_device_id(&device)?;
                CoUninitialize();
                Self::open_device(&id)
            }
        }

        pub fn open_device(device_id: &str) -> Result<Self> {
            unsafe { Self::probe_and_spawn(device_id) }
        }

        unsafe fn probe_and_spawn(device_id: &str) -> Result<Self> {
            let _ = CoInitializeEx(None, COINIT_MULTITHREADED).ok();

            let mut chosen_sr = 0u32;
            let mut chosen_ch = 0u16;

            {
                let enumerator: IMMDeviceEnumerator =
                    CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL)?;
                let wide = to_wide(device_id);
                let device = enumerator.GetDevice(PCWSTR::from_raw(wide.as_ptr()))?;
                let probe_client: IAudioClient = device.Activate(CLSCTX_ALL, None)?;

                for &(sr, ch) in CANDIDATES {
                    let fmt = make_waveformat_f32(sr, ch);
                    let mut closest: *mut WAVEFORMATEX = std::ptr::null_mut();
                    if probe_client
                        .IsFormatSupported(AUDCLNT_SHAREMODE_EXCLUSIVE, &fmt, Some(&mut closest))
                        .is_ok()
                    {
                        chosen_sr = sr;
                        chosen_ch = ch;
                        eprintln!(
                            "[wasapi-exclusive] format: {}Hz {}ch f32 on device {}",
                            sr, ch, device_id
                        );
                        break;
                    }
                }
            }

            CoUninitialize();

            if chosen_sr == 0 {
                return Err(anyhow!(
                    "Device '{}' does not support WASAPI exclusive IEEE_FLOAT",
                    device_id
                ));
            }

            let ring_cap = (chosen_sr as usize * chosen_ch as usize / 2) + RING_EXTRA_FRAMES;
            let rb = HeapRb::<f32>::new(ring_cap);
            let (prod, cons) = rb.split();

            let producer: SharedProducer = Arc::new(Mutex::new(prod));
            let alive = Arc::new(AtomicBool::new(true));
            let draining = Arc::new(AtomicBool::new(false));

            let alive_cb = alive.clone();
            let draining_cb = draining.clone();
            let id = device_id.to_owned();

            let _thread = thread::spawn(move || {
                run_audio_thread(id, chosen_sr, chosen_ch as u32, cons, alive_cb, draining_cb);
            });

            Ok(Self {
                producer,
                draining,
                sample_rate: chosen_sr,
                channels: chosen_ch as u32,
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

    // Audio render thread
    fn run_audio_thread(
        device_id: String,
        sample_rate: u32,
        channels: u32,
        mut cons: ringbuf::HeapCons<f32>,
        alive: Arc<AtomicBool>,
        draining: Arc<AtomicBool>,
    ) {
        eprintln!("[wasapi-exclusive] audio thread started for {}", device_id);
        unsafe {
            let _ = CoInitializeEx(None, COINIT_MULTITHREADED).ok();

            let result = setup_wasapi(&device_id, sample_rate, channels);
            let (audio_client, render_client, buffer_frames, event) = match result {
                Ok(r) => r,
                Err(e) => {
                    eprintln!("[wasapi-exclusive] thread setup failed: {e}");
                    CoUninitialize();
                    return;
                }
            };

            let samples_per_cb = buffer_frames * channels as usize;

            loop {
                if !alive.load(Ordering::SeqCst) {
                    break;
                }

                WaitForSingleObject(event, 100);

                let buf_ptr = match render_client.GetBuffer(buffer_frames as u32) {
                    Ok(p) => p,
                    Err(e) => {
                        eprintln!("[wasapi-exclusive] GetBuffer: {e}");
                        break;
                    }
                };

                let output = std::slice::from_raw_parts_mut(buf_ptr as *mut f32, samples_per_cb);

                if draining.load(Ordering::Relaxed) {
                    let avail = cons.occupied_len();
                    let mut tmp = vec![0f32; avail];
                    cons.pop_slice(&mut tmp);
                    output.fill(0.0);
                } else {
                    let n = cons.occupied_len().min(samples_per_cb);
                    cons.pop_slice(&mut output[..n]);
                    output[n..].fill(0.0);
                }

                let _ = render_client.ReleaseBuffer(buffer_frames as u32, 0);
            }

            let _ = audio_client.Stop();
            CoUninitialize();
        }
    }

    unsafe fn setup_wasapi(
        device_id: &str,
        sample_rate: u32,
        channels: u32,
    ) -> Result<(IAudioClient, IAudioRenderClient, usize, HANDLE)> {
        let enumerator: IMMDeviceEnumerator =
            CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL)?;
        let wide = to_wide(device_id);
        let device = enumerator.GetDevice(PCWSTR::from_raw(wide.as_ptr()))?;
        let audio_client: IAudioClient = device.Activate(CLSCTX_ALL, None)?;
        let fmt = make_waveformat_f32(sample_rate, channels as u16);

        const AUDCLNT_E_BUFFER_SIZE_NOT_ALIGNED: u32 = 0x88890019;
        const PREFERRED_DUR: i64 = 1_000_000;

        let init_result = audio_client.Initialize(
            AUDCLNT_SHAREMODE_EXCLUSIVE,
            AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
            PREFERRED_DUR,
            PREFERRED_DUR,
            &fmt,
            None,
        );

        let audio_client = match init_result {
            Ok(()) => audio_client,
            Err(ref e) if e.code().0 as u32 == AUDCLNT_E_BUFFER_SIZE_NOT_ALIGNED => {
                let aligned_frames = audio_client.GetBufferSize()? as u64;
                let aligned_dur = (aligned_frames * 10_000_000) / sample_rate as u64;
                eprintln!(
                    "[wasapi-exclusive] alignment fix: {} frames",
                    aligned_frames
                );
                let wide2 = to_wide(device_id);
                let device2 = enumerator.GetDevice(PCWSTR::from_raw(wide2.as_ptr()))?;
                let ac2: IAudioClient = device2.Activate(CLSCTX_ALL, None)?;
                ac2.Initialize(
                    AUDCLNT_SHAREMODE_EXCLUSIVE,
                    AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
                    aligned_dur as i64,
                    aligned_dur as i64,
                    &fmt,
                    None,
                )?;
                ac2
            }
            Err(e) => return Err(e.into()),
        };

        let event = CreateEventW(None, false, false, PCWSTR::null())?;
        audio_client.SetEventHandle(event)?;
        let render_client: IAudioRenderClient = audio_client.GetService()?;
        let buffer_frames = audio_client.GetBufferSize()? as usize;
        audio_client.Start()?;
        eprintln!("[wasapi-exclusive] started, buffer_frames={buffer_frames}");

        Ok((audio_client, render_client, buffer_frames, event))
    }

    // Helpers
    fn make_waveformat_f32(sample_rate: u32, channels: u16) -> WAVEFORMATEX {
        let bits: u16 = 32;
        let block_align = channels * bits / 8;
        WAVEFORMATEX {
            wFormatTag: WAVE_FORMAT_IEEE_FLOAT,
            nChannels: channels,
            nSamplesPerSec: sample_rate,
            nAvgBytesPerSec: sample_rate * block_align as u32,
            nBlockAlign: block_align,
            wBitsPerSample: bits,
            cbSize: 0,
        }
    }

    unsafe fn get_device_id(device: &IMMDevice) -> Result<String> {
        let ptr = device.GetId()?;
        let id = ptr.to_string()?;
        CoTaskMemFree(Some(ptr.0 as *const _));
        Ok(id)
    }

    unsafe fn get_default_id(enumerator: &IMMDeviceEnumerator) -> Option<String> {
        enumerator
            .GetDefaultAudioEndpoint(eRender, eConsole)
            .ok()
            .and_then(|d| get_device_id(&d).ok())
    }

    unsafe fn build_device_info(
        device: &IMMDevice,
        default_id: &Option<String>,
    ) -> Option<DeviceInfo> {
        let id = get_device_id(device).ok()?;

        let store: IPropertyStore = device.OpenPropertyStore(STGM_READ).ok()?;
        let prop = store
            .GetValue(&DEVPKEY_Device_FriendlyName as *const _ as *const _)
            .ok()?;
        let name = prop
            .Anonymous
            .Anonymous
            .Anonymous
            .pwszVal
            .to_string()
            .ok()?;

        let supports_exclusive = probe_exclusive_device(device);
        let is_default = default_id.as_deref() == Some(&id);

        Some(DeviceInfo {
            id,
            name,
            is_default,
            supports_exclusive,
        })
    }

    unsafe fn probe_exclusive_device(device: &IMMDevice) -> bool {
        let Ok(client) = device.Activate::<IAudioClient>(CLSCTX_ALL, None) else {
            return false;
        };
        for &(sr, ch) in CANDIDATES {
            let fmt = make_waveformat_f32(sr, ch);
            let mut closest: *mut WAVEFORMATEX = std::ptr::null_mut();
            if client
                .IsFormatSupported(AUDCLNT_SHAREMODE_EXCLUSIVE, &fmt, Some(&mut closest))
                .is_ok()
            {
                return true;
            }
        }
        false
    }

    fn to_wide(s: &str) -> Vec<u16> {
        s.encode_utf16().chain(std::iter::once(0)).collect()
    }
}
