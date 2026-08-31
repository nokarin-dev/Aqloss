use crate::audio_io::{ring_cap, SharedProducer};
use crate::convert::{quantize, PcmKind, Rng};
use anyhow::{anyhow, Result};
use ringbuf::{
    traits::{Consumer, Observer, Split},
    HeapRb,
};
use std::ffi::OsString;
use std::os::windows::ffi::OsStringExt;
use std::sync::{
    atomic::{AtomicBool, Ordering},
    mpsc, Arc, Mutex,
};
use std::thread;
use std::time::Duration;
use windows::{
    core::PCWSTR,
    Win32::{
        Devices::Properties::DEVPKEY_Device_FriendlyName,
        Foundation::{HANDLE, PROPERTYKEY},
        Media::{
            Audio::{
                eConsole, eRender, IAudioClient, IAudioRenderClient, IMMDevice,
                IMMDeviceCollection, IMMDeviceEnumerator, MMDeviceEnumerator,
                AUDCLNT_E_BUFFER_SIZE_NOT_ALIGNED, AUDCLNT_SHAREMODE_EXCLUSIVE,
                AUDCLNT_STREAMFLAGS_EVENTCALLBACK, DEVICE_STATE_ACTIVE, WAVEFORMATEX,
                WAVEFORMATEXTENSIBLE, WAVEFORMATEXTENSIBLE_0, WAVE_FORMAT_PCM,
            },
            KernelStreaming::{
                KSDATAFORMAT_SUBTYPE_PCM, SPEAKER_FRONT_CENTER, SPEAKER_FRONT_LEFT,
                SPEAKER_FRONT_RIGHT, WAVE_FORMAT_EXTENSIBLE,
            },
            Multimedia::{KSDATAFORMAT_SUBTYPE_IEEE_FLOAT, WAVE_FORMAT_IEEE_FLOAT},
        },
        System::{
            Com::{
                CoCreateInstance, CoInitializeEx, CoTaskMemFree, CoUninitialize, StructuredStorage,
                CLSCTX_ALL, COINIT_MULTITHREADED, STGM_READ,
            },
            Threading::{CreateEventW, WaitForSingleObject},
            Variant::VT_LPWSTR,
        },
        UI::Shell::PropertiesSystem::IPropertyStore,
    },
};

const RATES: &[u32] = &[44_100, 48_000, 88_200, 96_000, 176_400, 192_000];

#[derive(Debug, Clone)]
pub struct DeviceInfo {
    pub id: String,
    pub name: String,
    pub is_default: bool,
    pub supports_exclusive: bool,
}

#[derive(Clone, Copy)]
pub struct FormatHint {
    pub sample_rate: u32,
    pub channels: u32,
    pub bit_depth: u32,
}

pub struct ExclusiveStream {
    pub producer: SharedProducer,
    pub draining: Arc<AtomicBool>,
    pub paused: Arc<AtomicBool>,
    pub sample_rate: u32,
    pub channels: u32,
    pub pcm: PcmKind,
    pub device_id: String,
    _thread: Option<thread::JoinHandle<()>>,
    alive: Arc<AtomicBool>,
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

impl ExclusiveStream {
    pub fn open_default(hint: Option<FormatHint>) -> Result<Self> {
        unsafe {
            let _ = CoInitializeEx(None, COINIT_MULTITHREADED).ok();
            let enumerator: IMMDeviceEnumerator =
                CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL)?;
            let device = enumerator.GetDefaultAudioEndpoint(eRender, eConsole)?;
            let id = get_device_id(&device)?;
            CoUninitialize();
            Self::open_device(&id, hint)
        }
    }

    pub fn open_device(device_id: &str, hint: Option<FormatHint>) -> Result<Self> {
        unsafe { Self::probe_and_spawn(device_id, hint) }
    }

    unsafe fn probe_and_spawn(device_id: &str, hint: Option<FormatHint>) -> Result<Self> {
        let _ = CoInitializeEx(None, COINIT_MULTITHREADED).ok();
        let hint = hint.unwrap_or(FormatHint {
            sample_rate: 48_000,
            channels: 2,
            bit_depth: 24,
        });

        let chosen = {
            let enumerator: IMMDeviceEnumerator =
                CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL)?;
            let wide = to_wide(device_id);
            let device = enumerator.GetDevice(PCWSTR::from_raw(wide.as_ptr()))?;
            let probe_client: IAudioClient = device.Activate(CLSCTX_ALL, None)?;
            pick_format(&probe_client, hint)
        };
        CoUninitialize();

        let Some((sr, ch, pcm)) = chosen else {
            return Err(anyhow!(
                "Device '{}' has no exclusive PCM format near {}Hz",
                device_id,
                hint.sample_rate
            ));
        };

