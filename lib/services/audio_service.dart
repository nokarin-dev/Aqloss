import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:flutter/foundation.dart';

class AudioService {
  static Future<void> init() async {
    try {
      await backend.initEngine().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[AudioService] initEngine timed out, continuing...');
        },
      );
    } catch (e) {
      debugPrint('[AudioService] initEngine error: $e');
    }
  }

  static Future<void> loadTrack(String path) async {
    await backend.loadTrack(path: path);
  }

  static Future<void> play() async {
    await backend.play();
  }

  static Future<void> pause() async {
    await backend.pause();
  }

  static Future<void> stop() async {
    await backend.stop();
  }

  static Future<void> seek(double positionSecs) async {
    await backend.seek(positionSecs: positionSecs);
  }

  static Future<void> setVolume(double volume) async {
    await backend.setVolume(volume: volume);
  }
}
