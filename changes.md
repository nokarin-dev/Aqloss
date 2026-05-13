# Changelog

All notable changes to Aqloss are documented here.

This project loosely follows Keep a Changelog and uses Semantic Versioning.

---

No Changes Yet.

---

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

[Unreleased]: https://github.com/nokarin-dev/frameextractor/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/nokarin-dev/frameextractor/releases/tag/v0.1.0
