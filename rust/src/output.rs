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
use std::thread;
use std::time::Duration;

pub type SharedProducer = crate::audio_io::SharedProducer;

#[derive(Clone, Copy, Debug)]
pub struct FormatHint {
    pub sample_rate: u32,
    pub channels: u32,
    pub bit_depth: u32,
}

pub struct AudioOutput {
    _stream: Option<AudioStream>,
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

#[derive(Clone)]
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

    pub(crate) fn closed() -> Self {
        let rb = HeapRb::<f32>::new(64);
        let (prod, _) = rb.split();
        Self {
            _stream: None,
            producer: Arc::new(std::sync::Mutex::new(prod)),
            draining: Arc::new(AtomicBool::new(true)),
            paused: Arc::new(AtomicBool::new(true)),
            sample_rate: 48_000,
            channels: 2,
            exclusive: false,
            device_id: None,
        }
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
        prepare_mixer(device_id, exclusive);
        let tries = if exclusive { 6 } else { 1 };
        let mut last = None;
        for i in 0..tries {
            match Self::open_once(device_id, exclusive, hint) {
                Ok(out) => return Ok(out),
                Err(e) if exclusive && is_device_busy(&e) && i + 1 < tries => {
                    crate::logger::warn_output(format!(
                        "device busy, retry {}/{tries}: {e}",
                        i + 1
                    ));
                    #[cfg(target_os = "linux")]
                    {
                        PULSE_SUSPENDED.store(false, Ordering::SeqCst);
                        suspend_pulse_sinks();
                    }
                    thread::sleep(Duration::from_millis(80 * (i as u64 + 1)));
                    last = Some(e);
                }
                Err(e) => {
                    if exclusive {
                        prepare_mixer(None, false);
                    }
                    return Err(e);
                }
            }
        }
        if exclusive {
            prepare_mixer(None, false);
        }
        Err(last.unwrap_or_else(|| anyhow!("device busy")))
    }

