# Contributing to Aqloss

Thanks for wanting to contribute. Here's what you need to know.

## Project structure

```
lib/                → Flutter frontend (Dart)
rust/src/           → Audio backend (Rust)
  audio_engine.rs   → playback core
  discord_rpc.rs    → Discord rich presence
  api.rs            → bridge between Rust and Flutter
```

## Getting started

1. Make sure you have Flutter and Rust installed
2. Fork the repo and clone your fork
3. Run `flutter pub get` in the root
4. Run `cargo build` inside `rust/`
5. Start the app with `flutter run`

## Before submitting a PR

- Keep changes focused — one fix or feature per PR
- If you're fixing a bug, mention the issue number (`Fixes #123`)
- Test on your platform at minimum; note if you can't test others
- For Rust changes, make sure there are no new `unwrap()`/`expect()` on hot paths — use `?` or `global_opt()` instead
- For Flutter changes, test both desktop and mobile behavior if relevant (they can differ, e.g. context menus)
- Short commit messages are fine, just be descriptive enough

## Code style

- Rust: `cargo fmt` before committing
- Dart: `dart format .` before committing
- Comments are welcome but keep them brief — `// ...` style, not paragraph essays

## What to work on

Check issues labeled `good first issue` or `help wanted`. If you want to work on something, leave a comment first so we don't duplicate effort.

## Reporting bugs

Use the bug report template. Logs are really helpful — especially backend logs and `RUST_BACKTRACE=1` output for panics.
