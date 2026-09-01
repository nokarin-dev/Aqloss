use crate::audio_io::{ring_cap, RING_MS};
use anyhow::{anyhow, Result};
use ringbuf::{
    traits::{Consumer, Observer, Split},
    HeapRb,
};
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc,
};

pub type SharedProducer = crate::audio_io::SharedProducer;

#[derive(Clone, Copy, Debug)]
pub struct FormatHint {
    pub sample_rate: u32,
    pub channels: u32,
    pub bit_depth: u32,
}

pub struct AudioOutput {
    _stream: AudioStream,
    pub producer: SharedProducer,
    pub draining: Arc<AtomicBool>,
    pub paused: Arc<AtomicBool>,
    pub sample_rate: u32,
    pub channels: u32,
    pub exclusive: bool,
    pub device_id: Option<String>,
}

#[allow(dead_code)]
enum AudioStream {
    Cpal(cpal::Stream),
    #[cfg(target_os = "windows")]
    WasapiExclusive(crate::wasapi_exclusive::ExclusiveStream),
}

const CPAL_BUFFER_FRAMES: usize = 512;

pub struct CpalDeviceInfo {
    pub id: String,
    pub name: String,
    pub is_default: bool,
    pub supports_exclusive: bool,
}

impl AudioOutput {
    pub fn new_default() -> Result<Self> {
        Self::open(None, false, None)
    }

    pub fn new_shared_with_rate(hint_rate: Option<u32>) -> Result<Self> {
        Self::new_cpal_shared(None, hint_rate, false)
    }

    pub fn new_with_device(device_id: &str, exclusive: bool) -> Result<Self> {
        Self::open(Some(device_id), exclusive, None)
    }

    pub fn open(
        device_id: Option<&str>,
        exclusive: bool,
        hint: Option<FormatHint>,
    ) -> Result<Self> {
        let wants_exclusive = exclusive;
        let exclusive = exclusive && device_allows_exclusive(device_id);
        if wants_exclusive && !exclusive {
            crate::logger::info_output(
                "exclusive/bit-perfect needs WASAPI exclusive or ALSA hw:; using shared mixer",
            );
        }
        #[cfg(target_os = "windows")]
        if exclusive {
            let h = hint.map(|h| crate::wasapi_exclusive::FormatHint {
                sample_rate: h.sample_rate,
                channels: h.channels,
                bit_depth: h.bit_depth,
            });
            let exc = match device_id {
                Some(id) => crate::wasapi_exclusive::ExclusiveStream::open_device(id, h)?,
                None => crate::wasapi_exclusive::ExclusiveStream::open_default(h)?,
            };
            return Ok(Self::from_exclusive(exc));
        }

        Self::new_cpal_shared(device_id, hint.map(|h| h.sample_rate), exclusive)
    }

    #[cfg(target_os = "windows")]
    fn from_exclusive(exc: crate::wasapi_exclusive::ExclusiveStream) -> Self {
        let producer = exc.producer.clone();
        let draining = exc.draining.clone();
        let paused = exc.paused.clone();
        let sample_rate = exc.sample_rate;
        let channels = exc.channels;
        let device_id = Some(exc.device_id.clone());
        Self {
            _stream: AudioStream::WasapiExclusive(exc),
            producer,
            draining,
            paused,
            sample_rate,
            channels,
            exclusive: true,
            device_id,
        }
    }

    fn new_cpal_shared(
        device_id: Option<&str>,
        hint_rate: Option<u32>,
        exclusive: bool,
    ) -> Result<Self> {
        use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};

        let host = match device_id {
            Some(id) => host_for_id(id),
            None => audio_host(),
        };
        let device = match device_id {
            Some(id) => match find_device(&host, id) {
                Some(d) => {
                    crate::logger::info_output(format!("output device: {id}"));
                    d
                }
                None => {
                    crate::logger::warn_output(format!(
                        "device '{id}' not found, using system default"
                    ));
                    host.default_output_device()
                        .ok_or_else(|| anyhow!("No audio output device found"))?
                }
            },
            None => host
                .default_output_device()
                .ok_or_else(|| anyhow!("No audio output device found"))?,
        };

