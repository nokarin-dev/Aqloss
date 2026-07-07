# Aqloss Plugin System (EXPERIMENTAL)

The Aqloss plugin system runs Lua scripts inside an `mlua` sandbox embedded directly in the Rust process. Plugins receive real-time playback/library events and can call a limited set of functions injected through the global `aqloss` table.

This document reflects the exact implementation in `rust/src/plugin_engine.rs`, `rust/src/api.rs`, and `rust/src/logger.rs` as of the latest commit. If the code changes, update this document to match - don't let it drift.

---

## 1. Structure & Manifest

### Folder structure

Each plugin is a single folder inside the Aqloss plugins directory, containing at minimum `plugin.json` and one Lua entry file:

```
<plugins_root>/
└── xyz.nokarin.helloworld/
    ├── plugin.json
    └── main.lua
```

**Location of `<plugins_root>`:**

| Platform                 | Path                                                     |
| ------------------------ | -------------------------------------------------------- |
| Linux / macOS / Windows  | `$HOME/.aqloss/plugins/` (or `%USERPROFILE%` on Windows) |
| Other platforms (mobile) | `<application support directory>/plugins/`               |

The folder name doesn't technically have to match the manifest `id` (the registry reads `id` from the contents of `plugin.json`, not from the folder name), but Aqloss's built-in installer (`.aqx` import) always names the folder after `id`, sanitized with the regex `[^a-zA-Z0-9._-]` → `_`. Keep the folder name matching `id` for consistency.

### Manifest fields (`plugin.json`)

| Field                | Type                | Required? | Default      | Notes                                                                     |
| -------------------- | ------------------- | --------- | ------------ | ------------------------------------------------------------------------- |
| `id`                 | string              | **Yes**   | -            | Unique identifier, reverse-domain format recommended (`xyz.author.name`)  |
| `name`               | string              | **Yes**   | -            | Display name shown in the UI                                              |
| `version`            | string              | **Yes**   | -            | Plugin version (semver recommended, not validated)                        |
| `author`             | string              | **Yes**   | -            | Author name                                                               |
| `description`        | string              | No        | `null`       | Short description, shown in the UI                                        |
| `min_aqloss_version` | string              | No        | `"0.4.0"`    | **Informational only** - see note below                                   |
| `entry`              | string              | No        | `"main.lua"` | Lua file name loaded as the entry point                                   |
| `type`               | string              | No        | `"lua"`      | `"lua"` \| `"webhook"` \| `"builtin"` - this document only covers `"lua"` |
| `permissions`        | array&lt;string&gt; | No        | `[]`         | Combination of `"network"`, `"filesystem"`, `"library_write"`             |

> **Note on `min_aqloss_version`:** this field is parsed and stored, but **there is no version-gate check anywhere in the current code** - a plugin will still load regardless of whether its declared version matches the running Aqloss version. This field is purely metadata for now; don't rely on it to prevent old plugins from running on newer versions or vice versa.

> **Note on `library_write`:** this permission is a registered enum option, but **no function in the Lua API currently checks it**. Declaring `library_write` in the manifest does not unlock any capability today - this is an unimplemented gap, not an active permission gate.

### Minimal manifest example

```json
{
  "id": "xyz.nokarin.helloworld",
  "name": "Hello World Logger",
  "version": "1.0.0",
  "author": "nokarin"
}
```

All optional fields fall back to their defaults (`entry: "main.lua"`, `type: "lua"`, `permissions: []`).

### Manifest example with permissions

```json
{
  "id": "xyz.nokarin.helloworld",
  "name": "Hello World Logger",
  "version": "1.0.0",
  "author": "nokarin",
  "description": "Basic example plugin: logs every playback event to the Aqloss backend log.",
  "min_aqloss_version": "0.4.0",
  "entry": "main.lua",
  "type": "lua",
  "permissions": ["network"]
}
```

---

## 2. Lua API Reference

Each plugin gets its own **separate** Lua VM (no shared state between plugins). Before the entry file is executed, Rust injects a single global table named `aqloss` containing the functions below.

### Functions available via `aqloss.*`

