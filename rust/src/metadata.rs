use crate::TrackInfo;
use anyhow::Result;
use lofty::{Accessor, AudioFile, ItemKey, TaggedFileExt};
use std::path::Path;

// Read full metadata + audio properties from a file.
pub fn read_track_info(path: &str) -> Result<TrackInfo> {
    let tagged = lofty::read_from_path(path)?;
    let props = tagged.properties();
    let tag = tagged.primary_tag();

    let title = tag.and_then(|t| t.title().map(|s| s.into_owned()));
    let artist = tag.and_then(|t| t.artist().map(|s| s.into_owned()));
    let album = tag.and_then(|t| t.album().map(|s| s.into_owned()));
    let album_artist = tag.and_then(|t| t.get_string(&ItemKey::AlbumArtist).map(|s| s.to_owned()));
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
    })
}

// Album art (cover image)
pub fn read_album_art(path: &str) -> Result<Option<Vec<u8>>> {
    let tagged = lofty::read_from_path(path)?;
    if let Some(tag) = tagged.primary_tag() {
        if let Some(pic) = tag.pictures().first() {
            return Ok(Some(pic.data().to_vec()));
        }
    }
    Ok(None)
}

// Embedded lyrics
pub fn read_embedded_lyrics(path: &str) -> Result<Option<String>> {
    let tagged = lofty::read_from_path(path)?;
    if let Some(tag) = tagged.primary_tag() {
        if let Some(lyrics) = tag.get_string(&ItemKey::Lyrics) {
            let s = lyrics.trim().to_string();
            if !s.is_empty() {
                return Ok(Some(s));
            }
        }
    }
    Ok(None)
}

// Scan a directory recursively for supported audio files,
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
        let p = entry.path();
        if !p.is_file() {
            continue;
        }
        if let Some(ext) = p.extension().and_then(|e| e.to_str()) {
            if SUPPORTED.contains(&ext.to_lowercase().as_str()) {
                paths.push(p.to_string_lossy().into_owned());
            }
        }
    }

    paths.sort();
    Ok(paths)
}