        let default_cfg = device.default_output_config().map_err(|e| {
            crate::logger::error_output(format!("default_output_config failed: {e}"));
            e
        })?;
        let default_ch = default_cfg.channels();
        let default_rate = default_cfg.sample_rate();

        let (sample_rate, channels) = if exclusive {
            if let Some(hint) = hint_rate {
                if probe_rate(&device, default_ch, hint, true) {
                    crate::logger::info_output(format!(
                        "rate match: {hint}Hz (track native, no resampling)"
                    ));
                    (hint, default_ch as u32)
                } else {
                    return Err(anyhow!(
                        "device does not support exclusive {hint}Hz {}ch",
                        default_ch
                    ));
                }
            } else {
                (default_rate, default_ch as u32)
            }
        } else {
            (default_rate, default_ch as u32)
        };

        crate::logger::info_output(format!(
            "opening stream: {sample_rate}Hz {channels}ch exclusive={exclusive}"
        ));

        let config = cpal::StreamConfig {
            channels: channels as u16,
            sample_rate,
            #[cfg(any(target_os = "android", target_os = "linux"))]
            buffer_size: cpal::BufferSize::Default,
            #[cfg(not(any(target_os = "android", target_os = "linux")))]
            buffer_size: cpal::BufferSize::Fixed(CPAL_BUFFER_FRAMES as u32),
        };

        let cap = ring_cap(sample_rate, channels);
        let rb = HeapRb::<f32>::new(cap);
        let (prod, mut cons) = rb.split();
        let producer: SharedProducer = Arc::new(std::sync::Mutex::new(prod));
        let draining = Arc::new(AtomicBool::new(false));
        let paused = Arc::new(AtomicBool::new(false));
        let draining_cb = draining.clone();
        let paused_cb = paused.clone();

        let stream = device
            .build_output_stream(
                config,
                move |output: &mut [f32], _info| {
                    fill_output(output, &mut cons, &draining_cb, &paused_cb);
                },
                |err| crate::logger::error_output(format!("[cpal] stream error: {err}")),
                None,
            )
            .map_err(|e| {
                crate::logger::error_output(format!("build_output_stream failed: {e}"));
                anyhow::anyhow!(e)
            })?;

        stream.play().map_err(|e| {
            crate::logger::error_output(format!("stream.play() failed: {e}"));
            anyhow::anyhow!(e)
        })?;

        crate::logger::info_output(format!(
            "{}-mode: {} @ {}Hz {}ch (callback={} frames, ring={}ms)",
            if exclusive { "exclusive" } else { "shared" },
            device_id.unwrap_or("default"),
            sample_rate,
            channels,
            CPAL_BUFFER_FRAMES,
            RING_MS
        ));

        Ok(Self {
            _stream: AudioStream::Cpal(stream),
            producer,
            draining,
            paused,
            sample_rate,
            channels,
            exclusive,
            device_id: device_id.map(|s| s.to_owned()),
        })
    }

    pub fn ring_vacant(&self) -> usize {
        self.producer.lock().unwrap().vacant_len()
    }

    pub fn ring_occupied_samples(&self) -> usize {
        let p = self.producer.lock().unwrap();
        p.capacity().get() - p.vacant_len()
    }

    pub fn ring_capacity(&self) -> usize {
        self.producer.lock().unwrap().capacity().get()
    }

    pub fn start_drain(&self) {
        self.draining.store(true, Ordering::SeqCst);
    }

    pub fn stop_drain(&self) {
        self.draining.store(false, Ordering::SeqCst);
    }

    pub fn set_paused(&self, paused: bool) {
        self.paused.store(paused, Ordering::SeqCst);
    }
}

