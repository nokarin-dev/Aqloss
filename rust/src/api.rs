use crate::{audio_engine::AudioEngine, metadata, PlaybackPosition, TrackInfo};
use anyhow::Result;
use flutter_rust_bridge::frb;

#[frb(sync)]
pub fn init_engine() -> Result<()> {
    AudioEngine::init()
}

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
        .map(|arc| arc.lock().unwrap().is_playing())
        .unwrap_or(false)
}

#[frb(sync)]
pub fn is_exclusive_mode() -> bool {
    AudioEngine::global_opt()
        .map(|arc| arc.lock().unwrap().is_exclusive())
        .unwrap_or(false)
}

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

pub fn get_spectrum_data(bucket_count: u32) -> Vec<f32> {
    let Some(arc) = AudioEngine::global_opt() else {
        return vec![];
    };
    let x = arc.lock().unwrap().get_spectrum_data(bucket_count as usize);
    x
}

/// Update Discord presence while playing.
pub fn discord_update_playing(
    title: String,
    artist: String,
    album: String,
    album_art_url: String,
    position_secs: f64,
    duration_secs: f64,
) -> Result<()> {
    let url_opt = if album_art_url.is_empty() {
        None
    } else {
        Some(album_art_url.as_str())
    };
    crate::discord_rpc::update_playing(
        &title,
        &artist,
        &album,
        url_opt,
        position_secs,
        duration_secs,
    )
}

pub fn discord_update_paused(
    title: String,
    artist: String,
    album: String,
    album_art_url: String,
) -> Result<()> {
    let url_opt = if album_art_url.is_empty() {
        None
    } else {
        Some(album_art_url.as_str())
    };
    crate::discord_rpc::update_paused(&title, &artist, &album, url_opt)
}

pub fn discord_clear() -> Result<()> {
    crate::discord_rpc::clear()
}
