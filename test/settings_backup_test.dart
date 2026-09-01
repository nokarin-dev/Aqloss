import 'dart:convert';

import 'package:aqloss/models/playlist.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/services/settings_backup_service.dart';
import 'package:aqloss/theme/ui_framework.dart';
import 'package:aqloss/util/eq_presets.dart';
import 'package:aqloss/util/notices.dart';
import 'package:aqloss/util/settings_backup.dart';
import 'package:flutter_test/flutter_test.dart';

Track _t(String path) => Track(
  path: path,
  durationSecs: 1,
  sampleRate: 44100,
  channels: 2,
  format: 'FLAC',
  fileSizeBytes: 1,
);

void main() {
  test('backup roundtrip keeps settings, playlists, and folders', () {
    final settings = SettingsState(
      outputMode: AudioOutputMode.exclusive,
      selectedDeviceId: 'hw:0',
      gaplessPlayback: false,
      crossfade: CrossfadeMode.medium,
      replayGainMode: ReplayGainMode.album,
      replayGainPreamp: -3.5,
      skipSilence: true,
      playbackSpeed: 1.25,
      eqEnabled: true,
      eqGains: const [1, 2, 0, 0, 0, 0, 0, 0, 0, -1],
      eqUserPresets: const [
        EqPreset(name: 'Night', gains: [2, 1, 0, 0, 0, 0, 0, 0, 1, 2]),
      ],
      themeMode: ThemeMode.light,
      uiFramework: UiFramework.material3,
      shortcuts: const {ShortcutAction.search: 'Ctrl+K'},
      lastFmSessionKey: 'sess',
      listenBrainzToken: 'tok',
      hardwareAcceleration: false,
      closeToTray: false,
      loaded: true,
    );
    final playlists = [
      Playlist(
        id: '1',
        name: 'Late',
        createdAt: DateTime.utc(2026, 1, 2),
        tracks: [_t('/a.flac')],
      ),
    ];
    final encoded = encodeBackup(
      settings: settings,
      playlists: playlists,
      folders: const ['/music'],
      exported: DateTime.utc(2026, 8, 31),
    );
    expect(encoded['format'], kBackupFormat);
    expect(encoded['version'], kBackupVersion);

    final payload = decodeBackup(encoded)!;
    expect(payload.folders, ['/music']);
    expect(payload.playlists.single.name, 'Late');
    expect(payload.playlists.single.tracks.single.path, '/a.flac');

    final restored = settingsFromJson(payload.settings);
    expect(restored.outputMode, AudioOutputMode.exclusive);
    expect(restored.selectedDeviceId, 'hw:0');
    expect(restored.crossfade, CrossfadeMode.medium);
    expect(restored.replayGainMode, ReplayGainMode.album);
    expect(restored.replayGainPreamp, -3.5);
    expect(restored.eqUserPresets.single.name, 'Night');
    expect(restored.shortcuts[ShortcutAction.search], 'Ctrl+K');
    expect(restored.lastFmSessionKey, 'sess');
    expect(restored.listenBrainzToken, 'tok');
    expect(restored.hardwareAcceleration, isFalse);
    expect(restored.closeToTray, isFalse);
    expect(restored.playbackSpeed, 1.25);
    expect(restored.uiFramework, UiFramework.material3);
  });

  test('decodeBackup rejects the wrong format', () {
    expect(
      decodeBackup({'format': 'nope', 'version': 1, 'settings': {}}),
      isNull,
    );
    expect(
      decodeBackup({'format': kBackupFormat, 'version': 99, 'settings': {}}),
      isNull,
    );
    expect(decodeBackup('not json'), isNull);
  });

  test('parseBackupText names invalid files for the user', () {
    expect(
      SettingsBackupService.parseBackupText('not-json').error,
      kBackupFailedMessage,
    );
    expect(
      SettingsBackupService.parseBackupText(
        jsonEncode({'format': 'other', 'version': 1, 'settings': {}}),
      ).error,
      kBackupInvalidMessage,
    );
  });

  test('unknown enum names fall back instead of crashing', () {
    final restored = settingsFromJson({
      'outputMode': 'bitperfect',
      'crossfade': 'forever',
      'eqGains': [99, -99],
    });
    expect(restored.outputMode, AudioOutputMode.system);
    expect(restored.crossfade, CrossfadeMode.off);
    expect(restored.eqGains.first, 12.0);
    expect(restored.eqGains[1], -12.0);
    expect(restored.closeToTray, isTrue);
  });
}