        crate::logger::info_output(format!(
            "[wasapi-exclusive] {sr}Hz {ch}ch {pcm:?} on {device_id}"
        ));

        let cap = ring_cap(sr, ch as u32);
        let rb = HeapRb::<f32>::new(cap);
        let (prod, cons) = rb.split();
        let producer: SharedProducer = Arc::new(Mutex::new(prod));
        let alive = Arc::new(AtomicBool::new(true));
        let draining = Arc::new(AtomicBool::new(false));
        let paused = Arc::new(AtomicBool::new(false));
        let alive_cb = alive.clone();
        let draining_cb = draining.clone();
        let paused_cb = paused.clone();
        let id = device_id.to_owned();

        let (ready_tx, ready_rx) = mpsc::channel();
        let _thread = thread::spawn(move || {
            run_audio_thread(
                id,
                sr,
                ch as u32,
                pcm,
                cons,
                alive_cb,
                draining_cb,
                paused_cb,
                ready_tx,
            );
        });

        match ready_rx.recv_timeout(Duration::from_secs(4)) {
            Ok(Ok(())) => Ok(Self {
                producer,
                draining,
                paused,
                sample_rate: sr,
                channels: ch as u32,
                pcm,
                device_id: device_id.to_owned(),
                _thread: Some(_thread),
                alive,
            }),
            Ok(Err(e)) => {
                alive.store(false, Ordering::SeqCst);
                let _ = _thread.join();
                Err(e)
            }
            Err(_) => {
                alive.store(false, Ordering::SeqCst);
                let _ = _thread.join();
                Err(anyhow!("WASAPI exclusive start timed out"))
            }
        }
    }
}

impl Drop for ExclusiveStream {
    fn drop(&mut self) {
        self.alive.store(false, Ordering::SeqCst);
        if let Some(t) = self._thread.take() {
            let _ = t.join();
        }
    }
}

fn kind_order(bits: u32) -> [PcmKind; 4] {
    match bits {
        16 => [PcmKind::S16, PcmKind::S24In32, PcmKind::S32, PcmKind::F32],
        32 => [PcmKind::S32, PcmKind::F32, PcmKind::S24In32, PcmKind::S16],
        _ => [PcmKind::S24In32, PcmKind::S32, PcmKind::F32, PcmKind::S16],
    }
}

fn rate_order(want: u32) -> Vec<u32> {
    let mut rates = vec![want];
    let mut rest: Vec<u32> = RATES.iter().copied().filter(|r| *r != want).collect();
    rest.sort_by_key(|r| r.abs_diff(want));
    rates.extend(rest);
    rates
}

fn ch_order(want: u32) -> Vec<u16> {
    let want = want.clamp(1, 8) as u16;
    let mut chs = vec![want];
    if want != 2 {
        chs.push(2);
    }
    if want != 1 {
        chs.push(1);
    }
    chs
}

unsafe fn pick_format(client: &IAudioClient, hint: FormatHint) -> Option<(u32, u16, PcmKind)> {
    let kinds = kind_order(hint.bit_depth);
    for rate in rate_order(hint.sample_rate) {
        for ch in ch_order(hint.channels) {
            for kind in kinds {
                if format_ok(client, rate, ch, kind) {
                    return Some((rate, ch, kind));
                }
            }
        }
    }
    None
}

fn fmt_ptr(ext: &WAVEFORMATEXTENSIBLE) -> *const WAVEFORMATEX {
    std::ptr::from_ref(ext).cast()
}

unsafe fn exclusive_supported(client: &IAudioClient, fmt: *const WAVEFORMATEX) -> bool {
    client
        .IsFormatSupported(AUDCLNT_SHAREMODE_EXCLUSIVE, fmt, None)
        .0
        == 0
}

unsafe fn format_ok(client: &IAudioClient, rate: u32, ch: u16, kind: PcmKind) -> bool {
    match kind {
        PcmKind::S16 | PcmKind::F32 => {
            let simple = make_waveformat(rate, ch, kind);
            if exclusive_supported(client, std::ptr::from_ref(&simple).cast()) {
                return true;
            }
            let ext = make_extensible(rate, ch, kind);
            exclusive_supported(client, fmt_ptr(&ext))
        }
        PcmKind::S24In32 | PcmKind::S32 => {
            let ext = make_extensible(rate, ch, kind);
            exclusive_supported(client, fmt_ptr(&ext))
        }
    }
}

