pub mod api;
pub mod audio_engine;
pub mod decoder;
pub mod discord_rpc;
pub mod eq;
mod frb_generated;
pub mod metadata;
pub mod output;
pub mod resampler;

use flutter_rust_bridge::frb;

#[frb(dart_metadata = ("freezed"))]
pub struct TrackInfo {
    pub path: String,
    pub title: Option<String>,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub album_artist: Option<String>,
    pub track_number: Option<u32>,
    pub duration_secs: f64,
    pub sample_rate: u32,
    pub bit_depth: Option<u32>,
    pub channels: u32,
    pub format: String,
    pub file_size_bytes: u64,
    pub replay_gain_track: Option<f64>,
    pub replay_gain_album: Option<f64>,
}

pub struct PlaybackPosition {
    pub position_secs: f64,
    pub duration_secs: f64,
    pub sample_rate: u32,
    pub bit_depth: u32,
}
