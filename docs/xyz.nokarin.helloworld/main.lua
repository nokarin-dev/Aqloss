local track_count = 0
local WEBHOOK_URL = nil

function on_load()
  aqloss.log("Hello World Logger active - engine version " .. aqloss.version)
end

function on_unload()
  aqloss.log("Hello World Logger shutting down. Total tracks played: " .. track_count)
end

function on_track_start(event)
  track_count = track_count + 1
  local artist = event.artist or "Unknown Artist"
  local album = event.album or "-"
  aqloss.log(string.format(
    "[%d] Now playing: %s - %s (%s)",
    track_count, artist, event.title or event.path, album
  ))

  if WEBHOOK_URL then
    local payload = aqloss.json_encode({
      title = event.title,
      artist = artist,
      duration_secs = event.duration_secs,
    })
    local ok = aqloss.http_post(WEBHOOK_URL, { ["Content-Type"] = "application/json" }, payload)
    if not ok then
      aqloss.log_warn("Failed to send webhook for: " .. (event.title or event.path))
    end
  end
end

function on_track_stop(event)
  if event.title then
    aqloss.log("Stopped: " .. event.title)
  else
    aqloss.log("Playback stopped.")
  end
end

function on_play_pause(event)
  if event.is_playing then
    aqloss.log(string.format("Resumed at %.1fs", event.position_secs))
  else
    aqloss.log(string.format("Paused at %.1fs", event.position_secs))
  end
end

function on_position_update(event)
end

function on_track_complete(event)
  aqloss.log(string.format("Completed: %s (%.1fs)", event.title, event.duration_secs))
end

function on_library_scan_start()
  aqloss.log("Library scan started...")
end

function on_library_scan_complete(event)
  aqloss.log(string.format("Library scan complete: %d tracks found.", event.total))
end

function on_track_loved(event)
  local state = event.loved and "loved" or "unloved"
  aqloss.log(string.format("%s marked as %s", event.title, state))
end

function on_app_foreground()
  aqloss.log("App returned to foreground.")
end