    fn open_once(
        device_id: Option<&str>,
        exclusive: bool,
        hint: Option<FormatHint>,
    ) -> Result<Self> {
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
            _stream: Some(AudioStream::WasapiExclusive(exc)),
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
            _stream: Some(AudioStream::Cpal(stream)),
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

impl Drop for AudioOutput {
    fn drop(&mut self) {
        self._stream.take();
        #[cfg(target_os = "linux")]
        if self.exclusive {
            resume_pulse_sinks();
        }
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

fn is_device_busy(err: &anyhow::Error) -> bool {
    let s = err.to_string().to_ascii_lowercase();
    s.contains("busy")
        || s.contains("device_in_use")
        || s.contains("-2004287478")
        || s.contains("8889000a")
}

fn prepare_mixer(device_id: Option<&str>, exclusive: bool) {
    #[cfg(target_os = "linux")]
    {
        if exclusive && device_id.is_some_and(is_alsa_hw_id) {
            suspend_pulse_sinks();
        } else {
            resume_pulse_sinks();
        }
    }
    #[cfg(not(target_os = "linux"))]
    {
        let _ = device_id;
    }
    if exclusive {
        thread::sleep(Duration::from_millis(150));
    }
}

#[cfg(target_os = "linux")]
static PULSE_SUSPENDED: AtomicBool = AtomicBool::new(false);

#[cfg(target_os = "linux")]
fn pactl(args: &[&str]) -> bool {
    std::process::Command::new("pactl")
        .args(args)
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

#[cfg(target_os = "linux")]
fn suspend_pulse_sinks() {
    if PULSE_SUSPENDED.swap(true, Ordering::SeqCst) {
        return;
    }
    crate::logger::info_output(
        "suspending PipeWire/Pulse sinks so ALSA hw: can open exclusively",
    );
    let listed = std::process::Command::new("pactl")
        .args(["list", "short", "sinks"])
        .stdin(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .output()
        .ok();
    let mut any = false;
    if let Some(out) = listed {
        for line in String::from_utf8_lossy(&out.stdout).lines() {
            let id = line.split_whitespace().next().unwrap_or("");
            if !id.is_empty() {
                any |= pactl(&["suspend-sink", id, "1"]);
            }
        }
    }
    any |= pactl(&["suspend-sink", "@DEFAULT_SINK@", "1"]);
    if !any {
        crate::logger::warn_output(
            "pactl suspend-sink failed; ALSA hw: may stay busy while PipeWire holds the card",
        );
    }
}

#[cfg(target_os = "linux")]
fn resume_pulse_sinks() {
    if !PULSE_SUSPENDED.swap(false, Ordering::SeqCst) {
        return;
    }
    crate::logger::info_output("resuming PipeWire/Pulse sinks");
    if let Ok(out) = std::process::Command::new("pactl")
        .args(["list", "short", "sinks"])
        .stdin(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .output()
    {
        for line in String::from_utf8_lossy(&out.stdout).lines() {
            let id = line.split_whitespace().next().unwrap_or("");
            if !id.is_empty() {
                let _ = pactl(&["suspend-sink", id, "0"]);
            }
        }
    }
    let _ = pactl(&["suspend-sink", "@DEFAULT_SINK@", "0"]);
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

fn is_system_default_id(id: &str) -> bool {
    matches!(
        id,
        "default"
            | "alsa:default"
            | "pipewire:output_default"
            | "pipewire:sink_default"
    )
}

fn find_device(host: &cpal::Host, id: &str) -> Option<cpal::Device> {
    use cpal::traits::{DeviceTrait, HostTrait};
    if is_system_default_id(id) {
        return host.default_output_device();
    }
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
    #[cfg(any(
        target_os = "linux",
        target_os = "dragonfly",
        target_os = "freebsd",
        target_os = "netbsd"
    ))]
    {
        return enumerate_linux_devices();
    }
    #[cfg(not(any(
        target_os = "linux",
        target_os = "dragonfly",
        target_os = "freebsd",
        target_os = "netbsd"
    )))]
    {
        use cpal::traits::{DeviceTrait, HostTrait};
        let host = audio_host();
        let default_id = host
            .default_output_device()
            .and_then(|d| d.id().ok().map(|id| id.to_string()));
        let mut out = Vec::new();
        if let Ok(devs) = host.output_devices() {
            for d in devs {
                let id = device_id_string(&d);
                out.push(CpalDeviceInfo {
                    is_default: default_id.as_deref() == Some(id.as_str()),
                    id,
                    name: device_name(&d),
                    supports_exclusive: false,
                });
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
}

#[cfg(any(
    target_os = "linux",
    target_os = "dragonfly",
    target_os = "freebsd",
    target_os = "netbsd"
))]
fn enumerate_linux_devices() -> Result<Vec<CpalDeviceInfo>> {
    use cpal::traits::{DeviceTrait, HostTrait};
    use std::collections::{HashMap, HashSet};

    let host = audio_host();
    let mut out = Vec::new();
    if let Some(d) = host.default_output_device() {
        let mut name = device_name(&d);
        if name.is_empty() || name == "unknown" {
            name = "System default".into();
        }
        out.push(CpalDeviceInfo {
            id: device_id_string(&d),
            name,
            is_default: true,
            supports_exclusive: false,
        });
    }

    let card_ids = alsa_card_id_map();
    let mut best: HashMap<(u32, u32), (u8, CpalDeviceInfo)> = HashMap::new();
    if let Ok(alsa) = cpal::host_from_id(cpal::HostId::Alsa) {
        if let Ok(devs) = alsa.output_devices() {
            for d in devs {
                let Ok(did) = d.id() else {
                    continue;
                };
                let pcm = did.id();
                if !pcm.starts_with("hw:") {
                    continue;
                }
                let Some((card, dev)) = parse_alsa_hw(pcm) else {
                    continue;
                };
                let key = (resolve_alsa_card(&card, &card_ids), dev);
                let rank = alsa_hw_rank(pcm);
                let name = device_name(&d);
                let info = CpalDeviceInfo {
                    id: did.to_string(),
                    name: format!("{name} (ALSA hw)"),
                    is_default: false,
                    supports_exclusive: true,
                };
                match best.get(&key) {
                    Some((r, _)) if rank >= *r => {}
                    _ => {
                        best.insert(key, (rank, info));
                    }
                }
            }
        }
    }

    let mut hw: Vec<CpalDeviceInfo> = best.into_values().map(|(_, i)| i).collect();
    hw.sort_by(|a, b| a.id.cmp(&b.id));
    let mut used_names: HashSet<String> = out.iter().map(|e| e.name.clone()).collect();
    for mut info in hw {
        if out.iter().any(|e| e.id == info.id) {
            continue;
        }
        if !used_names.insert(info.name.clone()) {
            let pcm = info.id.strip_prefix("alsa:").unwrap_or(&info.id);
            info.name = format!("{} ({pcm})", info.name.trim_end_matches(" (ALSA hw)"));
            used_names.insert(info.name.clone());
        }
        out.push(info);
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

#[cfg(any(
    target_os = "linux",
    target_os = "dragonfly",
    target_os = "freebsd",
    target_os = "netbsd",
    test
))]
#[derive(Debug, Clone, PartialEq, Eq)]
enum AlsaCard {
    Index(u32),
    Name(String),
}

