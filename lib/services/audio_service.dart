import 'package:flutter/foundation.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

class AudioService {
  static Future<void> init({String? deviceId, bool exclusive = true}) async {
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
      debugPrint('[AudioService] init error: $e — retrying with shared mode');
      try {
        await Future(
          () => backend.initEngine(),
        ).timeout(const Duration(seconds: 6));
      } catch (e2) {
        debugPrint('[AudioService] shared mode init also failed: $e2');
      }
    }
  }

  static Future<void> loadTrack(String path) async {
    await backend.loadTrack(path: path);
  }

  static Future<void> play() async => backend.play();
  static Future<void> pause() async => backend.pause();
  static Future<void> stop() async => backend.stop();

  static Future<void> seek(double positionSecs) async =>
      backend.seek(positionSecs: positionSecs);

  static Future<void> setVolume(double volume) async =>
      backend.setVolume(volume: volume);
}
