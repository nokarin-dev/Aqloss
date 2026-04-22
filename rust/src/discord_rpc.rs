use anyhow::Result;
use discord_presence::{models::Activity, models::ActivityType, Client};
use std::sync::{Mutex, OnceLock};
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

const CLIENT_ID: u64 = 1495825548109414564;

// Discord state field max is 128 chars
fn truncate(s: &str, max: usize) -> String {
    if s.chars().count() <= max {
        return s.to_string();
    }
    let mut t: String = s.chars().take(max - 1).collect();
    t.push('…');
    t
}

struct RpcState {
    client: Client,
    ready: bool,
}

static RPC: OnceLock<Mutex<Option<RpcState>>> = OnceLock::new();

fn rpc() -> &'static Mutex<Option<RpcState>> {
    RPC.get_or_init(|| Mutex::new(None))
}

fn ensure_ready(guard: &mut Option<RpcState>) {
    if guard.as_ref().map(|s| s.ready).unwrap_or(false) {
        return;
    }
    if guard.is_some() {
        thread::sleep(Duration::from_millis(50));
        let ready = Client::is_ready();
        if let Some(ref mut s) = *guard {
            s.ready = ready;
        }
        return;
    }

    let mut client = Client::new(CLIENT_ID);
    client
        .on_ready(|_| eprintln!("[discord-rpc] Ready!"))
        .persist();
    client
        .on_error(|ctx| eprintln!("[discord-rpc] Error: {:?}", ctx.event))
        .persist();
    client.start();

    let deadline = Duration::from_secs(3);
    let poll = Duration::from_millis(50);
    let started = std::time::Instant::now();
    while !Client::is_ready() {
        if started.elapsed() >= deadline {
            eprintln!("[discord-rpc] Timed out waiting for Discord handshake");
            *guard = Some(RpcState {
                client,
                ready: false,
            });
            return;
        }
        thread::sleep(poll);
    }
    eprintln!("[discord-rpc] Connected to Discord");
    *guard = Some(RpcState {
        client,
        ready: true,
    });
}

pub fn update_playing(
    title: &str,
    artist: &str,
    album: &str,
    album_art_url: Option<&str>,
    position_secs: f64,
    duration_secs: f64,
) -> Result<()> {
    let mut guard = rpc().lock().unwrap();
    ensure_ready(&mut guard);
    let Some(ref mut state) = *guard else {
        return Ok(());
    };
    if !state.ready {
        return Ok(());
    }

    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    let elapsed = position_secs as u64;
    let end_ts = now
        .saturating_sub(elapsed)
        .saturating_add(duration_secs as u64);

    // Truncate state to max 128 chars
    let state_str = if album.is_empty() {
        truncate(artist, 128)
    } else {
        truncate(&format!("{artist} — {album}"), 128)
    };

    let large_img = match album_art_url {
        Some(url) if !url.is_empty() && is_direct_image_url(url) => url,
        _ => "aqloss",
    };

    let large_text = if album.is_empty() {
        truncate(artist, 128)
    } else {
        truncate(album, 128)
    };

    let title_truncated = truncate(title, 128);

    if let Err(e) = state.client.set_activity(|_| {
        Activity::new()
            .activity_type(ActivityType::Listening)
            .state(&state_str)
            .details(&title_truncated)
            .timestamps(|t| t.start(now).end(end_ts))
            .assets(|a| {
                a.large_image(large_img)
                    .large_text(&large_text)
                    .small_image("aqloss")
                    .small_text("Aqloss")
            })
    }) {
        eprintln!("[discord-rpc] set_activity failed: {e}");
        state.ready = Client::is_ready();
    }
    Ok(())
}

pub fn update_paused(
    title: &str,
    artist: &str,
    album: &str,
    album_art_url: Option<&str>,
) -> Result<()> {
    let mut guard = rpc().lock().unwrap();
    ensure_ready(&mut guard);
    let Some(ref mut state) = *guard else {
        return Ok(());
    };
    if !state.ready {
        return Ok(());
    }

    let large_img = match album_art_url {
        Some(url) if !url.is_empty() && is_direct_image_url(url) => url,
        _ => "aqloss",
    };

    // Truncate all fields
    let state_str = truncate(&format!("⏸ {artist}"), 128);
    let title_truncated = truncate(title, 128);
    let large_text = if album.is_empty() {
        truncate(artist, 128)
    } else {
        truncate(album, 128)
    };

    if let Err(e) = state.client.set_activity(|_| {
        Activity::new()
            .activity_type(ActivityType::Listening)
            .state(&state_str)
            .details(&title_truncated)
            .assets(|a| {
                a.large_image(large_img)
                    .large_text(&large_text)
                    .small_image("aqloss")
                    .small_text("Aqloss - Paused")
            })
    }) {
        eprintln!("[discord-rpc] set_activity (paused) failed: {e}");
        state.ready = Client::is_ready();
    }
    Ok(())
}

pub fn clear() -> Result<()> {
    let mut guard = rpc().lock().unwrap();
    let Some(ref mut state) = *guard else {
        return Ok(());
    };
    if !state.ready {
        return Ok(());
    }
    if let Err(e) = state.client.clear_activity() {
        eprintln!("[discord-rpc] clear_activity failed: {e}");
        state.ready = Client::is_ready();
    }
    Ok(())
}

fn is_direct_image_url(url: &str) -> bool {
    let lower = url.to_lowercase();
    // Must start with https
    if !lower.starts_with("https://") {
        return false;
    }

    // Reject obvious API/search URLs
    if lower.contains("/search?")
        || lower.contains("?term=")
        || lower.contains("?q=")
        || lower.contains("/api/")
    {
        return false;
    }

    // Prefer known image extensions or known CDN domains
    lower.ends_with(".jpg")
        || lower.ends_with(".jpeg")
        || lower.ends_with(".png")
        || lower.ends_with(".webp")
        || lower.contains("is1-ssl.mzstatic.com")
        || lower.contains("i.scdn.co")
        || lower.contains("coverartarchive.org")
        || lower.contains("lastfm.freetls.fastly.net")
        || lower.contains("i1.sndcdn.com")
}
