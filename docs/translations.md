# Translations

Each line is a short key and its text. `sidebar.now_playing` is the key. `Now Playing` is the English text. Copy `assets/l10n/en.json` to `assets/l10n/<code>.json`, then replace the values. The app uses `en.json` as the English fallback. It does not list `en` as a language in Settings.

## Add a language

1. Copy `assets/l10n/en.json` to `assets/l10n/<code>.json`. The filename is the language code: 2 to 8 lowercase letters. `it` is Italian, `id` is Indonesian, `de` is German. `it-IT.json` and `italiano.json` are ignored.
2. Set `_name` to the language's own name. That is the label in Settings, Display, Language.
3. Leave every key as it is. Replace the English value with the translation.
4. Run the app again. Settings, Display, Language lists it as a dropdown row, with the percent of lines that replaced English.

A blank line separates each part of the app. A key that starts with `_`, other than `_name`, is a heading. Leave it. It is not a line to translate and it is not counted.

A missing key, a value of `""`, or a value that is not text is not loaded. That line stays English and does not count toward the percent.

`{count}` and `{version}` are filled in by the app. The `{tokens}` in the value have to be the same set as in the English value. If one is missing or added, that line is not loaded.

```json
{
  "library.scanned": "{count} brani analizzati"
}
```

`{count}` covers 1 as well. There is no separate line for a single item.

Leave the name Aqloss as Aqloss.

## Example

```json
{
  "_name": "English",

  "_sidebar": "",
  "sidebar.library": "Library",
  "sidebar.albums": "Albums",
  "sidebar.artists": "Artists",
  "sidebar.history": "History",
  "sidebar.settings": "Settings",

  "_library": "",
  "library.tracks": "{count} tracks",
  "library.scanned": "Scanned {count} tracks",

  "_updates": "",
  "updates.available": "Version {version} is available",
}
```
You can see more at `assets/l10n/en,json`.

The lines you leave empty stay English. Every key to fill is in `assets/l10n/en.json`.
