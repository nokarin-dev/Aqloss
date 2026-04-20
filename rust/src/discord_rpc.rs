use anyhow::Result;
use discord_presence::Event;
use discord_presence::models::ActivityType;
use discord_presence::{models::Activity, Client};
use std::sync::{Mutex, OnceLock};
use std::time::{SystemTime, UNIX_EPOCH};

const CLIENT_ID: u64 = 1495825548109414564;

static RPC: OnceLock<Mutex<Option<Client>>> = OnceLock::new();

fn rpc() -> &'static Mutex<Option<Client>> {
    RPC.get_or_init(|| Mutex::new(None))
}

fn ensure_connected(lock: &mut Option<Client>) {
    if lock.is_none() {
        let mut client = Client::new(CLIENT_ID);

        let _ = client.on_event(Event::Ready, |_| {
            println!("READY!");
        });

        let _ = client.start();
        *lock = Some(client);
    }
}

// Playing.
pub fn update_playing(
    title: &str,
    artist: &str,
    album: &str,
    position_secs: f64,
    duration_secs: f64,
) -> Result<()> {
    let mut guard = rpc().lock().unwrap();
    ensure_connected(&mut guard);
    let Some(ref mut client) = *guard else {
        return Ok(());
    };

    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();

    let elapsed = position_secs as u64;
    let end_ts = now
        .saturating_sub(elapsed)
        .saturating_add(duration_secs as u64);

    let state_str = if album.is_empty() {
        artist.to_string()
    } else {
        format!("{artist} — {album}")
    };

    client.set_activity(|_| {
        Activity::new()
            .activity_type(ActivityType::Listening)
            .state(&state_str)
            .details(title)
            .timestamps(|t| t.end(end_ts))
            .assets(|a| a.large_image("aqloss").large_text("Aqloss"))
    })?;

    Ok(())
}

// Paused.
pub fn update_paused(title: &str, artist: &str) -> Result<()> {
    let mut guard = rpc().lock().unwrap();
    ensure_connected(&mut guard);
    let Some(ref mut client) = *guard else {
        return Ok(());
    };

    let state_str = format!("⏸ {artist}");
    client.set_activity(|_| {
        Activity::new()
            .activity_type(ActivityType::Listening)
            .state(&state_str)
            .details(title)
            .assets(|a| a.large_image("aqloss").large_text("Aqloss — Paused"))
    })?;

    Ok(())
}

// Clear presence
pub fn clear() -> Result<()> {
    let mut guard = rpc().lock().unwrap();
    let Some(ref mut client) = *guard else {
        return Ok(());
    };
    client.clear_activity()?;
    Ok(())
}
