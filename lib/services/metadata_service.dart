import 'dart:typed_data';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

class MetadataService {
  static final MetadataService _instance = MetadataService._();
  factory MetadataService() => _instance;
  MetadataService._();

  final Map<String, Uint8List?> _artCache = {};

  Future<Uint8List?> getAlbumArt(Track track) async {
    if (_artCache.containsKey(track.path)) {
      return _artCache[track.path];
    }

    try {
      final bytes = await backend.readAlbumArt(path: track.path);
      _artCache[track.path] = bytes != null ? Uint8List.fromList(bytes) : null;

      _artCache[track.path] = null;
    } catch (_) {
      _artCache[track.path] = null;
    }

    return _artCache[track.path];
  }

  Future<void> prefetchArt(List<Track> tracks) async {
    for (final track in tracks) {
      if (!_artCache.containsKey(track.path)) {
        await getAlbumArt(track);
      }
    }
  }

  void clearCache() => _artCache.clear();

  static String formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  static String formatSampleRate(int hz) {
    if (hz % 1000 == 0) return '${hz ~/ 1000} kHz';
    return '${(hz / 1000).toStringAsFixed(1)} kHz';
  }
}
