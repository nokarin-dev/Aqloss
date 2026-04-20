# Aqloss
A cross-platform music player engineered for bit-perfect, lossless, and hi-res audio playback - on every device you own.

---

## Why Aqloss?
Most music players resample, normalize, or quietly degrade your audio before it reaches your ears. Aqloss does not. It decodes your files exactly as they were recorded and sends them to your hardware without touching a single sample.

- **Bit-perfect output** - WASAPI Exclusive (Windows), CoreAudio (macOS/iOS), PipeWire/ALSA (Linux), AAudio (Android)
- **Hi-res support** - up to 32-bit / 384kHz
- **True lossless formats** - FLAC, WAV, AIFF, ALAC, DSD (DSF/DFF)
- **One codebase** - Flutter UI runs natively on all 5 platforms
- **Rust audio engine** - high-performance, memory-safe, zero compromises

---

## Screenshots

> Coming soon.

---

## Format Support

| Format | Extension     | Max Bit Depth | Max Sample Rate |
|--------|---------------|---------------|-----------------|
| FLAC   | `.flac`       | 32-bit        | 384 kHz         |
| WAV    | `.wav`        | 32-bit        | 384 kHz         |
| AIFF   | `.aiff`       | 32-bit        | 384 kHz         |
| ALAC   | `.m4a`        | 24-bit        | 192 kHz         |
| DSD    | `.dsf` `.dff` | 1-bit DSD     | DSD256          |
| MP3    | `.mp3`        | -             | 48 kHz          |
| AAC    | `.aac` `.m4a` | -             | 48 kHz          |
| OGG    | `.ogg`        | -             | 48 kHz          |

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

### Platform-specific setup

**Windows**
```bash
# WASAPI Exclusive Mode requires no extra setup.
# Make sure you have Visual Studio Build Tools installed.
flutter run -d windows
```

**Linux**
```bash
# Install PipeWire / ALSA dev headers
sudo apt install libasound2-dev libpipewire-0.3-dev pkg-config

flutter run -d linux
```

**macOS**
```bash
# CoreAudio is available out of the box.
flutter run -d macos
```

**Android**
```bash
# Connect device or start emulator
flutter run -d android
```

**iOS**
```bash
# Requires Xcode and Apple Developer account
flutter run -d ios
```

---

## Contributing

Contributions are welcome. Please open an issue first to discuss what you'd like to change.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/gapless-playback`)
3. Commit your changes (`git commit -m 'Add gapless playback'`)
4. Push to the branch (`git push origin feature/gapless-playback`)
5. Open a Pull Request

---

## License

```
Aqless
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