| Function                               | Signature                                         | Permission required | Notes                                                                                                                                                                                                                                  |
| -------------------------------------- | ------------------------------------------------- | ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `aqloss.log(msg)`                      | `(string) -> ()`                                  | -                   | Writes to the `plugin` log target at `info` level, prefixed `[plugin]`                                                                                                                                                                 |
| `aqloss.log_warn(msg)`                 | `(string) -> ()`                                  | -                   | Writes to the `plugin` log target at `warn` level, prefixed `[plugin]`                                                                                                                                                                 |
| `aqloss.json_encode(value)`            | `(table\|string\|number\|boolean\|nil) -> string` | -                   | Serializes a Lua value to a JSON string                                                                                                                                                                                                |
| `aqloss.json_decode(str)`              | `(string) -> table\|...`                          | -                   | Parses a JSON string into a Lua value                                                                                                                                                                                                  |
| `aqloss.http_post(url, headers, body)` | `(string, table, string) -> boolean`              | `network`           | POST request. `headers` is a `{[string]=string}` table. Returns `true` if status &lt; 400, `false` on failure/error status. **Without the `network` permission, calling this raises a Lua error**, it does not silently return `false` |
| `aqloss.http_get(url)`                 | `(string) -> string\|nil`                         | `network`           | GET request. Returns the body as a string, or `nil` on failure. Without `network`, raises a Lua error                                                                                                                                  |
| `aqloss.read_file(rel_path)`           | `(string) -> string`                              | `filesystem`        | Reads a file **relative to the plugin's own folder**. Paths that try to escape the plugin folder (`../../../etc/passwd`, symlink escape, etc.) are rejected with an error. Without `filesystem`, raises a Lua error                    |
| `aqloss.version`                       | `string` (not a function)                         | -                   | The Aqloss engine version (`CARGO_PKG_VERSION`), useful for logging/debugging                                                                                                                                                          |

### Handling missing permissions

Every function that requires a permission (`http_post`, `http_get`, `read_file`) raises a **Lua runtime error** when the relevant permission isn't declared in `plugin.json` - it does not silently return an empty value. If a plugin wants to keep running even without the permission (graceful degradation), wrap the call in `pcall`:

```lua
local ok, result = pcall(aqloss.http_get, "https://api.example.com/data")
if ok then
  aqloss.log("Data: " .. tostring(result))
else
  aqloss.log_warn("http_get failed (missing permission?): " .. tostring(result))
end
```

### Built-in Lua language functions available

The plugin Lua VM is loaded with the `table`, `string`, and `math` libraries (via `LuaStdLib::TABLE | STRING | MATH`), **plus** the core Lua base functions that are always present regardless of which library flags are set:

- `pairs`, `ipairs`, `next`
- `type`, `tostring`, `tonumber`
- `pcall`, `xpcall`, `error`, `assert`
- `setmetatable`, `getmetatable`, `rawget`, `rawset`, `rawequal`
- `select`, `unpack` / `table.unpack`
- All of `table.*` (`table.insert`, `table.concat`, `table.sort`, etc.)
- All of `string.*` (`string.format`, `string.sub`, `string.find`, etc.)
- All of `math.*` (`math.floor`, `math.random`, `math.huge`, etc.)

### What is **not** available

- `os.*` - **not available** (`os.time()`, `os.date()`, `os.exit()`, etc. will error with "attempt to index a nil value")
- `io.*` - **not available**; no native way to read/write files except through `aqloss.read_file`
- `coroutine.*` - **not available**
- `require` / `package.*` - **not available**, a plugin cannot `require` another Lua file or load an external module
- `debug.*` - **not available**
- Filesystem access beyond `aqloss.read_file` - **there is no native way to write a file from Lua at all** (no `write_file` in the current API)

If you need a timestamp, don't reach for `os.time()` - use timestamp data that comes from the event payload (if present), or request it as a future Rust-side parameter.

---

## 3. Event Lifecycle

### How hooks work

Every event from Rust is mapped to a global function name in Lua. The plugin runtime looks up a global function with that name; if it exists, it is called with **one argument**, a table produced by deserializing the event's JSON payload. If the hook function isn't defined in the script, the event is silently skipped for that plugin - this is not an error.