fn make_waveformat(sample_rate: u32, channels: u16, kind: PcmKind) -> WAVEFORMATEX {
    let bits: u16 = match kind {
        PcmKind::S16 => 16,
        _ => 32,
    };
    let tag = match kind {
        PcmKind::F32 => WAVE_FORMAT_IEEE_FLOAT as u16,
        _ => WAVE_FORMAT_PCM as u16,
    };
    let block_align = channels * bits / 8;
    WAVEFORMATEX {
        wFormatTag: tag,
        nChannels: channels,
        nSamplesPerSec: sample_rate,
        nAvgBytesPerSec: sample_rate * block_align as u32,
        nBlockAlign: block_align,
        wBitsPerSample: bits,
        cbSize: 0,
    }
}

fn make_extensible(sample_rate: u32, channels: u16, kind: PcmKind) -> WAVEFORMATEXTENSIBLE {
    let valid = kind.bits() as u16;
    let container: u16 = match kind {
        PcmKind::S16 => 16,
        _ => 32,
    };
    let block_align = channels * container / 8;
    let mask = if channels == 1 {
        SPEAKER_FRONT_CENTER
    } else {
        SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT
    };
    let sub = if kind == PcmKind::F32 {
        KSDATAFORMAT_SUBTYPE_IEEE_FLOAT
    } else {
        KSDATAFORMAT_SUBTYPE_PCM
    };
    WAVEFORMATEXTENSIBLE {
        Format: WAVEFORMATEX {
            wFormatTag: WAVE_FORMAT_EXTENSIBLE as u16,
            nChannels: channels,
            nSamplesPerSec: sample_rate,
            nAvgBytesPerSec: sample_rate * block_align as u32,
            nBlockAlign: block_align,
            wBitsPerSample: container,
            cbSize: (std::mem::size_of::<WAVEFORMATEXTENSIBLE>()
                - std::mem::size_of::<WAVEFORMATEX>()) as u16,
        },
        Samples: WAVEFORMATEXTENSIBLE_0 {
            wValidBitsPerSample: valid,
        },
        dwChannelMask: mask,
        SubFormat: sub,
    }
}

fn run_audio_thread(
    device_id: String,
    sample_rate: u32,
    channels: u32,
    pcm: PcmKind,
    mut cons: ringbuf::HeapCons<f32>,
    alive: Arc<AtomicBool>,
    draining: Arc<AtomicBool>,
    paused: Arc<AtomicBool>,
    ready: mpsc::Sender<Result<()>>,
) {
    crate::logger::info_output(format!(
        "[wasapi-exclusive] audio thread {device_id} {pcm:?} {sample_rate}Hz"
    ));
    unsafe {
        let _ = CoInitializeEx(None, COINIT_MULTITHREADED).ok();
        let result = setup_wasapi(&device_id, sample_rate, channels, pcm);
        let (audio_client, render_client, buffer_frames, event) = match result {
            Ok(r) => {
                let _ = ready.send(Ok(()));
                r
            }
            Err(e) => {
                crate::logger::error_output(format!("[wasapi-exclusive] thread setup failed: {e}"));
                let _ = ready.send(Err(e));
                CoUninitialize();
                return;
            }
        };

        let frames = buffer_frames;
        let samples = frames * channels as usize;
        let bytes = samples * pcm.bytes_per_sample();
        let mut f32_scratch = vec![0f32; samples];
        let mut rng = Rng::new();

        loop {
            if !alive.load(Ordering::SeqCst) {
                break;
            }
            WaitForSingleObject(event, 100);
            let buf_ptr = match render_client.GetBuffer(frames as u32) {
                Ok(p) => p,
                Err(e) => {
                    crate::logger::warn_output(format!("[wasapi-exclusive] GetBuffer: {e}"));
                    break;
                }
            };
            let dst = std::slice::from_raw_parts_mut(buf_ptr, bytes);

            if draining.load(Ordering::Relaxed) {
                let avail = cons.occupied_len();
                cons.skip(avail);
                dst.fill(0);
            } else if paused.load(Ordering::Relaxed) {
                dst.fill(0);
            } else {
                let n = cons.occupied_len().min(samples);
                cons.pop_slice(&mut f32_scratch[..n]);
                f32_scratch[n..].fill(0.0);
                quantize(&f32_scratch, dst, pcm, &mut rng);
            }

            let _ = render_client.ReleaseBuffer(frames as u32, 0);
        }

        let _ = audio_client.Stop();
        CoUninitialize();
    }
}

