# Translations

English in the app is the key. Copy `assets/l10n/en.json` to `assets/l10n/<code>.json`, then fill the values. `en.json` is the full list of lines. Its values are empty on purpose, and the app does not treat it as a language.

## Add a language

1. Copy `assets/l10n/en.json` to `assets/l10n/it.json`. The filename is the language code: 2 to 8 lowercase letters. `it` is Italian, `id` is Indonesian, `de` is German. `it-IT.json` and `italiano.json` are ignored.
2. Set `_name` to the language's own name. That is the label in Settings, Display, Language.
3. Leave every other key exactly as it is. Replace the empty value.
4. Run the app again. Settings, Display, Language lists it as a dropdown row, with the percent of lines that replaced English.

A missing key, a value of `""`, or a value that is not text is not loaded. That line stays English and does not count toward the percent.

`{count}` and `{version}` are filled in by the app. The `{tokens}` in the value have to be the same set as in the key. If one is missing or added, that line is not loaded.

```json
{
  "Scanned {count} tracks": "{count} brani analizzati"
}
```

`Scanned 1 track` is a separate line from `Scanned {count} tracks`. Same for `1 file missing` and `{count} files missing`. Translate both.

Leave the name Aqloss as Aqloss.

Text that is not in `en.json` is still English. That includes most of the settings body and short toasts such as "Playing next".

## Example

`assets/l10n/it.json`:

```json
{
  "_name": "Italiano",
  "Library": "Libreria",
  "Albums": "Album",
  "Artists": "Artisti",
  "History": "Cronologia",
  "Settings": "Impostazioni",
  "{count} tracks": "{count} brani",
  "Scanned 1 track": "Analizzato 1 brano",
  "Scanned {count} tracks": "{count} brani analizzati",
  "Version {version} is available": "La versione {version} è disponibile"
}
```

The lines you leave empty stay English. Every key to fill is in `assets/l10n/en.json`.

## Every string the app translates today

Copy `assets/l10n/en.json`. The same keys are listed here with empty values.

```json
{
  "_name": "",
  "Language": "",
  "English": "",
  "System": "",
  "System, English, or a translation file. The percent is how many lines replaced English.": "",
  "Theme": "",
  "Colour scheme for the app.": "",
  "Dark": "",
  "Light": "",
  "NAVIGATE": "",
  "Now Playing": "",
  "Library": "",
  "Albums": "",
  "Artists": "",
  "History": "",
  "Settings": "",
  "Playlist": "",
  "PLAYLISTS": "",
  "Search": "",
  "Queue": "",
  "More": "",
  "Loved": "",
  "New playlist": "",
  "{count} tracks": "",
  "Music Folders": "",
  "Audio Output": "",
  "Playback": "",
  "DSP / EQ": "",
  "Display": "",
  "Integrations": "",
  "Shortcuts": "",
  "Plugins": "",
  "Updates": "",
  "Support": "",
  "About": "",
  "Folders Aqloss scans for audio files": "",
  "Device and output mode selection": "",
  "Gapless, crossfade, ReplayGain, skip silence": "",
  "Equalizer, soft-clip, stereo width and depth": "",
  "Theme, language, spectrum analyser, album art": "",
  "Manage external services, rich presence, and plugins": "",
  "Global keyboard shortcuts": "",
  "Installed third-party and built-in plugins": "",
  "Check for new releases": "",
  "Ko-fi, Trakteer, and other ways to help": "",
  "Version, logs, and backup": "",
  "LIBRARY": "",
  "PLAYBACK": "",
  "APPEARANCE": "",
  "SYSTEM": "",
  "Shuffle": "",
  "Repeat": "",
  "Repeat track": "",
  "Repeat album": "",
  "Repeat all": "",
  "Previous": "",
  "Next": "",
  "Play": "",
  "Pause": "",
  "Show Aqloss": "",
  "Quit": "",
  "Play / Pause": "",
  "Next track": "",
  "Previous track": "",
  "Volume up 5%": "",
  "Volume down 5%": "",
  "Toggle sidebar": "",
  "Toggle queue panel": "",
  "Open search": "",
  "Toggle mini player": "",
  "Go to Now Playing": "",
  "Go to Library": "",
  "Go to Albums": "",
  "Go to Artists": "",
  "Go to History": "",
  "Go to Settings": "",
  "Scanned 1 track": "",
  "Scanned {count} tracks": "",
  "Library scan failed": "",
  "Scrobble failed": "",
  "Version {version} is available": "",
  "Removed 1 missing file": "",
  "Removed {count} missing files": "",
  "1 file missing": "",
  "{count} files missing": "",
  "Backup saved": "",
  "Backup restored": "",
  "Could not save backup": "",
  "Could not restore backup": "",
  "This is not an Aqloss backup": "",
  "Storage permission is required to scan music folders": "",
  "Could not open that folder": "",
  "This folder cannot be scanned. Pick a folder on internal storage, such as Music.": "",
  "Copy tracks into Files, On My iPhone, Aqloss. Add Folder only works for folders you pick in Files.": "",
  "Nightly build": "",
  "This is a rolling build from main. Features may be unfinished or break. Use a GitHub or Flathub release if you want something stable.": "",
  "OK": ""
}
```