```lua
function on_track_start(event)
end
```

### The two plugin lifecycle hooks

| Hook          | When called                                                                   | Argument   |
| ------------- | ----------------------------------------------------------------------------- | ---------- |
| `on_load()`   | Once, when the plugin is successfully loaded (`plugin_load` called from Dart) | None (nil) |
| `on_unload()` | Once, when the plugin is unloaded (uninstall or app shutdown)                 | None (nil) |

### Playback & library events

| Hook                              | Fields on `event`                                                  | When dispatched                                                                                          |
| --------------------------------- | ------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------- |
| `on_track_start(event)`           | `title`, `artist`, `album` (can be `nil`), `duration_secs`, `path` | A track starts playing                                                                                   |
| `on_track_stop(event)`            | `title` (can be `nil`), `artist` (can be `nil`)                    | Playback is manually stopped                                                                             |
| `on_play_pause(event)`            | `is_playing` (boolean), `position_secs`                            | Play/pause toggled                                                                                       |
| `on_position_update(event)`       | `position_secs`, `duration_secs`, `progress` (0.0–1.0)             | Fired repeatedly during playback (high frequency - avoid heavy work here)                                |
| `on_track_complete(event)`        | `title`, `artist`, `duration_secs`, `path`                         | A track finishes playing naturally (not manually skipped)                                                |
| `on_library_scan_start()`         | - (no fields)                                                      | Library scan starts                                                                                      |
| `on_library_scan_complete(event)` | `total` (integer)                                                  | Library scan finishes, `total` = number of tracks found                                                  |
| `on_track_loved(event)`           | `title`, `artist`, `loved` (boolean)                               | A track is marked/unmarked as loved                                                                      |
| `on_app_foreground()`             | - (no fields)                                                      | The app returns to the foreground (resume from background on mobile, or window regains focus on desktop) |

### Important note on `on_position_update`

This event fires **repeatedly** during playback (on every player position tick, not once per track). If a plugin does expensive work in this hook (a network call, file I/O, heavy string processing), it directly impacts playback performance, since dispatch runs on the same thread as the audio engine. Keep this hook to lightweight work only (e.g. updating an in-memory counter), or throttle it yourself in Lua if you need periodic logging:

```lua
local last_logged = 0
function on_position_update(event)
  if event.position_secs - last_logged >= 30 then
    aqloss.log(string.format("Position: %.0fs", event.position_secs))
    last_logged = event.position_secs
  end
end
```

### Fields that can be `nil`

Some event payload fields can arrive as `nil` in Lua (equivalent to `null` in JSON / `None` in Rust). Fields that need guarding:

- `on_track_start`: `event.album` can be `nil` (a track with no album metadata)
- `on_track_stop`: `event.title` and `event.artist` can **both** be `nil` at once (e.g. stop called with no active track)

Always use the `event.field or fallback` pattern for fields that could be `nil`:

```lua
local artist = event.artist or "Unknown Artist"
```

---

## 4. Install / Load Process

### Discovery at startup

When the app starts, `PluginRegistry.init()` (Dart) calls `_discoverInstalled()`, which scans **every direct subfolder** of `<plugins_root>`. For each subfolder:

