use crate::{
    audio_engine::AudioEngine, logger, metadata, plugin_engine, plugin_engine::PluginEvent,
    PlaybackPosition, TrackInfo,
};
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
    logger::init();
    crate::plugin_engine::engine_init();
    AudioEngine::init_default()
}
pub fn init_engine_with_device(device_id: String, exclusive: bool) -> Result<()> {
    logger::init();
    crate::plugin_engine::engine_init();
    AudioEngine::init_with_device(&device_id, exclusive)
}
pub fn reinit_engine(device_id: String, exclusive: bool) -> Result<()> {
    AudioEngine::reinit(&device_id, exclusive)
}
pub fn recover_engine() -> Result<()> {
    AudioEngine::recover_engine()
}
#[frb(sync)]
pub fn is_decode_thread_dead() -> bool {
    AudioEngine::global_opt()
        .map(|a| a.lock().unwrap().is_decode_thread_dead())
        .unwrap_or(false)
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

// Helper
fn engine() -> Result<std::sync::Arc<std::sync::Mutex<AudioEngine>>> {
    AudioEngine::global_opt().ok_or_else(|| anyhow::anyhow!("AudioEngine not ready"))
}

// Playback
pub fn load_track(path: String) -> Result<TrackInfo> {
    let info = metadata::read_track_info(&path)?;
    engine()?.lock().unwrap().load(&path)?;
    Ok(info)
}
pub fn play() -> Result<()> {
    engine()?.lock().unwrap().play()
}
pub fn pause() -> Result<()> {
    engine()?.lock().unwrap().pause()
}
pub fn stop() -> Result<()> {
    engine()?.lock().unwrap().stop()
}
pub fn seek(position_secs: f64) -> Result<()> {
    engine()?.lock().unwrap().seek(position_secs)
}
pub fn set_volume(volume: f32) -> Result<()> {
    engine()?.lock().unwrap().set_volume(volume)
}
pub fn get_position() -> Result<PlaybackPosition> {
    engine()?.lock().unwrap().get_position()
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
    engine()?.lock().unwrap().set_replay_gain(linear_gain);
    Ok(())
}
pub fn set_soft_clip(enabled: bool) -> Result<()> {
    engine()?.lock().unwrap().set_soft_clip(enabled);
    Ok(())
}
pub fn set_skip_silence(enabled: bool) -> Result<()> {
    engine()?.lock().unwrap().set_skip_silence(enabled);
    Ok(())
}
pub fn set_gapless(enabled: bool) -> Result<()> {
    engine()?.lock().unwrap().set_gapless(enabled);
    Ok(())
}
pub fn set_crossfade_secs(secs: f32) -> Result<()> {
    engine()?.lock().unwrap().set_crossfade_secs(secs);
    Ok(())
}

// EQ
pub fn set_eq_enabled(enabled: bool) -> Result<()> {
    engine()?.lock().unwrap().set_eq_enabled(enabled);
    Ok(())
}
pub fn set_eq_gains(gains: Vec<f32>) -> Result<()> {
    engine()?.lock().unwrap().set_eq_gains(gains);
    Ok(())
}
pub fn set_eq_band(band: u32, gain_db: f32) -> Result<()> {
    engine()?
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

// Stereo enhance
pub fn set_stereo_width(width: f32) -> Result<()> {
    engine()?.lock().unwrap().set_stereo_width(width);
    Ok(())
}
pub fn set_haas_ms(ms: f32) -> Result<()> {
    engine()?.lock().unwrap().set_haas_ms(ms);
    Ok(())
}
#[frb(sync)]
pub fn get_stereo_width() -> f32 {
    AudioEngine::global_opt()
        .map(|a| a.lock().unwrap().get_stereo_width())
        .unwrap_or(1.0)
}
#[frb(sync)]
pub fn get_haas_ms() -> f32 {
    AudioEngine::global_opt()
        .map(|a| a.lock().unwrap().get_haas_ms())
        .unwrap_or(0.0)
}
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
pub fn read_album_art_thumbnail(path: String) -> Result<Option<Vec<u8>>> {
    metadata::read_album_art_thumbnail(&path)
}
pub fn evict_thumbnail_cache(path: String) {
    metadata::evict_thumbnail_cache(&path);
}
pub fn scan_directory(path: String) -> Result<Vec<String>> {
    metadata::scan_directory(&path)
}
pub fn read_embedded_lyrics(path: String) -> Result<Option<String>> {
    metadata::read_embedded_lyrics(&path)
}

pub fn set_log_path(path: String) -> () {
    logger::set_path(path);
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

// Plugin engine
#[frb(sync)]
pub fn plugin_is_enabled(id: String) -> bool {
    plugin_engine::with_engine_read(|e| e.is_enabled(&id)).unwrap_or(false)
}

#[frb(sync)]
pub fn plugin_loaded_ids() -> Vec<String> {
    plugin_engine::with_engine_read(|e| e.loaded_ids()).unwrap_or_default()
}

#[frb(sync)]
pub fn plugin_manifest_json(id: String) -> Option<String> {
    plugin_engine::with_engine_read(|e| {
        e.manifest(&id).and_then(|m| serde_json::to_string(&m).ok())
    })
    .flatten()
}

pub fn plugin_load(dir_path: String) -> Result<String> {
    plugin_engine::with_engine(|e| e.load_plugin(std::path::Path::new(&dir_path)))?
}

pub fn plugin_unload(id: String) {
    let _ = plugin_engine::with_engine(|e| e.unload_plugin(&id));
}

pub fn plugin_set_enabled(id: String, enabled: bool) {
    let _ = plugin_engine::with_engine(|e| e.set_enabled(&id, enabled));
}

pub fn plugin_dispatch_track_start(
    title: String,
    artist: String,
    album: Option<String>,
    duration_secs: f64,
    path: String,
) {
    plugin_engine::with_engine_read(|e| {
        e.dispatch(&PluginEvent::TrackStart {
            title,
            artist,
            album,
            duration_secs,
            path,
        });
    });
}

pub fn plugin_dispatch_track_stop(title: Option<String>, artist: Option<String>) {
    plugin_engine::with_engine_read(|e| {
        e.dispatch(&PluginEvent::TrackStop { title, artist });
    });
}

pub fn plugin_dispatch_play_pause(is_playing: bool, position_secs: f64) {
    plugin_engine::with_engine_read(|e| {
        e.dispatch(&PluginEvent::PlayPause {
            is_playing,
            position_secs,
        });
    });
}

pub fn plugin_dispatch_position_update(position_secs: f64, duration_secs: f64, progress: f64) {
    plugin_engine::with_engine_read(|e| {
        e.dispatch(&PluginEvent::PositionUpdate {
            position_secs,
            duration_secs,
            progress,
        });
    });
}

pub fn plugin_dispatch_track_complete(
    title: String,
    artist: String,
    duration_secs: f64,
    path: String,
) {
    plugin_engine::with_engine_read(|e| {
        e.dispatch(&PluginEvent::TrackComplete {
            title,
            artist,
            duration_secs,
            path,
        });
    });
}

pub fn plugin_dispatch_library_scan_start() {
    plugin_engine::with_engine_read(|e| e.dispatch(&PluginEvent::LibraryScanStart));
}

pub fn plugin_dispatch_library_scan_complete(total: u32) {
    plugin_engine::with_engine_read(|e| {
        e.dispatch(&PluginEvent::LibraryScanComplete { total });
    });
}

pub fn plugin_dispatch_track_loved(title: String, artist: String, loved: bool) {
    plugin_engine::with_engine_read(|e| {
        e.dispatch(&PluginEvent::TrackLoved {
            title,
            artist,
            loved,
        });
    });
}

pub fn plugin_dispatch_app_foreground() {
    plugin_engine::with_engine_read(|e| e.dispatch(&PluginEvent::AppForeground));
}
