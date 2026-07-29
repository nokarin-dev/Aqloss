use crate::TrackInfo;
use anyhow::Result;
use image::{ImageFormat, imageops::FilterType};
use lofty::prelude::{Accessor, AudioFile, ItemKey, TaggedFileExt};
use lru::LruCache;
use std::{
    ffi::OsStr,
    io::Cursor,
    num::NonZeroUsize,
    path::{Path, PathBuf},
    sync::Mutex,
};

// LRU cache
const CACHE_SIZE: usize = 128;
const THUMB_SIZE: u32 = 300;

const COVER_STEMS: &[&str] = &[
    "cover",
    "folder",
    "album",
    "albumart",
    "front",
    "albumartsmall",
];

const IMAGE_EXTS: &[&str] = &["jpg", "jpeg", "png", "webp", "bmp", "gif"];

static THUMB_CACHE: std::sync::OnceLock<Mutex<LruCache<String, Vec<u8>>>> =
    std::sync::OnceLock::new();

static FOLDER_COVER_CACHE: std::sync::OnceLock<Mutex<LruCache<String, Option<Vec<u8>>>>> =
    std::sync::OnceLock::new();

fn thumb_cache() -> &'static Mutex<LruCache<String, Vec<u8>>> {
    THUMB_CACHE.get_or_init(|| Mutex::new(LruCache::new(NonZeroUsize::new(CACHE_SIZE).unwrap())))
}

fn folder_cover_cache() -> &'static Mutex<LruCache<String, Option<Vec<u8>>>> {
    FOLDER_COVER_CACHE
        .get_or_init(|| Mutex::new(LruCache::new(NonZeroUsize::new(CACHE_SIZE).unwrap())))
}

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

// Returns embedded album art bytes, then a cover image from the track folder.
pub fn read_album_art(path: &str) -> Result<Option<Vec<u8>>> {
    if let Ok(tagged) = lofty::read_from_path(path) {
        if let Some(tag) = tagged.primary_tag() {
            if let Some(pic) = tag.pictures().first() {
                return Ok(Some(pic.data().to_vec()));
            }
        }
    }

    Ok(find_local_cover(Path::new(path)))
}

fn find_local_cover(audio_path: &Path) -> Option<Vec<u8>> {
    let dir = audio_path.parent()?;
    let dir_key = dir.to_string_lossy().into_owned();

    {
        let mut cache = folder_cover_cache().lock().unwrap();
        if let Some(cached) = cache.get(&dir_key) {
            return cached.clone();
        }
    }

    let cover = find_local_cover_uncached(dir);
    folder_cover_cache()
        .lock()
        .unwrap()
        .put(dir_key, cover.clone());
    cover
}

fn find_local_cover_uncached(dir: &Path) -> Option<Vec<u8>> {
    let entries: Vec<_> = std::fs::read_dir(dir)
        .ok()?
        .filter_map(|e| e.ok())
        .collect();

    for stem in COVER_STEMS {
        if let Some(path) = find_image_with_stem(&entries, stem) {
            return std::fs::read(path).ok();
        }
    }

    let mut images: Vec<PathBuf> = entries
        .iter()
        .filter_map(|entry| {
            let path = entry.path();
            if path.is_file() && is_image_file(path.as_path()) {
                Some(path)
            } else {
                None
            }
        })
        .collect();
    images.sort();

    images.first().and_then(|path| std::fs::read(path).ok())
}

fn find_image_with_stem(entries: &[std::fs::DirEntry], stem: &str) -> Option<PathBuf> {
    for entry in entries {
        let path = entry.path();
        if !path.is_file() || !is_image_file(path.as_path()) {
            continue;
        }
        let file_stem = path.file_stem()?.to_str()?;
        if file_stem.eq_ignore_ascii_case(stem) {
            return Some(path);
        }
    }
    None
}

fn is_image_file(path: &Path) -> bool {
    path.extension()
        .and_then(OsStr::to_str)
        .map(|ext| IMAGE_EXTS.contains(&ext.to_ascii_lowercase().as_str()))
        .unwrap_or(false)
}

// Returns a resized JPEG thumbnail
pub fn read_album_art_thumbnail(path: &str) -> Result<Option<Vec<u8>>> {
    {
        let mut cache = thumb_cache().lock().unwrap();
        if let Some(cached) = cache.get(path) {
            return Ok(Some(cached.clone()));
        }
    }

    let raw = match read_album_art(path)? {
        Some(b) => b,
        None => return Ok(None),
    };

    let thumb = make_thumbnail(&raw)?;

    {
        let mut cache = thumb_cache().lock().unwrap();
        cache.put(path.to_string(), thumb.clone());
    }

    Ok(Some(thumb))
}

// Evict a path from the thumbnail cache
pub fn evict_thumbnail_cache(path: &str) {
    thumb_cache().lock().unwrap().pop(path);
}

fn make_thumbnail(raw: &[u8]) -> Result<Vec<u8>> {
    let img = image::load_from_memory(raw)?;
    let (w, h) = (img.width(), img.height());
    let resized = if w > THUMB_SIZE || h > THUMB_SIZE {
        img.resize(THUMB_SIZE, THUMB_SIZE, FilterType::Triangle)
    } else {
        img
    };
    let mut out = Vec::with_capacity(16 * 1024);
    resized.write_to(&mut Cursor::new(&mut out), ImageFormat::Jpeg)?;
    Ok(out)
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::io::Write;

    fn write_file(path: &Path, bytes: &[u8]) {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        let mut file = fs::File::create(path).unwrap();
        file.write_all(bytes).unwrap();
    }

    #[test]
    fn finds_named_cover_case_insensitive() {
        let dir = std::env::temp_dir().join("aqloss_art_named");
        let _ = fs::remove_dir_all(&dir);
        write_file(&dir.join("Cover.JPG"), b"named-cover");
        write_file(&dir.join("track.mp3"), b"dummy");

        let art = find_local_cover_uncached(&dir);
        assert_eq!(art.as_deref(), Some(b"named-cover".as_slice()));
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn falls_back_to_first_image_in_folder() {
        let dir = std::env::temp_dir().join("aqloss_art_first");
        let _ = fs::remove_dir_all(&dir);
        write_file(&dir.join("zzz.png"), b"later");
        write_file(&dir.join("aaa.png"), b"first");

        let art = find_local_cover_uncached(&dir);
        assert_eq!(art.as_deref(), Some(b"first".as_slice()));
        let _ = fs::remove_dir_all(&dir);
    }
}