fn fill_output<C>(output: &mut [f32], cons: &mut C, draining: &AtomicBool, paused: &AtomicBool)
where
    C: Consumer<Item = f32> + Observer,
{
    if draining.load(Ordering::Relaxed) {
        let avail = cons.occupied_len();
        cons.skip(avail);
        output.fill(0.0);
    } else if paused.load(Ordering::Relaxed) {
        output.fill(0.0);
    } else {
        let n = cons.occupied_len().min(output.len());
        cons.pop_slice(&mut output[..n]);
        output[n..].fill(0.0);
    }
}

fn device_allows_exclusive(device_id: Option<&str>) -> bool {
    #[cfg(target_os = "windows")]
    {
        let _ = device_id;
        return true;
    }
    #[cfg(any(
        target_os = "linux",
        target_os = "dragonfly",
        target_os = "freebsd",
        target_os = "netbsd"
    ))]
    {
        return device_id.is_some_and(is_alsa_hw_id);
    }
    #[cfg(not(any(
        target_os = "windows",
        target_os = "linux",
        target_os = "dragonfly",
        target_os = "freebsd",
        target_os = "netbsd"
    )))]
    {
        let _ = device_id;
        false
    }
}

#[cfg(any(
    target_os = "linux",
    target_os = "dragonfly",
    target_os = "freebsd",
    target_os = "netbsd"
))]
fn is_alsa_hw_id(id: &str) -> bool {
    let pcm = if let Ok(did) = id.parse::<cpal::DeviceId>() {
        if did.host() != cpal::HostId::Alsa {
            return false;
        }
        did.id().to_string()
    } else {
        id.strip_prefix("alsa:").unwrap_or(id).to_string()
    };
    pcm.starts_with("hw:")
}

fn audio_host() -> cpal::Host {
    cpal::default_host()
}

fn host_for_id(id: &str) -> cpal::Host {
    if let Ok(did) = id.parse::<cpal::DeviceId>() {
        if let Ok(h) = cpal::host_from_id(did.host()) {
            return h;
        }
    }
    #[cfg(any(
        target_os = "linux",
        target_os = "dragonfly",
        target_os = "freebsd",
        target_os = "netbsd"
    ))]
    {
        if id.starts_with("alsa:") {
            if let Ok(h) = cpal::host_from_id(cpal::HostId::Alsa) {
                return h;
            }
        }
    }
    audio_host()
}

fn find_device(host: &cpal::Host, id: &str) -> Option<cpal::Device> {
    use cpal::traits::{DeviceTrait, HostTrait};
    if let Ok(did) = id.parse::<cpal::DeviceId>() {
        if let Some(d) = host.device_by_id(&did) {
            return Some(d);
        }
    }
    let lookup = id.strip_prefix("alsa:").unwrap_or(id);
    host.output_devices().ok()?.find(|d| {
        let did = device_id_string(d);
        did == id
            || d.id().ok().is_some_and(|x| x.id() == lookup)
            || device_name(d) == lookup
            || device_name(d) == id
    })
}

fn device_id_string(device: &cpal::Device) -> String {
    use cpal::traits::DeviceTrait;
    device
        .id()
        .map(|id| id.to_string())
        .unwrap_or_else(|_| device_name(device))
}

fn device_name(device: &cpal::Device) -> String {
    use cpal::traits::DeviceTrait;
    device
        .description()
        .map(|d| d.name().to_string())
        .unwrap_or_else(|_| "unknown".into())
}

fn probe_rate(device: &cpal::Device, channels: u16, rate: u32, exact: bool) -> bool {
    use cpal::traits::DeviceTrait;
    #[cfg(target_os = "windows")]
    {
        let _ = (device, channels, exact);
        return probe_wasapi_shared_rate(rate);
    }
    #[cfg(not(target_os = "windows"))]
    {
        device
            .supported_output_configs()
            .ok()
            .map(|cfgs| {
                cfgs.filter(|c| c.channels() == channels).any(|c| {
                    let min = c.min_sample_rate();
                    let max = c.max_sample_rate();
                    if exact {
                        min == rate && max == rate
                    } else {
                        rate >= min && rate <= max
                    }
                })
            })
            .unwrap_or(false)
    }
}

