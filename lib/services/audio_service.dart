import 'dart:async';
import 'dart:math' as math;
import 'package:aqloss/util/logger.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/providers/settings_provider.dart';

class AudioService {
  // Volume cache
  static double _cachedVolume = 1.0;

  // Freeze watchdog
  static Timer? _watchdog;
  static bool _recovering = false;
  static void Function()? onFreezeDetected;

  static void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_recovering) return;
      try {
        final dead = backend.isDecodeThreadDead();
        if (dead) {
          _recovering = true;
          Logger.debugAudioService('FREEZE detected - recovering engine');
          try {
            await Future(
              () => backend.recoverEngine(),
            ).timeout(const Duration(seconds: 6));
            Logger.debugAudioService('recoverEngine() OK');
            onFreezeDetected?.call();
          } catch (e) {
            Logger.debugAudioService('recoverEngine() failed: $e');
          } finally {
            _recovering = false;
          }
        }
      } catch (_) {}
    });
  }

  static void stopWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

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
      Logger.warnAudioService('init error: $e - retrying shared');
      try {
        await Future(
          () => backend.initEngine(),
        ).timeout(const Duration(seconds: 6));
      } catch (e2) {
        Logger.errorAudioService('shared init failed: $e2');
        return;
      }
    }
    await _applyVolume();
    if (settings != null) await applyAllDsp(settings);
    _startWatchdog();
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

  static Future<void> applyAllDsp(SettingsState s) async {
    await Future.wait([
      backend.setSoftClip(enabled: s.notchFilter).catchError((_) {}),
      backend.setSkipSilence(enabled: s.skipSilence).catchError((_) {}),
      backend.setGapless(enabled: s.gaplessPlayback).catchError((_) {}),
      backend
          .setCrossfadeSecs(secs: s.crossfadeSecs.toDouble())
          .catchError((_) {}),
      backend.setEqEnabled(enabled: s.eqEnabled).catchError((_) {}),
      backend.setEqGains(gains: s.eqGains).catchError((_) {}),
      if (!s.replayGainEnabled)
        backend.setReplayGain(linearGain: 1.0).catchError((_) {}),
    ]);
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
      case ReplayGainMode.album:
        gainDb = albumGainDb ?? trackGainDb;
      case ReplayGainMode.auto:
        gainDb = isPlayingInOrder ? (albumGainDb ?? trackGainDb) : trackGainDb;
      case ReplayGainMode.off:
        break;
    }
    gainDb = ((gainDb ?? 0.0) + preampDb).clamp(-40.0, 20.0);
    final linear = math.pow(10.0, gainDb / 20.0).toDouble();
    try {
      await backend.setReplayGain(linearGain: linear);
    } catch (e) {
      Logger.debugAudioService('setReplayGain: $e');
    }
  }

  // Internal
  static Future<void> _applyVolume() async {
    try {
      await backend.setVolume(volume: _cachedVolume);
    } catch (e) {
      Logger.debugAudioService('setVolume: $e');
    }
  }
}
