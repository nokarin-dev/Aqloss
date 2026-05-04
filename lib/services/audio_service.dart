import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/providers/settings_provider.dart';

class AudioService {
  // Volume cache
  static double _cachedVolume = 1.0;

  // Init
  static Future<void> init({
    String? deviceId,
    bool exclusive = true,
    double? volume,
    SettingsState? settings,
  }) async {
    if (volume != null) _cachedVolume = volume.clamp(0.0, 1.0);

    try {
      if (deviceId != null) {
        await Future(
          () => backend.initEngineWithDevice(
            deviceId: deviceId,
            exclusive: exclusive,
          ),
        ).timeout(const Duration(seconds: 8));
      } else {
        await Future(
          () => backend.initEngine(),
        ).timeout(const Duration(seconds: 8));
      }
    } catch (e) {
      debugPrint('[AudioService] init error: $e — retrying shared');
      try {
        await Future(
          () => backend.initEngine(),
        ).timeout(const Duration(seconds: 6));
      } catch (e2) {
        debugPrint('[AudioService] shared init failed: $e2');
        return;
      }
    }

    await _applyVolume();
    if (settings != null) await applyDspSettings(settings);
  }

  // Playback
  static Future<void> loadTrack(String path) async {
    await backend.loadTrack(path: path);
    await _applyVolume();
  }

  static Future<void> play() async => backend.play();
  static Future<void> pause() async => backend.pause();
  static Future<void> stop() async => backend.stop();
  static Future<void> seek(double positionSecs) async =>
      backend.seek(positionSecs: positionSecs);

  static Future<void> setVolume(double volume) async {
    _cachedVolume = volume.clamp(0.0, 1.0);
    await _applyVolume();
  }

  // DSP
  static Future<void> applyDspSettings(SettingsState s) async {
    // Soft clip
    try {
      await backend.setSoftClip(enabled: s.notchFilter);
    } catch (_) {}

    // Skip silence
    try {
      await backend.setSkipSilence(enabled: s.skipSilence);
    } catch (_) {}

    if (!s.replayGainEnabled) {
      try {
        await backend.setReplayGain(linearGain: 1.0);
      } catch (_) {}
    }
  }

  static Future<void> applyReplayGainForTrack({
    required ReplayGainMode mode,
    required double preampDb,
    double? trackGainDb,
    double? albumGainDb,
    bool isPlayingInOrder = false,
  }) async {
    if (mode == ReplayGainMode.off) {
      await backend.setReplayGain(linearGain: 1.0);
      return;
    }

    double? gainDb;
    switch (mode) {
      case ReplayGainMode.track:
        gainDb = trackGainDb;
        break;
      case ReplayGainMode.album:
        gainDb = albumGainDb ?? trackGainDb;
        break;
      case ReplayGainMode.auto:
        gainDb = isPlayingInOrder ? (albumGainDb ?? trackGainDb) : trackGainDb;
        break;
      case ReplayGainMode.off:
        break;
    }

    if (gainDb == null) {
      gainDb = preampDb;
    } else {
      gainDb = gainDb + preampDb;
    }

    gainDb = gainDb.clamp(-40.0, 20.0);
    final linearGain = math.pow(10.0, gainDb / 20.0).toDouble();

    try {
      await backend.setReplayGain(linearGain: linearGain.toDouble());
    } catch (e) {
      debugPrint('[AudioService] setReplayGain error: $e');
    }
  }

  // Internal
  static Future<void> _applyVolume() async {
    try {
      await backend.setVolume(volume: _cachedVolume);
    } catch (e) {
      debugPrint('[AudioService] setVolume error: $e');
    }
  }
}
