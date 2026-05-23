import 'dart:typed_data';

class MediaControlPlatform {
  static Future<void> init({
    required void Function() onPlay,
    required void Function() onPause,
    required void Function() onNext,
    required void Function() onPrevious,
    required void Function(Duration) onSeek,
  }) async {}

  static Future<void> update({
    required String title,
    required String artist,
    required String album,
    required bool isPlaying,
    Duration? position,
    Duration? duration,
    Uint8List? artBytes,
  }) async {}

  static void clear() {}
  static void dispose() {}
}
