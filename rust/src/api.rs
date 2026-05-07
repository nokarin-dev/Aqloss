use crate::{audio_engine::AudioEngine, metadata, PlaybackPosition, TrackInfo};
use anyhow::Result;
use flutter_rust_bridge::frb;

// Audio device info
pub struct AudioDeviceInfo {
    pub id: String,
    pub name: String,
    pub is_default: bool,
    pub supports_exclusive: bool,
}

// Engine lifecycle
pub fn init_engine() -> Result<()> {
    AudioEngine::init_default()
}
pub fn init_engine_with_device(device_id: String, exclusive: bool) -> Result<()> {
    AudioEngine::init_with_device(&device_id, exclusive)
}
pub fn reinit_engine(device_id: String, exclusive: bool) -> Result<()> {
    AudioEngine::reinit(&device_id, exclusive)
}

// Device enumeration
pub fn enumerate_audio_devices() -> Result<Vec<AudioDeviceInfo>> {
    #[cfg(target_os = "windows")]
    {
        use crate::output::wasapi_exclusive;
        return Ok(wasapi_exclusive::enumerate_devices()?
            .into_iter()
            .map(|d| AudioDeviceInfo {
                id: d.id,
                name: d.name,
                is_default: d.is_default,
                supports_exclusive: d.supports_exclusive,
            })
            .collect());
    }
    #[cfg(not(target_os = "windows"))]
    Ok(vec![AudioDeviceInfo {
        id: "default".into(),
        name: "System default".into(),
        is_default: true,
        supports_exclusive: false,
    }])
}

// Playback
pub fn load_track(path: String) -> Result<TrackInfo> {
    let info = metadata::read_track_info(&path)?;
    AudioEngine::global().lock().unwrap().load(&path)?;
    Ok(info)
}
pub fn play() -> Result<()> {
    AudioEngine::global().lock().unwrap().play()
}
pub fn pause() -> Result<()> {
    AudioEngine::global().lock().unwrap().pause()
}
pub fn stop() -> Result<()> {
    AudioEngine::global().lock().unwrap().stop()
}
pub fn seek(position_secs: f64) -> Result<()> {
    AudioEngine::global().lock().unwrap().seek(position_secs)
}
pub fn set_volume(volume: f32) -> Result<()> {
    AudioEngine::global().lock().unwrap().set_volume(volume)
}
pub fn get_position() -> Result<PlaybackPosition> {
    AudioEngine::global().lock().unwrap().get_position()
}

#[frb(sync)]
pub fn is_playing() -> bool {
    AudioEngine::global_opt()
        .map(|a| a.lock().unwrap().is_playing())
        .unwrap_or(false)
}
#[frb(sync)]
pub fn is_exclusive_mode() -> bool {
    AudioEngine::global_opt()
        .map(|a| a.lock().unwrap().is_exclusive())
        .unwrap_or(false)
}

// DSP
pub fn set_replay_gain(linear_gain: f32) -> Result<()> {
    AudioEngine::global()
        .lock()
        .unwrap()
        .set_replay_gain(linear_gain);
    Ok(())
}
pub fn set_soft_clip(enabled: bool) -> Result<()> {
    AudioEngine::global().lock().unwrap().set_soft_clip(enabled);
    Ok(())
}
pub fn set_skip_silence(enabled: bool) -> Result<()> {
    AudioEngine::global()
        .lock()
        .unwrap()
        .set_skip_silence(enabled);
    Ok(())
}
pub fn set_gapless(enabled: bool) -> Result<()> {
    AudioEngine::global().lock().unwrap().set_gapless(enabled);
    Ok(())
}
pub fn set_crossfade_secs(secs: f32) -> Result<()> {
    AudioEngine::global()
        .lock()
        .unwrap()
        .set_crossfade_secs(secs);
    Ok(())
}

// EQ
pub fn set_eq_enabled(enabled: bool) -> Result<()> {
    AudioEngine::global()
        .lock()
        .unwrap()
        .set_eq_enabled(enabled);
    Ok(())
}
pub fn set_eq_gains(gains: Vec<f32>) -> Result<()> {
    AudioEngine::global().lock().unwrap().set_eq_gains(gains);
    Ok(())
}
pub fn set_eq_band(band: u32, gain_db: f32) -> Result<()> {
    AudioEngine::global()
        .lock()
        .unwrap()
        .set_eq_band(band as usize, gain_db);
    Ok(())
}
pub fn get_eq_gains() -> Vec<f32> {
    AudioEngine::global_opt()
        .map(|a| a.lock().unwrap().get_eq_gains())
        .unwrap_or_else(|| vec![0.0; 10])
}

// Spectrum
pub fn get_spectrum_data(bucket_count: u32) -> Vec<f32> {
    AudioEngine::global_opt()
        .map(|a| a.lock().unwrap().get_spectrum_data(bucket_count as usize))
        .unwrap_or_default()
}

// Metadata
pub fn read_metadata(path: String) -> Result<TrackInfo> {
    metadata::read_track_info(&path)
}
pub fn read_album_art(path: String) -> Result<Option<Vec<u8>>> {
    metadata::read_album_art(&path)
}
pub fn scan_directory(path: String) -> Result<Vec<String>> {
    metadata::scan_directory(&path)
}
pub fn read_embedded_lyrics(path: String) -> Result<Option<String>> {
    metadata::read_embedded_lyrics(&path)
}

// Discord RPC
pub fn discord_update_playing(
    title: String,
    artist: String,
    album: String,
    album_art_url: String,
    position_secs: f64,
    duration_secs: f64,
) -> Result<()> {
    let url = if album_art_url.is_empty() {
        None
    } else {
        Some(album_art_url.as_str())
    };
    crate::discord_rpc::update_playing(&title, &artist, &album, url, position_secs, duration_secs)
}
pub fn discord_update_paused(
    title: String,
    artist: String,
    album: String,
    album_art_url: String,
) -> Result<()> {
    let url = if album_art_url.is_empty() {
        None
    } else {
        Some(album_art_url.as_str())
    };
    crate::discord_rpc::update_paused(&title, &artist, &album, url)
}
pub fn discord_clear() -> Result<()> {
    crate::discord_rpc::clear()
}