#[cfg(any(
    target_os = "linux",
    target_os = "dragonfly",
    target_os = "freebsd",
    target_os = "netbsd",
    test
))]
fn parse_alsa_hw(pcm: &str) -> Option<(AlsaCard, u32)> {
    let rest = pcm
        .strip_prefix("alsa:")
        .unwrap_or(pcm)
        .strip_prefix("hw:")?;
    if rest.starts_with("CARD=") {
        let mut card = None;
        let mut dev = 0u32;
        for part in rest.split(',') {
            if let Some(v) = part.strip_prefix("CARD=") {
                card = Some(v.trim());
            } else if let Some(v) = part.strip_prefix("DEV=") {
                dev = v.trim().parse().ok()?;
            }
        }
        let card = card?;
        if let Ok(n) = card.parse::<u32>() {
            return Some((AlsaCard::Index(n), dev));
        }
        return Some((AlsaCard::Name(card.to_string()), dev));
    }
    let mut parts = rest.split(',');
    let first = parts.next()?.trim();
    let dev = parts
        .next()
        .map(|s| s.trim().parse::<u32>().ok())
        .unwrap_or(Some(0))?;
    if let Ok(n) = first.parse::<u32>() {
        Some((AlsaCard::Index(n), dev))
    } else if !first.is_empty() {
        Some((AlsaCard::Name(first.to_string()), dev))
    } else {
        None
    }
}

#[cfg(any(
    target_os = "linux",
    target_os = "dragonfly",
    target_os = "freebsd",
    target_os = "netbsd",
    test
))]
fn alsa_hw_rank(pcm: &str) -> u8 {
    let rest = pcm
        .strip_prefix("alsa:")
        .unwrap_or(pcm)
        .strip_prefix("hw:")
        .unwrap_or(pcm);
    if let Some(card) = rest
        .split(',')
        .next()
        .and_then(|s| s.strip_prefix("CARD="))
    {
        if card.parse::<u32>().is_err() {
            0
        } else {
            1
        }
    } else {
        2
    }
}

#[cfg(any(
    target_os = "linux",
    target_os = "dragonfly",
    target_os = "freebsd",
    target_os = "netbsd",
    test
))]
fn resolve_alsa_card(card: &AlsaCard, ids: &std::collections::HashMap<String, u32>) -> u32 {
    match card {
        AlsaCard::Index(n) => *n,
        AlsaCard::Name(name) => ids.get(name).copied().unwrap_or(u32::MAX),
    }
}

#[cfg(any(
    target_os = "linux",
    target_os = "dragonfly",
    target_os = "freebsd",
    target_os = "netbsd"
))]
fn alsa_card_id_map() -> std::collections::HashMap<String, u32> {
    let mut map = std::collections::HashMap::new();
    let Ok(text) = std::fs::read_to_string("/proc/asound/cards") else {
        return map;
    };
    for line in text.lines() {
        let line = line.trim_start();
        let mut parts = line.split_whitespace();
        let Some(idx) = parts.next().and_then(|s| s.parse::<u32>().ok()) else {
            continue;
        };
        let Some(start) = line.find('[') else {
            continue;
        };
        let Some(end) = line[start + 1..].find(']') else {
            continue;
        };
        let id = line[start + 1..start + 1 + end].trim().to_string();
        if !id.is_empty() {
            map.insert(id, idx);
        }
    }
    map
}

#[cfg(test)]
mod alsa_hw_id_tests {
    use super::*;

    #[test]
    fn parse_numeric_hw() {
        assert_eq!(parse_alsa_hw("hw:0,0"), Some((AlsaCard::Index(0), 0)));
        assert_eq!(parse_alsa_hw("hw:1"), Some((AlsaCard::Index(1), 0)));
        assert_eq!(
            parse_alsa_hw("alsa:hw:2,3"),
            Some((AlsaCard::Index(2), 3))
        );
    }

    #[test]
    fn parse_named_hw() {
        assert_eq!(
            parse_alsa_hw("hw:CARD=PCH,DEV=0"),
            Some((AlsaCard::Name("PCH".into()), 0))
        );
        assert_eq!(
            parse_alsa_hw("hw:CARD=0,DEV=1"),
            Some((AlsaCard::Index(0), 1))
        );
        assert_eq!(
            parse_alsa_hw("hw:PCH,1"),
            Some((AlsaCard::Name("PCH".into()), 1))
        );
    }

    #[test]
    fn named_hw_outranks_numeric() {
        assert!(alsa_hw_rank("hw:CARD=PCH,DEV=0") < alsa_hw_rank("hw:CARD=0,DEV=0"));
        assert!(alsa_hw_rank("hw:CARD=0,DEV=0") < alsa_hw_rank("hw:0,0"));
    }

    #[test]
    fn resolve_named_card() {
        let mut ids = std::collections::HashMap::new();
        ids.insert("PCH".into(), 0);
        assert_eq!(resolve_alsa_card(&AlsaCard::Name("PCH".into()), &ids), 0);
        assert_eq!(resolve_alsa_card(&AlsaCard::Index(1), &ids), 1);
    }

    #[test]
    fn system_default_aliases() {
        assert!(is_system_default_id("pipewire:output_default"));
        assert!(is_system_default_id("alsa:default"));
        assert!(!is_system_default_id("alsa:hw:CARD=PCH,DEV=0"));
    }
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