1. Check for `plugin.json` at the root of that subfolder. If it's missing, the folder is skipped entirely (not treated as a plugin).
2. Parse `plugin.json`. If parsing fails (invalid JSON, missing required field), that plugin is skipped and the error is logged - this does **not** stop discovery of other plugins.
3. Check `type`:
   - `"lua"` → calls `plugin_load(dirPath)` on the Rust side via the FRB bridge (`package:aqloss/src/rust/api.dart`), which re-reads `plugin.json` on the Rust side, creates a new Lua VM, injects the `aqloss` table, loads the `entry` file, and calls `on_load()`.
   - `"webhook"` → loaded directly as a webhook dispatcher, never touches Rust/Lua at all.
   - `"builtin"` → **cannot** be loaded from disk; this type is exclusively for plugins registered via `PluginRegistry.registerBuiltin()` from Dart code before `init()` is called (used for Aqloss's own built-in features like Discord RPC, not for third-party plugins).

### Hot-loading after runtime install

If a plugin is installed while the app is already running (e.g. via `.aqx` import from the UI), `PluginRegistry.loadFromDir(dir)` is called directly without an app restart - the parsing and load steps are identical to the above, just triggered manually instead of at startup.

### Enable/disable & uninstall

- **Enable/disable**: state is persisted in Dart local storage, then synced to Rust via `plugin_set_enabled(id, enabled)`. A disabled plugin stays loaded in memory (its Lua VM still exists) but **receives no event dispatch at all** - toggling enable/disable does not re-call `on_load`/`on_unload`; only the `enabled` flag on the Rust side changes.
- **Uninstall**: calls `plugin_unload(id)` (which triggers `on_unload()`, then drops the Lua VM), then permanently deletes the plugin's folder from disk.

### Manual steps for testing (without the UI installer)

1. Copy the plugin folder (`plugin.json` + `main.lua`) into `<plugins_root>` (see the path table in Section 1).
2. Restart Aqloss, or use the refresh/rescan button in the plugin manager UI if available, without needing a full restart.
3. Check the app log for a `[plugins] lua loaded: <id>` line as confirmation of a successful load. On failure, the log will show `[plugins] lua load error <id>: <message>` instead.

---

## 5. Troubleshooting: "My plugin loaded but nothing happens"

If the app log shows `[plugins] lua loaded: <id>` but you see no output from your plugin's `aqloss.log()` calls, the load itself succeeded - the problem is elsewhere. Work through these in order:

### Check `plugin.log`, not just the frontend log

The Dart-side `[FRONTEND] [DEBUG] [plugins] lua loaded: ...` line only confirms that `plugin_load()` returned successfully - it does **not** confirm that `on_load()` ran without error, or that later hooks like `on_track_start` are firing. The Rust plugin engine writes its own independent log to:

```
<app data dir>/logs/backend/plugin.log
```

This is also mirrored to stderr with the `[BACKEND]` tag, so it should appear in your terminal alongside the audio engine's own logs. Every `aqloss.log()` / `aqloss.log_warn()` call from any loaded plugin, plus internal engine messages (`loaded: <id>`, hook errors, permission errors), goes here. If you see nothing in `plugin.log` either, the issue is upstream of your script - check the next section.

### Confirm the hook name matches exactly

Hook function names are case-sensitive and must match exactly: `on_track_start`, not `onTrackStart` or `OnTrackStart` or `on_trackstart`. A typo in the function name means the hook is silently skipped - no error, no log, nothing. Compare your function names against the table in Section 3.

### Check for a silent Lua error inside the hook

If your hook function raises an error partway through (a typo calling a function that doesn't exist, indexing a `nil` value, etc.), the error is caught and logged to `plugin.log` as `[plugins/<id>] <hook>: <error message>` - but only for the specific call that failed. If the error happens inside `on_load()` itself, look for a line like:

```
[plugins/xyz.nokarin.helloworld] on_load: <error>
```

If your very first `aqloss.log()` call inside `on_load()` never printed and there's no error line either, double check that `on_load` is defined as a **global** function (`function on_load()`, not `local function on_load()`) - a `local` function is never visible to the hook dispatcher, since it looks up hooks by name in Lua's global table.

### Confirm the event is actually being triggered

For playback hooks like `on_track_start`, confirm the corresponding action actually happened on the Dart/Rust side (e.g. check for a `[BACKEND] [INFO] play()` line in the main app log). If the underlying playback action never fired, no plugin event will fire either - this isn't a plugin bug, it's upstream.

---

## 6. Complete Example

See the accompanying `xyz.nokarin.helloworld/` folder included with this document - it demonstrates every hook listed above (including `on_load`/`on_unload` for setup and cleanup, plus all 9 playback/library event hooks) and shows an optional, permission-gated use of `aqloss.http_post` (safe to load as-is with no network side effects, since `WEBHOOK_URL` defaults to `nil`).
