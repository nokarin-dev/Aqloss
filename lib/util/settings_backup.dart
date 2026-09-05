import 'package:aqloss/models/playlist.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/theme/ui_framework.dart';
import 'package:aqloss/util/eq_presets.dart';
import 'package:aqloss/util/playback_speed.dart';

const kBackupFormat = 'aqloss-backup';
const kBackupVersion = 1;

class SettingsBackupPayload {
  final Map<String, dynamic> settings;
  final List<Playlist> playlists;
  final List<String> folders;

  const SettingsBackupPayload({
    required this.settings,
    required this.playlists,
    required this.folders,
  });
}

T? enumByName<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  for (final v in values) {
    if (v.name == raw) return v;
  }
  return null;
}

Map<String, dynamic> settingsToJson(SettingsState s) => {
  'outputMode': s.outputMode.name,
  'selectedDeviceId': s.selectedDeviceId,
  'gaplessPlayback': s.gaplessPlayback,
  'crossfade': s.crossfade.name,
  'replayGainMode': s.replayGainMode.name,
  'replayGainPreamp': s.replayGainPreamp,
  'skipSilence': s.skipSilence,
  'playbackSpeed': s.playbackSpeed,
  'stopAfter': s.stopAfter.name,
  'eqEnabled': s.eqEnabled,
  'eqGains': s.eqGains,
  'eqUserPresets': [
    for (final p in s.eqUserPresets) {'name': p.name, 'gains': p.gains},
  ],
  'notchFilter': s.notchFilter,
  'themeMode': s.themeMode.name,
  'appStyle': s.appStyle.name,
  'uiFramework': s.uiFramework.name,
  'libraryViewMode': s.libraryViewMode.name,
  'albumViewMode': s.albumViewMode.name,
  'showBitDepthInLibrary': s.showBitDepthInLibrary,
  'showNowPlayingHeader': s.showNowPlayingHeader,
  'shortcuts': {for (final e in s.shortcuts.entries) e.key.name: e.value},
  'showAlbumArtBackground': s.showAlbumArtBackground,
  'spectrumEnabled': s.spectrumEnabled,
  'spectrumStyle': s.spectrumStyle,
  'scrobbleLastFm': s.scrobbleLastFm,
  'lastFmUsername': s.lastFmUsername,
  'lastFmApiKey': s.lastFmApiKey,
  'lastFmApiSecret': s.lastFmApiSecret,
  'lastFmSessionKey': s.lastFmSessionKey,
  'scrobbleListenBrainz': s.scrobbleListenBrainz,
  'listenBrainzToken': s.listenBrainzToken,
  'listenBrainzUsername': s.listenBrainzUsername,
  'accentMode': s.accentMode.name,
  'accentColor': s.accentColor,
  'stereoWidth': s.stereoWidth,
  'haasMs': s.haasMs,
  'discordRpc': s.discordRpc,
  'materialYou': s.materialYou,
  'hardwareAcceleration': s.hardwareAcceleration,
  'closeToTray': s.closeToTray,
  'reduceMotion': s.reduceMotion,
  'showTitleBar': s.showTitleBar,
};

