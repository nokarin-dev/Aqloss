# Aqloss
**Lossless everywhere.**

A cross-platform music player engineered for bit-perfect, lossless, and hi-res audio playback — on every device you own.

> Windows · Linux · macOS · Android · iOS

---

## Why Aqloss?
Most music players resample, normalize, or quietly degrade your audio before it reaches your ears. Aqloss does not. It decodes your files exactly as they were recorded and sends them to your hardware without touching a single sample.

- **Bit-perfect output** — WASAPI Exclusive (Windows), CoreAudio (macOS/iOS), PipeWire/ALSA (Linux), AAudio (Android)
- **Hi-res support** — up to 32-bit / 384kHz
- **True lossless formats** — FLAC, WAV, AIFF, ALAC, DSD (DSF/DFF)
- **One codebase** — Flutter UI runs natively on all 5 platforms
- **Rust audio engine** — high-performance, memory-safe, zero compromises

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
| MP3    | `.mp3`        | —             | 48 kHz          |
| AAC    | `.aac` `.m4a` | —             | 48 kHz          |
| OGG    | `.ogg`        | —             | 48 kHz          |

---

## Architecture

```
┌─────────────────────────────────────┐
│         Flutter UI (Dart)           │
│  Player · Library · Settings · EQ   │
└────────────────┬────────────────────┘
                 │ flutter_rust_bridge (FFI)
┌────────────────▼────────────────────┐
│        Rust Audio Engine            │
│  Symphonia · CPAL · Rubato · lofty  │
└────────────────┬────────────────────┘
                 │ Native audio API
   ┌─────────────┼──────────────────┐
   │             │                  │
WASAPI      CoreAudio          PipeWire
(Windows)  (macOS/iOS)    (Linux / Android AAudio)
```

**Key libraries:**

| Library                                                               | Role                                      |
|-----------------------------------------------------------------------|-------------------------------------------|
| [Symphonia](https://github.com/pdeljanov/Symphonia)                   | Audio decoding (FLAC, WAV, MP3, AAC, OGG) |
| [CPAL](https://github.com/RustAudio/cpal)                             | Cross-platform audio output               |
| [Rubato](https://github.com/HEnquist/rubato)                          | High-quality sample rate conversion       |
| [lofty-rs](https://github.com/Serial-ATA/lofty-rs)                    | Metadata & tag parsing                    |
| [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) | Dart ↔ Rust FFI bridge                    |
| [drift](https://drift.simonbinder.eu/)                                | SQLite ORM for music library              |
| [riverpod](https://riverpod.dev/)                                     | State management                          |

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.19
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

## Project Structure

```
aqloss/
├── rust/                        # Rust audio engine
│   └── src/
│       ├── lib.rs               # Bridge API exposed to Dart
│       ├── audio_engine.rs      # Main engine: decode → resample → output
│       ├── decoder.rs           # Symphonia-based format decoder
│       ├── output.rs            # CPAL audio output abstraction
│       ├── resampler.rs         # Rubato resampler wrapper
│       └── metadata.rs          # lofty-rs tag & album art reader
│
├── flutter/
│   └── lib/
│       ├── main.dart            # Entry point
│       ├── app.dart             # App root, theme, routing
│       ├── screens/
│       │   ├── home_screen.dart
│       │   ├── player_screen.dart
│       │   ├── library_screen.dart
│       │   └── settings_screen.dart
│       ├── widgets/
│       │   ├── player_controls.dart
│       │   ├── track_tile.dart
│       │   ├── waveform_bar.dart
│       │   └── spectrum_display.dart
│       ├── models/
│       │   ├── track.dart
│       │   ├── playlist.dart
│       │   └── audio_format.dart
│       ├── services/
│       │   ├── audio_service.dart
│       │   ├── library_service.dart
│       │   └── metadata_service.dart
│       └── providers/
│           ├── player_provider.dart
│           ├── library_provider.dart
│           └── settings_provider.dart
│
├── assets/
│   ├── icons/
│   └── fonts/
│
└── README.md
```

---

## Roadmap

### v0.1 — MVP
- [x] Project structure & bridge setup
- [ ] FLAC + WAV playback
- [ ] Basic player UI (play / pause / skip / seek)
- [ ] Folder scan & library indexing
- [ ] Metadata display (title, artist, album art)

### v0.2 — Hi-Res
- [ ] Full format support (ALAC, AIFF, DSD)
- [ ] Bit-perfect output (WASAPI Exclusive, CoreAudio)
- [ ] Sample rate & bit depth display
- [ ] Gapless playback

### v0.3 — Features
- [ ] Parametric equalizer
- [ ] ReplayGain normalization
- [ ] Playlist management
- [ ] Search & filter
- [ ] Cue sheet support

### v0.4 — Polish
- [ ] Last.fm scrobbling
- [ ] Theme customization
- [ ] Keyboard & media key support
- [ ] Lock screen controls (mobile)

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

MIT License — see [LICENSE](LICENSE) for details.

---

*Nothing lost.*
