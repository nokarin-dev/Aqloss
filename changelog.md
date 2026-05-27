# Changelog

All notable changes to Aqloss are documented here.

This project loosely follows Keep a Changelog and uses Semantic Versioning.

---

## [Unreleased]

### Added

- [Frontend] History Screen
- [Frontend|Lastfm] Sync loved local track with lastfm

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

[Unreleased]: https://github.com/nokarin-dev/Aqloss/compare/v0.2.3...HEAD
[0.2.3]: https://github.com/nokarin-dev/Aqloss/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/nokarin-dev/Aqloss/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/nokarin-dev/Aqloss/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/nokarin-dev/Aqloss/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/nokarin-dev/Aqloss/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/nokarin-dev/Aqloss/releases/tag/v0.1.0
