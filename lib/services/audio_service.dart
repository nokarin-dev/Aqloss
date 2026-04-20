import 'package:aqloss/src/rust/api.dart' as backend;

class AudioService {
  static Future<void> init() async {
    backend.initEngine();
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
