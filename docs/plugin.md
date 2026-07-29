# Aqloss plugins

Aqloss supports two plugin types:

- **Lua** (`type: "lua"`) - scripts run in a sandboxed Lua VM inside the Rust audio engine.
- **Webhook** (`type: "webhook"`) - playback events are POSTed as JSON to a URL you provide.

Packages use the `.aqx` format: a ZIP archive with `plugin.json` at the root.

## Install location

| Platform | Path |
| --- | --- |
| Linux / macOS / Windows | `~/.aqloss/plugins/` |
| Mobile | `<app support>/plugins/` |

Install from **Settings → Plugins → Install .aqx**, or drop a folder there manually and restart.

## `plugin.json`

| Field | Required | Default | Notes |
| --- | --- | --- | --- |
| `id` | yes | - | Unique ID (`author.name`) |
| `name` | yes | - | Shown in the UI |
| `version` | yes | - | Your plugin version |
| `author` | yes | - | |
| `description` | no | - | |
| `type` | no | `"lua"` | `"lua"` or `"webhook"` |
| `entry` | no | `"main.lua"` | Lua entry file |
| `min_aqloss_version` | no | `"1.0.0"` | Refused at load time if the running app is older |
| `permissions` | no | `[]` | `"network"`, `"filesystem"` (Lua only) |
| `webhook_url` | webhook | - | Destination URL |
| `webhook_headers` | no | - | Extra HTTP headers |
| `webhook_events` | no | all events | Subset of event names |

Example:

```json
{
  "id": "xyz.nokarin.helloworld",
  "name": "Hello World Logger",
  "version": "1.0.0",
  "author": "nokarin",
  "type": "lua",
  "permissions": []
}
```

## Lua API (`aqloss`)

Each Lua plugin gets its own VM with `table`, `string`, and `math` stdlibs plus:

| API | Permission | Notes |
| --- | --- | --- |
| `aqloss.log(msg)` | - | Info log |
| `aqloss.log_warn(msg)` | - | Warning log |
| `aqloss.json_encode(value)` | - | Value → JSON string |
| `aqloss.json_decode(str)` | - | JSON string → value |
| `aqloss.http_get(url)` | `network` | Returns body or `nil` |
| `aqloss.http_post(url, headers, body)` | `network` | Returns `true` if HTTP status &lt; 400 |
| `aqloss.read_file(rel_path)` | `filesystem` | Read-only, jailed to the plugin folder |
| `aqloss.version` | - | Running Aqloss version string |

Calls that need a permission raise a Lua error when the permission is missing. Use `pcall` if you want to handle that gracefully.

`os`, `io`, `require`, `coroutine`, and `debug` are **not** available.

## Event hooks

Define global functions (not `local function`). Missing hooks are skipped silently.

| Hook | Payload |
| --- | --- |
| `on_load()` | none |
| `on_unload()` | none |
| `on_track_start(event)` | `title`, `artist`, `album?`, `duration_secs`, `path` |
| `on_track_stop(event)` | `title?`, `artist?` |
| `on_play_pause(event)` | `is_playing`, `position_secs` |
| `on_position_update(event)` | `position_secs`, `duration_secs`, `progress` - throttled to ~1 Hz |
| `on_track_complete(event)` | `title`, `artist`, `duration_secs`, `path` |
| `on_library_scan_start()` | none |
| `on_library_scan_complete(event)` | `total` |
| `on_track_loved(event)` | `title`, `artist`, `loved` |
| `on_app_foreground()` | none |

Use `event.field or "fallback"` for optional fields.

## Webhook plugins

Set `"type": "webhook"` and `"webhook_url"`. Aqloss POSTs JSON like:

```json
{
  "event": "track_start",
  "title": "...",
  "artist": "..."
}
```

Filter events with `webhook_events` if you do not need all of them.

## Logs

Lua output goes to `<app data>/logs/backend/plugin.log` (also mirrored to stderr as `[BACKEND]`).

Load failures appear in the main app log as `[plugins] lua load error …`.

## Example

See [`docs/xyz.nokarin.helloworld/`](xyz.nokarin.helloworld/).
