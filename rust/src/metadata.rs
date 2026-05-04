use crate::TrackInfo;
use anyhow::Result;
use lofty::prelude::{Accessor, AudioFile, ItemKey, TaggedFileExt};
use std::path::Path;

pub fn read_track_info(path: &str) -> Result<TrackInfo> {
    let tagged = lofty::read_from_path(path)?;
    let props = tagged.properties();
    let tag = tagged.primary_tag();

    let title = tag.and_then(|t| t.title().map(|s| s.into_owned()));
    let artist = tag.and_then(|t| t.artist().map(|s| s.into_owned()));
    let album = tag.and_then(|t| t.album().map(|s| s.into_owned()));
    let album_artist = tag.and_then(|t| t.get_string(ItemKey::AlbumArtist).map(|s| s.to_owned()));
    let track_number = tag.and_then(|t| t.track());

    let duration_secs = props.duration().as_secs_f64();
    let sample_rate = props.sample_rate().unwrap_or(44100);
    let bit_depth = props.bit_depth().map(|b| b as u32);
    let channels = props.channels().unwrap_or(2) as u32;

    let format = Path::new(path)
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("unknown")
        .to_uppercase();

    let file_size_bytes = std::fs::metadata(path)?.len();

    // ReplayGain tags
    let replay_gain_track = tag
        .and_then(|t| t.get_string(ItemKey::ReplayGainTrackGain))
        .and_then(|v| parse_gain_db(v));

    let replay_gain_album = tag
        .and_then(|t| t.get_string(ItemKey::ReplayGainAlbumGain))
        .and_then(|v| parse_gain_db(v));

    Ok(TrackInfo {
        path: path.to_string(),
        title,
        artist,
        album,
        album_artist,
        track_number,
        duration_secs,
        sample_rate,
        bit_depth,
        channels,
        format,
        file_size_bytes,
        replay_gain_track,
        replay_gain_album,
    })
}

fn parse_gain_db(s: &str) -> Option<f64> {
    let trimmed = s
        .trim()
        .trim_end_matches(|c: char| c.is_alphabetic() || c == ' ')
        .trim();
    trimmed.parse::<f64>().ok()
}

pub fn read_album_art(path: &str) -> Result<Option<Vec<u8>>> {
    let tagged = lofty::read_from_path(path)?;
    if let Some(tag) = tagged.primary_tag() {
        if let Some(pic) = tag.pictures().first() {
            return Ok(Some(pic.data().to_vec()));
        }
    }
    Ok(None)
}

pub fn read_embedded_lyrics(path: &str) -> Result<Option<String>> {
    let tagged = lofty::read_from_path(path)?;
    if let Some(tag) = tagged.primary_tag() {
        if let Some(lyrics) = tag.get_string(ItemKey::Lyrics) {
            let s = lyrics.trim().to_string();
            if !s.is_empty() {
                return Ok(Some(s));
            }
        }
    }
    Ok(None)
}

pub fn scan_directory(dir: &str) -> Result<Vec<String>> {
    const SUPPORTED: &[&str] = &[
        "flac", "wav", "aiff", "aif", "alac", "m4a", "dsf", "dff", "mp3", "ogg", "opus", "aac",
        "wv",
    ];

    let mut paths = Vec::new();
    for entry in walkdir::WalkDir::new(dir)
        .follow_links(true)
        .into_iter()
        .filter_map(|e| e.ok())
    {
        let path = entry.path();
        if !path.is_file() {
            continue;
        }
        if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
            if SUPPORTED.contains(&ext.to_lowercase().as_str()) {
                if let Some(s) = path.to_str() {
                    paths.push(s.to_string());
                }
            }
        }
    }
    paths.sort();
    Ok(paths)
}
