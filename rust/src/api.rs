use crate::{audio_engine::AudioEngine, metadata, PlaybackPosition, TrackInfo};
use anyhow::Result;
use flutter_rust_bridge::frb;

// Engine lifecycle
#[frb(sync)]
pub fn init_engine() -> Result<()> {
    AudioEngine::init()
}

// Playback control
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

// State queries
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

pub fn get_spectrum_data(bucket_count: u32) -> Vec<f32> {
    let Some(arc) = AudioEngine::global_opt() else {
        return vec![];
    };
    let engine = arc.lock().unwrap();
    engine.get_spectrum_data(bucket_count as usize)
}

pub fn discord_update_playing(
    title: String,
    artist: String,
    album: String,
    position_secs: f64,
    duration_secs: f64,
) -> Result<()> {
    crate::discord_rpc::update_playing(&title, &artist, &album, position_secs, duration_secs)
}

// Paused state.
pub fn discord_update_paused(title: String, artist: String) -> Result<()> {
    crate::discord_rpc::update_paused(&title, &artist)
}

// Clear Discord Rich Presence
pub fn discord_clear() -> Result<()> {
    crate::discord_rpc::clear()
}