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
