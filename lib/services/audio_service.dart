import 'dart:async';
import 'dart:math' as math;
import 'package:aqloss/util/logger.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/providers/settings_provider.dart';

class AudioService {
  // Volume cache
  static double _cachedVolume = 1.0;
  static bool _engineReady = false;
  static bool get engineReady => _engineReady;

  // Freeze watchdog
  static Timer? _watchdog;
  static bool _recovering = false;
  static void Function()? onFreezeDetected;

  // Device-change watchdog
  static void Function(String? newDefaultDeviceId)? onDeviceChanged;
  static Timer? _deviceWatchdog;
  static bool _reinitingForDevice = false;
  static List<String> _lastDeviceIds = [];
  static String? _lastDefaultId;

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
            _engineReady = true;
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
    _deviceWatchdog?.cancel();
    _deviceWatchdog = null;
  }

  static int _deviceChangePendingCount = 0;
  static const int _kDeviceChangeDebounce = 2;

  static void _startDeviceWatchdog() {
    _deviceWatchdog?.cancel();
    _deviceChangePendingCount = 0;
    _deviceWatchdog = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_reinitingForDevice || _recovering) return;
      try {
        final devices = await Future(
          () => backend.enumerateAudioDevices(),
        ).timeout(const Duration(seconds: 3));

        final ids = devices.map((d) => d.id).toList()..sort();
        final defaultId = devices.where((d) => d.isDefault).firstOrNull?.id;

        if (_lastDeviceIds.isEmpty) {
          _lastDeviceIds = ids;
          _lastDefaultId = defaultId;
          _deviceChangePendingCount = 0;
          return;
        }

        final idsChanged = ids.join(',') != _lastDeviceIds.join(',');
        final defaultChanged = defaultId != _lastDefaultId;

        if (idsChanged || defaultChanged) {
          _deviceChangePendingCount++;
          if (_deviceChangePendingCount >= _kDeviceChangeDebounce) {
            Logger.debugAudioService(
              'device change confirmed (${_deviceChangePendingCount}x) '
              '— default: $_lastDefaultId → $defaultId',
            );
            _lastDeviceIds = ids;
            _lastDefaultId = defaultId;
            _deviceChangePendingCount = 0;
            onDeviceChanged?.call(defaultId);
          }
        } else {
          _deviceChangePendingCount = 0;
        }
      } catch (_) {
        // Enumeration can fail briefly during transitions
      }
    });
  }

  // Init
  static Future<void> init({
    String? deviceId,
    bool exclusive = true,
    double? volume,
    SettingsState? settings,
  }) async {
    _engineReady = false;
    if (volume != null) _cachedVolume = volume.clamp(0.0, 1.0);

    const delays = [0, 1000, 2000];
    for (int attempt = 0; attempt < delays.length; attempt++) {
      if (delays[attempt] > 0) {
        await Future.delayed(Duration(milliseconds: delays[attempt]));
      }
      try {
        Logger.debugAudioService('engine attempt ${attempt + 1} start');
        if (deviceId != null) {
          await backend
              .initEngineWithDevice(deviceId: deviceId, exclusive: exclusive)
              .timeout(const Duration(seconds: 8));
        } else {
          await backend.initEngine().timeout(const Duration(seconds: 8));
        }
        Logger.debugAudioService('engine attempt ${attempt + 1} SUCCESS');
        _engineReady = true;
        Logger.debugAudioService('engine ready (attempt ${attempt + 1})');
        break;
      } catch (e, st) {
        Logger.errorAudioService('init attempt ${attempt + 1} FAILED: $e\n$st');
        if (attempt == delays.length - 1) {
          try {
            Logger.debugAudioService('initEngine fallback start');
            await backend.initEngine().timeout(const Duration(seconds: 6));
            Logger.debugAudioService('[aqloss] initEngine fallback SUCCESS');
            _engineReady = true;
            Logger.debugAudioService('engine ready (fallback shared)');
          } catch (e2, st2) {
            Logger.errorAudioService('engine init FATAL: $e2\n$st2');
            return;
          }
        }
      }
    }

    if (!_engineReady) return;
    await _applyVolume();
    if (settings != null) await applyAllDsp(settings);
    _startWatchdog();
    _startDeviceWatchdog();
  }

  static Future<bool> reinitToDevice({
    required String? deviceId,
    required bool exclusive,
  }) async {
    if (_reinitingForDevice) return false;
    _reinitingForDevice = true;
    _engineReady = false;
    Logger.debugAudioService('reinitToDevice: $deviceId exclusive=$exclusive');
    try {
      if (deviceId != null) {
        await backend
            .reinitEngine(deviceId: deviceId, exclusive: exclusive)
            .timeout(const Duration(seconds: 8));
      } else {
        await backend.initEngine().timeout(const Duration(seconds: 8));
      }
      _engineReady = true;
      await _applyVolume();
      Logger.debugAudioService('reinitToDevice OK');
      return true;
    } catch (e) {
      Logger.errorAudioService(
        'reinitToDevice failed: $e — trying system default',
      );
      try {
        await backend.initEngine().timeout(const Duration(seconds: 6));
        _engineReady = true;
        await _applyVolume();
        Logger.debugAudioService('reinitToDevice fallback OK');
        return true;
      } catch (e2) {
        Logger.errorAudioService('reinitToDevice fallback also failed: $e2');
        return false;
      }
    } finally {
      _reinitingForDevice = false;
    }
  }

  // Playback
  static Future<void> loadTrack(String path) async {
    if (!_engineReady) {
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_engineReady) break;
      }
    }
    if (!_engineReady) throw Exception('AudioEngine not ready');
    await backend.loadTrack(path: path);
    await _applyVolume();
  }

  static Future<void> play() async {
    if (!_engineReady) {
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_engineReady) break;
      }
    }
    if (!_engineReady) throw Exception('AudioEngine not ready');
    return backend.play();
  }

  static Future<void> pause() async {
    if (!_engineReady) return;
    return backend.pause();
  }

  static Future<void> stop() async {
    if (!_engineReady) return;
    return backend.stop();
  }

  static Future<void> seek(double positionSecs) async {
    if (!_engineReady) throw Exception('AudioEngine not ready');
    return backend.seek(positionSecs: positionSecs);
  }

  static Future<void> setVolume(double volume) async {
    _cachedVolume = volume.clamp(0.0, 1.0);
    await _applyVolume();
  }

  static Future<void> setStereoWidth(double width) async {
    if (!_engineReady) return;
    try {
      await backend.setStereoWidth(width: width);
    } catch (e) {
      Logger.debugAudioService('setStereoWidth: $e');
    }
  }

  static Future<void> setHaasMs(double ms) async {
    if (!_engineReady) return;
    try {
      await backend.setHaasMs(ms: ms);
    } catch (e) {
      Logger.debugAudioService('setHaasMs: $e');
    }
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
      backend.setStereoWidth(width: s.stereoWidth).catchError((_) {}),
      backend.setHaasMs(ms: s.haasMs).catchError((_) {}),
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
