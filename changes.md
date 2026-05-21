# Changelog

All notable changes to Aqloss are documented here.

This project loosely follows Keep a Changelog and uses Semantic Versioning.

---

## [Unreleased]

### Added

- [Frontend-UserInterface] Press scale animation to play button
- [Frontend-Lyrics] Lrclib search & get API fallback

### Changes

- [Frontend-Theme] Adjust dark theme more darker dan cleaner
- [Frontend-HomeScreen] Improve sidebar collaps animation
- [Frontend-PlayerScreen] Player Screen now has slide in animation on change track
- [Frontend-MiniPlayer] Adjust mini player bar UI

---

## [0.2.2] - 2026-05-19

### Added

- [Backend-DiscordRPC] Find button discord RPC now links to YouTube Music search
- [Frontend-Lyrics] Irclib fallback for lyrics
- [Frontend-Albums] Albums screen
- [Android] Storage permissions handler
- [Android] URI path resolution
- [Android] Folder manager access on mobile

### Fixed

- [Frontend] Call backend only on drag end to prevent seek throttle
- [Frontend] All button now should has pointer now
- [Backend-DiscordRPC] Discord button label overflow
- [Backend-Audio] Added helpers to prevent backend crash
- [Frontend-DiscordRPC] Validate activity fields and reconnect after error
- [Frontend-DiscordRPC] Sanitize album field sent as large_text
- [Android] Library scan empty
- [Android] Status bar overlap
- [Android] window_manager crash on Android
- [Android] Spectrum negative padding
- [Android] Using ndk context to open audio output for cpal
- [Android] Overflow on grid item

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
- Window not rounded on linux
- Search doesn't work on library

### Changed

- Library and playlist now displaying cover art
- Images are resized to a maximum of 300×300 and recompressed to JPEG to reduce ram usage
- remove material widgets from library and settings screen

## [0.2.0] - 2026-05-14

### Fixed

- AOT library not found when app starts

## [0.1.1] - 2026-05-13

### Fixed

- Audio output device selection not respected
- Playlist reorder moves item one position too far when dragging down
- Dragging a track from the library to a playlist sidebar item did nothing
- Lyrics text stays white in light mode

### Added

- Desktop mini player bar
- Right-click context menu in Library (desktop)
- File info dialog

### Changed

- `MiniPlayerBar` now detects the platform and renders a full desktop bar (`_DesktopBar`) or the existing compact bar (`_MobileBar`) accordingly.
- Desktop mini player is now shown on all non-player screens instead of only on mobile.

## [0.1.0] - 2026-05-07

### Initial release v0.1.0

---

[Unreleased]: https://github.com/nokarin-dev/frameextractor/compare/v0.2.2...HEAD
[0.2.2]: https://github.com/nokarin-dev/frameextractor/releases/tag/v0.2.2
[0.2.1]: https://github.com/nokarin-dev/frameextractor/releases/tag/v0.2.1
[0.2.0]: https://github.com/nokarin-dev/frameextractor/releases/tag/v0.2.0
[0.1.1]: https://github.com/nokarin-dev/frameextractor/releases/tag/v0.1.1
[0.1.0]: https://github.com/nokarin-dev/frameextractor/releases/tag/v0.1.0
