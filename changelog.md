# Changelog

All notable changes to Aqloss are documented here.

This project loosely follows Keep a Changelog and uses Semantic Versioning.

---

## [Unreleased]

No Changes Yet.

---

## [0.3.1] - 2026-06-11

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

### Added

- Aqloss logging
- 128-entry LRU cache for album art thumbnails
- Islands theme
- Grid / Detail view toggle in library
- Now playing header on library and playlist
- Mini player

### Fixed

- Buffer underrun warning spam
- Window not rounded on Linux
- Search doesn't work on library

### Changed

- Library and playlist now display cover art
- Images are resized to a maximum of 300×300 and recompressed to JPEG to reduce RAM usage
- Removed Material widgets from library and settings screen

---

## [0.2.0] - 2026-05-14

### Fixed

- AOT library not found when app starts

---

## [0.1.1] - 2026-05-13

### Added

- Desktop mini player bar
- Right-click context menu in Library (desktop)
- File info dialog

### Fixed

- Audio output device selection not respected
- Playlist reorder moves item one position too far when dragging down
- Dragging a track from the library to a playlist sidebar item did nothing
- Lyrics text stays white in light mode

### Changed

- `MiniPlayerBar` now detects the platform and renders a full desktop bar (`_DesktopBar`) or the existing compact bar (`_MobileBar`) accordingly
- Desktop mini player is now shown on all non-player screens instead of only on mobile

---

## [0.1.0] - 2026-05-07

### Initial release

---

[Unreleased]: https://github.com/nokarin-dev/Aqloss/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/nokarin-dev/Aqloss/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/nokarin-dev/Aqloss/compare/v0.2.3...v0.3.0
[0.2.3]: https://github.com/nokarin-dev/Aqloss/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/nokarin-dev/Aqloss/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/nokarin-dev/Aqloss/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/nokarin-dev/Aqloss/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/nokarin-dev/Aqloss/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/nokarin-dev/Aqloss/releases/tag/v0.1.0