unsafe fn setup_wasapi(
    device_id: &str,
    sample_rate: u32,
    channels: u32,
    pcm: PcmKind,
) -> Result<(IAudioClient, IAudioRenderClient, usize, HANDLE)> {
    let enumerator: IMMDeviceEnumerator = CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL)?;
    let wide = to_wide(device_id);
    let device = enumerator.GetDevice(PCWSTR::from_raw(wide.as_ptr()))?;
    let audio_client: IAudioClient = device.Activate(CLSCTX_ALL, None)?;

    const PREFERRED_DUR: i64 = 1_000_000;
    let ext;
    let simple;
    let fmt: *const WAVEFORMATEX = match pcm {
        PcmKind::S24In32 | PcmKind::S32 => {
            ext = make_extensible(sample_rate, channels as u16, pcm);
            fmt_ptr(&ext)
        }
        PcmKind::S16 | PcmKind::F32 => {
            simple = make_waveformat(sample_rate, channels as u16, pcm);
            if exclusive_supported(&audio_client, std::ptr::from_ref(&simple).cast()) {
                std::ptr::from_ref(&simple).cast()
            } else {
                ext = make_extensible(sample_rate, channels as u16, pcm);
                fmt_ptr(&ext)
            }
        }
    };

    let init_result = audio_client.Initialize(
        AUDCLNT_SHAREMODE_EXCLUSIVE,
        AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
        PREFERRED_DUR,
        PREFERRED_DUR,
        fmt,
        None,
    );

    let audio_client = match init_result {
        Ok(()) => audio_client,
        Err(ref e) if e.code() == AUDCLNT_E_BUFFER_SIZE_NOT_ALIGNED => {
            let aligned_frames = audio_client.GetBufferSize()? as u64;
            let aligned_dur = (aligned_frames * 10_000_000) / sample_rate as u64;
            crate::logger::info_output(format!(
                "[wasapi-exclusive] alignment fix: {aligned_frames} frames"
            ));
            let wide2 = to_wide(device_id);
            let device2 = enumerator.GetDevice(PCWSTR::from_raw(wide2.as_ptr()))?;
            let ac2: IAudioClient = device2.Activate(CLSCTX_ALL, None)?;
            ac2.Initialize(
                AUDCLNT_SHAREMODE_EXCLUSIVE,
                AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
                aligned_dur as i64,
                aligned_dur as i64,
                fmt,
                None,
            )?;
            ac2
        }
        Err(e) => {
            let code = e.code().0 as u32;
            return Err(anyhow!(
                "wasapi exclusive Initialize failed: {e} (0x{code:08x})"
            ));
        }
    };

    let event = CreateEventW(None, false, false, None)?;
    audio_client.SetEventHandle(event)?;
    let render_client: IAudioRenderClient = audio_client.GetService()?;
    let buffer_frames = audio_client.GetBufferSize()? as usize;
    audio_client.Start()?;
    crate::logger::info_output(format!(
        "[wasapi-exclusive] started, buffer_frames={buffer_frames}"
    ));
    Ok((audio_client, render_client, buffer_frames, event))
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

unsafe fn build_device_info(device: &IMMDevice, default_id: &Option<String>) -> Option<DeviceInfo> {
    let id = get_device_id(device).ok()?;
    let store: IPropertyStore = device.OpenPropertyStore(STGM_READ).ok()?;
    let name = get_property_string(
        &store,
        &DEVPKEY_Device_FriendlyName as *const _ as *const PROPERTYKEY,
    )?;
    let supports_exclusive = probe_exclusive_device(device);
    let is_default = default_id.as_deref() == Some(&id);
    Some(DeviceInfo {
        id,
        name,
        is_default,
        supports_exclusive,
    })
}

unsafe fn get_property_string(
    property_store: &IPropertyStore,
    property_key: *const PROPERTYKEY,
) -> Option<String> {
    let mut property_value = property_store.GetValue(property_key).ok()?;
    let prop_variant = &property_value.Anonymous.Anonymous;
    if prop_variant.vt != VT_LPWSTR {
        let _ = StructuredStorage::PropVariantClear(&mut property_value);
        return None;
    }
    let ptr_utf16 = *(&prop_variant.Anonymous as *const _ as *const *const u16);
    const MAX_STRING_LEN: usize = 32768;
    let mut len = 0;
    while len < MAX_STRING_LEN && *ptr_utf16.add(len) != 0 {
        len += 1;
    }
    if len >= MAX_STRING_LEN {
        let _ = StructuredStorage::PropVariantClear(&mut property_value);
        return None;
    }
    let string_slice = std::slice::from_raw_parts(ptr_utf16, len);
    let os_string = OsString::from_wide(string_slice);
    let result = os_string.to_string_lossy().into_owned();
    let _ = StructuredStorage::PropVariantClear(&mut property_value);
    Some(result)
}

unsafe fn probe_exclusive_device(device: &IMMDevice) -> bool {
    let Ok(client) = device.Activate::<IAudioClient>(CLSCTX_ALL, None) else {
        return false;
    };
    pick_format(
        &client,
        FormatHint {
            sample_rate: 48_000,
            channels: 2,
            bit_depth: 24,
        },
    )
    .is_some()
}

fn to_wide(s: &str) -> Vec<u16> {
    s.encode_utf16().chain(std::iter::once(0)).collect()
}
