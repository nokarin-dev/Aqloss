# Changelog

All notable changes to Aqloss are documented here.

This project loosely follows Keep a Changelog and uses Semantic Versioning.

---

## [Unreleased]

Opus playback, macOS launch fix, Windows installer repair, rolling Apple Build channel, a quieter library header, queue context actions, a Linux half-screen layout pass, and queue search.

### Added

- [Frontend|Settings] Display toggle for the top now playing card; off by default (#16)
- [Frontend|Player] Search the current queue and jump to a match (#24)
- [Frontend|Library] Play all button when the library is filtered, to replace the queue with the visible results (#24)
- [Frontend|Player] Play next and Add to queue from track, album, and artist context menus (#18)
- [Frontend|UI] Show album and Show artist from the queue and other track menus (#18)
- [Backend|Audio] Opus playback (`.opus`) via libopus through the Symphonia adapter (#17)

### Fixed

- [Linux] Add Folder did nothing on Hyprland; pick with zenity/kdialog, or from a dialog in the app
- [Frontend] Add Folder crashed after the picker closed: Riverpod `ref` was used after the widget unmounted (#26)
- [Frontend|UI] Duplicate drag handle on the left of queue rows (#18)
- [Frontend|UI] Now Playing crushed when expanded nav and queue shared a half-screen: it now switches to a cover layout from the pane width, with lyrics behind a toggle on the art and controls sized under the cover
- [Frontend|UI] Playing indicator replaced cover art with a solid tile; the cover stays visible under a light scrim
- [Linux] Tiled/half-screen windows kept 14px CSD padding and rounded corners, so the app did not fill the tile
- [macOS] Crash on launch on Sequoia: `_luaopen_base` missing because vendored Lua was left out of the CocoaPods staticlib (#19)
- [Windows] SFX installer truncated to ~100 KB: `rcedit` rewrote the concatenated exe and dropped the 7z payload

### Changed

- [Tooling] Major dependency update
- [Frontend|UI] Mini player subtitle is `artist — album` so album is visible without the top card
- [Frontend|UI] Album artist name and artist-page album headings open the matching page
- [Frontend|UI] Queue panel narrows on windows narrower than 1100px
- [Frontend|UI] Maximized Now Playing keeps lyrics under the cover and splits the column so lyrics keep a real share of the height
- [Frontend|UI] Playlist rows show cover art instead of track numbers
- [Frontend|Player] Shuffle rearranges upcoming tracks instead of jumping to a random index, so Play Next stays next (#24)
- [Frontend|Library] Playing a library or global search result keeps the current queue; jump if the track is already queued

---

## [1.0.0] - 2026-08-01

Major release: plugin system, UI refresh, integrations, and an audio pipeline quality pass.

### Added

- [Frontend|FileSystem] `.aqx` plugin packages (`plugin.json` + Lua or webhook)
- [Frontend|UI] Plugin manager in Settings (install, enable, export, uninstall)
- [Backend|Architecture] Lua plugin sandbox with permission-gated `aqloss` API
- [Backend|Library] Album art fallback from folder images (`cover.jpg`, `folder.jpg`, etc.)
- [Backend|Integrations] ListenBrainz scrobbling (alongside Last.fm)
- [Frontend|UI] Responsive album page for narrow screens with grid/detail toggle
- [Frontend|UI] Dual UI framework: Default (custom Aqloss) or Material Design 3 (shared sidebar, M3 components, dynamic colour)
- [Frontend|UI] Material 3 desktop shell polish — expanded nav by default, page scaffold, richer queue drawer / mini player, track hover actions, Now Playing & Settings layout cleanup
- [Frontend|UI] Shared UI kit (`UiPage`, `UiListTile`, `UiSurface`, `UiDivider`, `showUiDialog`) for framework-aware screens
- [Tooling] Centralised app version in `version.yaml` (`dart run tool/sync_version.dart`)
- [Tooling] CI split into `ci.yml` and `release.yml`; release signing removed
- [Windows] Custom Flutter Windows installer

### Fixed

- [Frontend|Plugins] Uninstall now deletes the real install folder (by `plugin.json` id), so removed plugins no longer reappear after restart
- [Frontend|Plugins] Install flow reports errors (invalid `.aqx`, missing manifest, load failure) instead of failing silently; nested zip roots are flattened on extract
- [Frontend|UI] Minimum window size reduced to 800×600 for half-screen layouts
- [Backend|Audio] 32-bit FLAC playback
- [Backend|Audio] Playback position drift after Symphonia 0.6.0 upgrade
- [Backend|Audio] Seek only landed on whole seconds; now sample-accurate
- [Backend|Audio] Audible click on seek and on resume from pause (short gain ramp-in, shared mode only)
- [Frontend|Player] Loop-one stalled at end of track with the UI stuck on playing
- [Frontend|Android] Black screen on launch (`desktop_multi_window` guarded to desktop only)
- [Frontend|Android] Audio freeze when TWS/headset route changes mid-playback
- [Backend|Plugins] Library scan hooks now fire; Lua dispatch is awaited; position updates throttled

### Changed

- [Backend|Audio] Resampler upgraded from 64-tap linear sinc to 256-tap cubic (transparent, >140 dB stopband)
- [Backend|Audio] EQ biquads now run in f64 (DF2T); flat bands are bypassed entirely
- [Backend|Audio] Crossfade uses an equal-power curve instead of linear (no mid-fade level dip)
- [Frontend|Settings] Last.fm moved to Integrations
- [Backend|Audio] Symphonia 0.5.5 → 0.6.0 (with in-tree FLAC patch)
- [Docs] Plugin author guide rewritten (`docs/plugin.md`)

---

## [0.3.2] - 2026-06-22

Added stereo enhance module, Discord Rich Presence toggle, and various audio playback fixes.

### Added

- [Backend|Audio] Stereo enhance module, M/S width expansion, Haas micro-delay (0–25 ms), and high-shelf Side air boost for wider soundstage
- [Backend|Audio] `adapt_channels` now handles stereo→N-channel upmix (previously fell through to as-is, causing fast-forward on 8ch devices)
- [Frontend|Settings] Stereo Width and Haas Delay sliders in DSP pane with live apply
- [Frontend|Settings] Integrations page with Discord Rich Presence toggle
- [Frontend|Settings] Discord RPC enabled state now persisted across restarts

### Fixed

- [Backend|Audio] Fast-forward bug on devices with more than 2 output channels, `adapt_channels(2, N)` was returning raw stereo bytes consumed as N-ch, making tracks play N/2× too fast
- [Backend|Audio] `probe_exact_rate` on Windows was hardcoded to `false`, preventing output from reopening at the track's native sample rate; now probes via `IAudioClient::IsFormatSupported`
- [Frontend|Settings] Discord RPC setting is now applied at startup before first track plays, not only after visiting settings

### Changed

- [Backend|Audio] `adapt_channels` rewritten to cover all channel combinations: mono→N, stereo→N, surround→stereo, surround→surround
- [Frontend|Settings] DSP page subtitle updated to reflect new controls
- [Backend|Audio] Channel mismatch between decoder and output now logs a warning instead of silently producing wrong audio

## [0.3.1] - 2026-06-11

Customisable shortcuts, mini player mode, share now playing, and more UI improvements.

### Added

- [Frontend|Visualizer] Classic style for visualizer
- [Frontend|Integration] Share now playing
- [Frontend|UI] Mini player window
- [Frontend|UI] Customisable shortcuts
- [Frontend|UI] Accent color

### Fixed

- [Frontend|Search] Art stuck on previous track when global search changes
- [Frontend|Library] Cache library and automatic rescan on startup if something changed on disk
- [Backend|Visualizer] Sync visualizer to playback position

### Changes

- [Frontend|Visualizer] Rework wave & dots visualizer
- [Frontend|UI] Drag to queue improvement
- [Backend|Visualizer] Improve visualizer with realfft

## [0.3.0] - 2026-05-30

History, artists, loved tracks, and a big batch of audio backend fixes and improvements. Also playlist import/export and Last.fm sync.

### Added

- [Frontend] History screen
- [Frontend] Artists screen
- [Frontend] Artist detail
- [Frontend] Loved tracks
- [Frontend] Queue panel
- [Frontend] Global search overlay
- [Frontend] Play count badge on track tiles
- [Frontend] Play count on artist detail track rows
- [Frontend|Playlist] Export playlist to `.aqp` file
- [Frontend|Playlist] Import `.aqp` playlist
- [Frontend|LastFm] Sync loved tracks to Last.fm
- [Frontend|Settings] Mobile nav
- [Frontend|Audio] Device change watchdog

### Fixed

- [Frontend|History] Playing from history now uses history order as queue, not library order
- [Frontend|History] Duplicate tracks in history no longer require extra skips (explicit atIndex passed to loadWithQueue)
- [Frontend|Playlist] Rename dialog spacebar no longer triggers play/pause (FocusNode registered with SearchFocusTracker)
- [Frontend|Settings] Mobile settings screen was stuck on Music Folders with no way to navigate
- [Backend|Audio] `_engineReady = false` was set too eagerly on reinit, causing all backend calls (audio, Discord RPC, scrobble) to block or fail during normal playback
- [Backend|Audio] `play()` wait loop shortened from 15s to 5s - failures surface quickly instead of silently stalling
- [Backend|Audio] `play()` now only calls `reinitToDevice` when `backend.play()` actually throws, not as an upfront check

### Changed

- [Frontend|Playlist] `selectDevice` now goes through `AudioService.reinitToDevice` so `_engineReady` is managed in one place

---

## [0.2.3] - 2026-05-26

Update checker, media notifications, and a bunch of audio backend fixes. Also a big Flutter source restructure that was long overdue.

### Added

- [Frontend|UpdateChecker] Update checker in settings
- [Frontend|UI] Press scale animation to play button
- [Frontend|Lyrics] Lrclib search & get API fallback
- [Frontend|Notifier] Media player notifications
- [Audio|Backend] Reopen output stream at native sample rate on load to avoid unnecessary resampling
- [Audio|Backend] Added hardware capability check in probe_exact_rate before opening streams

### Fixed

- [Frontend|Shortcuts] Fixed Spacebar shortcut being swallowed when search field is focused (migrated to HardwareKeyboard)
- [Audio|Backend] Added debounce guard to prevent backend freezes from play/pause spam
- [Audio|Backend] Fixed missing stop_drain() call in the play() resume path

### Changed

- [Frontend|Settingss] Settings now uses a two-panel layout
- [Frontend|Theme] Adjust dark theme to be darker and cleaner
- [Frontend|HomeScreen] Improve sidebar collapse animation
- [Frontend|PlayerScreen] Player screen now has slide-in animation on track change
- [Frontend|MiniPlayer] Adjust mini player bar UI
- [Backend|Audio] Stream no longer blindly probes for the highest supported rate
- [Frontend] Music Folders moved into Settings
- [Codebase] Major restructure of Flutter source

---

## [0.2.2] - 2026-05-19

Albums screen lands, Discord RPC gets a YouTube Music deep-link, and Android gets proper storage handling. Lots of small fixes across the board.

### Added

- [Backend|DiscordRPC] Find button discord RPC now links to YouTube Music search
- [Frontend|Lyrics] Lrclib fallback for lyrics
- [Frontend|Albums] Albums screen
- [Android] Storage permissions handler
- [Android] URI path resolution
- [Android] Folder manager access on mobile

### Fixed

- [Backend|DiscordRPC] Discord button label overflow
- [Backend|Audio] Added helpers to prevent backend crash
- [Frontend|DiscordRPC] Validate activity fields and reconnect after error
- [Frontend|DiscordRPC] Sanitize album field sent as large_text
- [Frontend] Call backend only on drag end to prevent seek throttle
- [Frontend] All buttons now have pointer cursor
- [Android] Library scan empty
- [Android] Status bar overlap
- [Android] window_manager crash on Android
- [Android] Spectrum negative padding
- [Android] Using ndk context to open audio output for cpal
- [Android] Overflow on grid item

---

## [0.2.1] - 2026-05-17

Mini player, Islands theme, grid/detail toggle, LRU cache for album art. Library and playlist got a visual overhaul.

### Added

- [General] Aqloss logging
- [Frontend|Performance] 128-entry LRU cache for album art thumbnails
- [Frontend|Theme] Islands theme
- [Frontend|Library] Grid / Detail view toggle in library
- [Frontend|UI] Now playing header on library and playlist
- [Frontend|UI] Mini player

### Fixed

- [Backend|Audio] Buffer underrun warning spam
- [Frontend|Linux] Window not rounded on linux
- [Frontend|Library] Search doesn't work on library

### Changed

- [Frontend|Library] Library and playlist now displaying cover art
- [Frontend|UI] remove material widgets from library and settings screen
- [Backend|Performance] Images are resized to a maximum of 300×300 and recompressed to JPEG to reduce ram usage

---

## [0.2.0] - 2026-05-14

Hotfix: AOT library not found at startup.

### Fixed

- AOT library not found when app starts

---

## [0.1.1] - 2026-05-13

Desktop polish: mini player bar, right-click context menu, file info dialog. Plus a handful of playlist and drag-and-drop fixes.

### Added

- [Frontend|Desktop] Desktop mini player bar
- [Frontend|Desktop] Right-click context menu in Library (desktop)
- [Frontend|UI] File info dialog

### Fixed

- [Backend|Audio] Audio output device selection not respected
- [Frontend|Playlist] Playlist reorder moves item one position too far when dragging down
- [Frontend|Library] Dragging a track from the library to a playlist sidebar item did nothing
- [Frontend|Theme] Lyrics text stays white in light mode

### Changed

- [Frontend|Miniplayer] MiniPlayerBar now detects the platform and renders a full desktop bar (\_DesktopBar) or the existing compact bar (\_MobileBar) accordingly.
- [Frontend|Desktop] Desktop mini player is now shown on all non-player screens instead of only on mobile.

---

## [0.1.0] - 2026-05-07

Initial public

---

[Unreleased]: https://github.com/nokarin-dev/Aqloss/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/nokarin-dev/Aqloss/compare/v0.3.2...v1.0.0
[0.3.2]: https://github.com/nokarin-dev/Aqloss/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/nokarin-dev/Aqloss/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/nokarin-dev/Aqloss/compare/v0.2.3...v0.3.0
[0.2.3]: https://github.com/nokarin-dev/Aqloss/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/nokarin-dev/Aqloss/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/nokarin-dev/Aqloss/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/nokarin-dev/Aqloss/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/nokarin-dev/Aqloss/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/nokarin-dev/Aqloss/releases/tag/v0.1.0