pub fn enumerate_cpal_devices() -> Result<Vec<CpalDeviceInfo>> {
    use cpal::traits::{DeviceTrait, HostTrait};
    let host = audio_host();
    let default_name = host
        .default_output_device()
        .map(|d| device_name(&d))
        .unwrap_or_default();
    let mut out = Vec::new();
    if let Ok(devs) = host.output_devices() {
        for d in devs {
            let name = device_name(&d);
            let id = device_id_string(&d);
            out.push(CpalDeviceInfo {
                id,
                name: name.clone(),
                is_default: name == default_name,
                supports_exclusive: false,
            });
        }
    }
    #[cfg(any(
        target_os = "linux",
        target_os = "dragonfly",
        target_os = "freebsd",
        target_os = "netbsd"
    ))]
    if let Ok(alsa) = cpal::host_from_id(cpal::HostId::Alsa) {
        if let Ok(devs) = alsa.output_devices() {
            for d in devs {
                let Ok(did) = d.id() else {
                    continue;
                };
                if !did.id().starts_with("hw:") {
                    continue;
                }
                let name = device_name(&d);
                let id = did.to_string();
                if out.iter().any(|e| e.id == id) {
                    continue;
                }
                out.push(CpalDeviceInfo {
                    id,
                    name: format!("{name} (ALSA hw)"),
                    is_default: false,
                    supports_exclusive: true,
                });
            }
        }
    }
    if out.is_empty() {
        out.push(CpalDeviceInfo {
            id: "default".into(),
            name: "System default".into(),
            is_default: true,
            supports_exclusive: false,
        });
    }
    Ok(out)
}

#[cfg(target_os = "windows")]
fn probe_wasapi_shared_rate(rate: u32) -> bool {
    use windows::{
        Win32::Media::Audio::{
            eConsole, eRender, IAudioClient, IMMDeviceEnumerator, MMDeviceEnumerator,
            AUDCLNT_SHAREMODE_SHARED, WAVEFORMATEX,
        },
        Win32::System::Com::{
            CoCreateInstance, CoInitializeEx, CoTaskMemFree, CoUninitialize, CLSCTX_ALL,
            COINIT_MULTITHREADED,
        },
    };

    const WAVE_FORMAT_IEEE_FLOAT: u16 = 3;
    unsafe {
        let _ = CoInitializeEx(None, COINIT_MULTITHREADED).ok();
        let result = (|| -> Option<bool> {
            let enumerator: IMMDeviceEnumerator =
                CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL).ok()?;
            let device = enumerator.GetDefaultAudioEndpoint(eRender, eConsole).ok()?;
            let client: IAudioClient = device.Activate(CLSCTX_ALL, None).ok()?;
            for &ch in &[2u16, 1u16] {
                let block_align = ch * 4;
                let fmt = WAVEFORMATEX {
                    wFormatTag: WAVE_FORMAT_IEEE_FLOAT,
                    nChannels: ch,
                    nSamplesPerSec: rate,
                    nAvgBytesPerSec: rate * block_align as u32,
                    nBlockAlign: block_align,
                    wBitsPerSample: 32,
                    cbSize: 0,
                };
                let mut closest: *mut WAVEFORMATEX = std::ptr::null_mut();
                let hr =
                    client.IsFormatSupported(AUDCLNT_SHAREMODE_SHARED, &fmt, Some(&mut closest));
                if !closest.is_null() {
                    CoTaskMemFree(Some(closest as *const _));
                }
                if hr.0 == 0 {
                    return Some(true);
                }
            }
            Some(false)
        })()
        .unwrap_or(false);
        CoUninitialize();
        result
    }
}
