![Aqloss Banner](https://github.com/nokarin-dev/Aqloss/blob/main/assets/banner/github_banner.png?raw=true)

<div align="center">

A music player built around a Rust audio engine, with optional WASAPI Exclusive mode on Windows for bit-perfect output to compatible hardware.

[![Release](https://img.shields.io/github/v/release/nokarin-dev/aqloss?style=for-the-badge&color=4F8EF7)](https://github.com/nokarin-dev/aqloss/releases/latest)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg?style=for-the-badge)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-02569B?style=for-the-badge)](#download)

[![Total Downloads](https://img.shields.io/github/downloads/nokarin-dev/aqloss/total?style=for-the-badge&logoColor=%3D&color=3471eb)](https://github.com/nokarin-dev/aqloss/releases)
[![Latest Downloads](https://img.shields.io/github/downloads/nokarin-dev/aqloss/latest/total?style=for-the-badge&color=3d47d4)](https://github.com/nokarin-dev/aqloss/releases/latest)
[![Test Status](https://img.shields.io/github/actions/workflow/status/nokarin-dev/aqloss/build-test.yml?style=for-the-badge&label=test%20build&color=22316e)](https://github.com/nokarin-dev/aqloss/actions/workflows/build-test.yml)

</div>

---

## About

Aqloss is an open-source music player with a Flutter UI and a Rust audio engine powered by [Symphonia](https://github.com/pdeljanov/Symphonia). It is currently in active development and targets 3 Platforms as its primary platforms.

**WASAPI Exclusive mode** (Windows only) allows the audio signal to bypass the Windows audio mixer and be sent directly to the output device without modification, provided the device and driver support it. When this mode is active, features like volume control, EQ, ReplayGain, and soft-clip are intentionally bypassed. On other platforms or when using shared mode, audio passes through the OS mixer and optional DSP processing.

Bit-perfect output depends on both the software path _and_ the hardware, a DAC, driver, and output chain that support it are required on the user's end.

---

## Current Status

| Area                         | Status                                        |
| ---------------------------- | --------------------------------------------- |
| Audio engine                 | Rust / Symphonia - stable                     |
| WASAPI Exclusive (Windows)   | Implemented                                   |
| Shared mode (Windows, Linux) | Via CPAL                                      |
| macOS / iOS                  | Compiles, not actively tested                 |
| EQ (10-band)                 | Implemented, applied in shared mode only      |
| ReplayGain                   | Tag reading & gain applied in shared mode     |
| Crossfade                    | Implemented                                   |
| Gapless playback             | Via Symphonia                                 |
| Scrobble (Last.fm)           | Implemented                                   |
| DSD (DSF/DFF)                | Not supported, Symphonia does not decode DSD  |

---

## Format Support

Formats decoded by Symphonia

| Format     | Extension      | Notes                            |
| ---------- | -------------- | -------------------------------- |
| FLAC       | `.flac`        | Lossless, up to 32-bit / 384 kHz |
| WAV / AIFF | `.wav` `.aiff` | PCM lossless                     |
| ALAC       | `.m4a`         | Lossless, up to 24-bit / 192 kHz |
| MP3        | `.mp3`         | Lossy                            |
| AAC        | `.aac` `.m4a`  | Lossy                            |
| OGG Vorbis | `.ogg`         | Lossy                            |
| Opus       | `.opus`        | Lossy                            |

> [!NOTE]
> DSD (DSF/DFF) is **not supported**. Symphonia does not have a DSD decoder. Native DSD playback would require a separate decode path which is not currently planned.

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.41
- [Rust toolchain](https://rustup.rs/) (stable)
- [flutter_rust_bridge CLI](https://cjycode.com/flutter_rust_bridge/integrate/quickstart.html)

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install flutter_rust_bridge codegen
cargo install flutter_rust_bridge_codegen

# Install Flutter dependencies
flutter pub get

# Generate Rust ↔ Dart bridge code
flutter_rust_bridge_codegen generate
```

### Platform setup

**Windows**

```bash
# Visual Studio Build Tools required.
flutter run -d windows
```

**Linux**

```bash
sudo apt install libasound2-dev pkg-config
flutter run -d linux
```

```bash
# Android SDK & Android Device required
flutter run -d android
```

**macOS / iOS**

These platforms compile but are not actively tested. Contributions and bug reports are welcome.

---

## Last.fm Scrobbling

Aqloss supports scrobbling via the Last.fm API. Because the source code is public, no API key is bundled with the repository.

you will need to register a free API key at [last.fm/api/account/create](https://www.last.fm/api/account/create) and enter it in Settings → Last.fm.

---

## Contributing

Contributions are welcome. Please open an issue first to discuss what you'd like to change.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes
4. Push and open a Pull Request

---

## License

```
Aqloss
Copyright © 2025-2026 nokarin-dev

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
```
