![Aqloss Banner](https://github.com/nokarin-dev/Aqloss/blob/main/assets/banner/github_banner.png?raw=true)

<div align="center">

[![Release](https://img.shields.io/github/v/release/nokarin-dev/aqloss?style=for-the-badge&color=4F8EF7)](https://github.com/nokarin-dev/aqloss/releases/latest)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg?style=for-the-badge)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20Android-02569B?style=for-the-badge)](#download)

[![Total Downloads](https://img.shields.io/github/downloads/nokarin-dev/aqloss/total?style=for-the-badge&logoColor=%3D&color=3471eb)](https://github.com/nokarin-dev/aqloss/releases)
[![Flathub Downloads](https://img.shields.io/flathub/downloads/xyz.nokarin.aqloss?style=for-the-badge&label=flathub%40installs&color=0451b8)](https://github.com/nokarin-dev/aqloss/releases/latest)
[![Latest Downloads](https://img.shields.io/github/downloads/nokarin-dev/aqloss/latest/total?style=for-the-badge&color=3d47d4)](https://github.com/nokarin-dev/aqloss/releases/latest)
[![Test Status](https://img.shields.io/github/actions/workflow/status/nokarin-dev/aqloss/ci.yml?style=for-the-badge&label=test%20build&color=22316e)](https://github.com/nokarin-dev/aqloss/actions/workflows/ci.yml)

</div>

---

> [!NOTE]
> Windows, Linux, and Android are the platforms I actually ship. macOS and iOS compile; I don't test them regularly.

On Windows, **WASAPI Exclusive** can send the stream straight to the device (no OS mixer). Volume, EQ, ReplayGain, and soft-clip are off in that mode - that's the point. Shared mode (and every other OS) goes through the mixer and whatever DSP you enable. Bit-perfect still needs a DAC/driver that won't resample behind your back.

---

## Formats

DSD (`.dsf` / `.dff`) is not supported. Symphonia has no DSD decoder, and I'm not adding a second path for it.
| Format | Extensions | Notes |
| --- | --- | --- |
| FLAC | `.flac` | lossless, up to 32-bit / 384 kHz |
| WAV / AIFF | `.wav` `.aiff` `.aif` | PCM |
| ALAC | `.m4a` | lossless |
| MP3 | `.mp3` | |
| AAC | `.aac` `.m4a` | |
| Vorbis | `.ogg` | |
| Opus | `.opus` | libopus via Symphonia adapter |

---

## Download

GitHub [releases](https://github.com/nokarin-dev/aqloss/releases/latest) (Windows installer/portable, Linux `.deb` / `.rpm` / AppImage / tarball, Android APKs). Linux is also on [Flathub](https://flathub.org/apps/xyz.nokarin.aqloss). Arch and derivatives: AUR [`aqloss-bin`](https://aur.archlinux.org/packages/aqloss-bin) (`yay -S aqloss-bin` / `paru -S aqloss-bin`).

The Windows installer is not code-signed. SmartScreen will complain; More info → Run anyway.

macOS and iOS are a rolling [Apple Build](https://github.com/nokarin-dev/aqloss/releases/tag/apple-build) (unsigned, overwritten on each stable tag).

---

## Build

You need Flutter (stable) and Rust (stable). For codegen changes, also `cargo install flutter_rust_bridge_codegen`.

```bash
flutter pub get
flutter_rust_bridge_codegen generate   # only if you touch the Rust API
```

```bash
flutter run -d windows
```

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev \
  libasound2-dev libpulse-dev
flutter run -d linux
```

```bash
flutter run -d android
```

---

## Last.fm / ListenBrainz

Both live under Settings → Integrations. Last.fm needs an API account because this repo is public and I don't ship a key - create one at [last.fm/api/account/create](https://www.last.fm/api/account/create) and paste it in settings. ListenBrainz uses your own user token.

Lua/webhook plugins: see [docs/plugin.md](docs/plugin.md).

---

## Support

- International: [Ko-fi](https://ko-fi.com/nokarin), [Buy Me a Coffee](https://www.buymeacoffee.com/nokarin), [Open Collective](https://opencollective.com/nokarin), [thanks.dev](https://thanks.dev/u/gh/nokarin-dev)
- Indonesia: [Trakteer](https://trakteer.id/nokarin), [Tako](https://tako.id/nokarin)

Also in Settings → Support.

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