SettingsState settingsFromJson(
  Map<String, dynamic> json, {
  AudioOutputMode defaultOutputMode = AudioOutputMode.system,
}) {
  final shortcuts = <ShortcutAction, String>{};
  final rawShortcuts = json['shortcuts'];
  if (rawShortcuts is Map) {
    for (final e in rawShortcuts.entries) {
      final action = enumByName(ShortcutAction.values, e.key.toString());
      final value = e.value;
      if (action != null && value is String && value.isNotEmpty) {
        shortcuts[action] = value;
      }
    }
  }

  final presets = <EqPreset>[];
  final rawPresets = json['eqUserPresets'];
  if (rawPresets is List) {
    for (final item in rawPresets) {
      if (item is! Map) continue;
      final name = sanitizeEqPresetName('${item['name'] ?? ''}');
      if (name == null || isBuiltInEqPresetName(name)) continue;
      final gainsRaw = item['gains'];
      if (gainsRaw is! List) continue;
      final gains = <double>[
        for (final g in gainsRaw)
          if (g is num) g.toDouble(),
      ];
      if (gains.isEmpty) continue;
      presets.add(EqPreset(name: name, gains: normalizeEqGains(gains)));
      if (presets.length >= kMaxEqUserPresets) break;
    }
  }

  final gainsRaw = json['eqGains'];
  final eqGains = <double>[
    if (gainsRaw is List)
      for (final g in gainsRaw)
        if (g is num) g.toDouble(),
  ];

  return SettingsState(
    outputMode:
        enumByName(AudioOutputMode.values, json['outputMode']) ??
        defaultOutputMode,
    selectedDeviceId: json['selectedDeviceId'] as String?,
    gaplessPlayback: json['gaplessPlayback'] as bool? ?? true,
    crossfade:
        enumByName(CrossfadeMode.values, json['crossfade']) ??
        CrossfadeMode.off,
    replayGainMode:
        enumByName(ReplayGainMode.values, json['replayGainMode']) ??
        ReplayGainMode.off,
    replayGainPreamp: ((json['replayGainPreamp'] as num?)?.toDouble() ?? 0)
        .clamp(-12, 12),
    skipSilence: json['skipSilence'] as bool? ?? false,
    playbackSpeed: clampPlaybackSpeed(
      (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
    ),
    stopAfter:
        enumByName(StopAfterMode.values, json['stopAfter']) ??
        StopAfterMode.off,
    eqEnabled: json['eqEnabled'] as bool? ?? false,
    eqGains: normalizeEqGains(eqGains),
    eqUserPresets: presets,
    notchFilter: json['notchFilter'] as bool? ?? true,
    themeMode:
        enumByName(ThemeMode.values, json['themeMode']) ?? ThemeMode.dark,
    appStyle: enumByName(AppStyle.values, json['appStyle']) ?? AppStyle.legacy,
    uiFramework:
        enumByName(UiFramework.values, json['uiFramework']) ??
        UiFramework.standalone,
    libraryViewMode:
        enumByName(LibraryViewMode.values, json['libraryViewMode']) ??
        LibraryViewMode.detail,
    albumViewMode:
        enumByName(LibraryViewMode.values, json['albumViewMode']) ??
        LibraryViewMode.detail,
    showBitDepthInLibrary: json['showBitDepthInLibrary'] as bool? ?? true,
    showNowPlayingHeader: json['showNowPlayingHeader'] as bool? ?? false,
    shortcuts: shortcuts,
    showAlbumArtBackground: json['showAlbumArtBackground'] as bool? ?? true,
    spectrumEnabled: json['spectrumEnabled'] as bool? ?? true,
    spectrumStyle: ((json['spectrumStyle'] as num?)?.toInt() ?? 0).clamp(0, 3),
    scrobbleLastFm: json['scrobbleLastFm'] as bool? ?? false,
    lastFmUsername: json['lastFmUsername'] as String?,
    lastFmApiKey: json['lastFmApiKey'] as String?,
    lastFmApiSecret: json['lastFmApiSecret'] as String?,
    lastFmSessionKey: json['lastFmSessionKey'] as String?,
    scrobbleListenBrainz: json['scrobbleListenBrainz'] as bool? ?? false,
    listenBrainzToken: json['listenBrainzToken'] as String?,
    listenBrainzUsername: json['listenBrainzUsername'] as String?,
    accentMode:
        enumByName(AccentMode.values, json['accentMode']) ?? AccentMode.off,
    accentColor: (json['accentColor'] as num?)?.toInt(),
    stereoWidth: ((json['stereoWidth'] as num?)?.toDouble() ?? 1.0).clamp(
      0.0,
      2.0,
    ),
    haasMs: ((json['haasMs'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 25.0),
    discordRpc: json['discordRpc'] as bool? ?? true,
    materialYou: json['materialYou'] as bool? ?? false,
    hardwareAcceleration: json['hardwareAcceleration'] as bool? ?? true,
    closeToTray: json['closeToTray'] as bool? ?? true,
    reduceMotion: json['reduceMotion'] as bool? ?? false,
    showTitleBar: json['showTitleBar'] as bool? ?? true,
    loaded: true,
  );
}

Map<String, dynamic> encodeBackup({
  required SettingsState settings,
  required List<Playlist> playlists,
  required List<String> folders,
  DateTime? exported,
}) => {
  'format': kBackupFormat,
  'version': kBackupVersion,
  'exported': (exported ?? DateTime.now().toUtc()).toIso8601String(),
  'settings': settingsToJson(settings),
  'playlists': [for (final p in playlists) p.toJson()],
  'folders': folders,
};

SettingsBackupPayload? decodeBackup(Object? raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  if (map['format'] != kBackupFormat) return null;
  final version = map['version'];
  if (version is! int || version < 1 || version > kBackupVersion) return null;
  final settingsRaw = map['settings'];
  if (settingsRaw is! Map) return null;
  final settings = Map<String, dynamic>.from(settingsRaw);

  final playlists = <Playlist>[];
  final playlistsRaw = map['playlists'];
  if (playlistsRaw is List) {
    for (final item in playlistsRaw) {
      if (item is! Map) continue;
      try {
        playlists.add(Playlist.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {}
    }
  }

  final folders = <String>[];
  final foldersRaw = map['folders'];
  if (foldersRaw is List) {
    for (final item in foldersRaw) {
      if (item is String && item.trim().isNotEmpty) folders.add(item.trim());
    }
  }

  return SettingsBackupPayload(
    settings: settings,
    playlists: playlists,
    folders: folders,
  );
}
