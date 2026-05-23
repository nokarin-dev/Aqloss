import 'dart:io';
import 'dart:typed_data';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

// Platform-specific imports via conditional compilation
import 'media_control_linux.dart'
    if (dart.library.js_util) 'media_control_stub.dart'
    as linux;
import 'media_control_windows.dart'
    if (dart.library.js_util) 'media_control_stub.dart'
    as windows;
import 'media_control_mobile.dart'
    if (dart.library.js_util) 'media_control_stub.dart'
    as mobile;

/// Platform-agnostic facade. Driven by [update] each time PlayerState changes.
class MediaControlService {
  MediaControlService._();

  static bool _initialized = false;
  static String? _lastArtPath;
  static Uint8List? _lastArtBytes;

  static bool get _isSupported =>
      Platform.isLinux ||
      Platform.isWindows ||
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS;

  static Future<void> init({
    required void Function() onPlay,
    required void Function() onPause,
    required void Function() onNext,
    required void Function() onPrevious,
    required void Function(Duration) onSeek,
  }) async {
    if (_initialized || !_isSupported) return;
    _initialized = true;

    if (Platform.isLinux) {
      await linux.MediaControlPlatform.init(
        onPlay: onPlay,
        onPause: onPause,
        onNext: onNext,
        onPrevious: onPrevious,
        onSeek: onSeek,
      );
    } else if (Platform.isWindows) {
      await windows.MediaControlPlatform.init(
        onPlay: onPlay,
        onPause: onPause,
        onNext: onNext,
        onPrevious: onPrevious,
        onSeek: onSeek,
      );
    } else if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      await mobile.MediaControlPlatform.init(
        onPlay: onPlay,
        onPause: onPause,
        onNext: onNext,
        onPrevious: onPrevious,
        onSeek: onSeek,
      );
    }
  }

  static Future<void> update(PlayerState state) async {
    if (!_initialized) return;

    final track = state.currentTrack;
    if (track == null) {
      _clear();
      return;
    }

    final isPlaying = state.status == PlayerStatus.playing;

    // Load art when track changes — capture path before await to avoid race
    Uint8List? art;
    if (track.path != _lastArtPath) {
      final pathSnapshot = track.path;
      _lastArtPath = pathSnapshot;
      _lastArtBytes = null;
      try {
        final bytes = await backend.readAlbumArt(path: pathSnapshot);
        // Discard if track changed again while we were awaiting
        if (_lastArtPath == pathSnapshot && bytes != null) {
          _lastArtBytes = Uint8List.fromList(bytes);
        }
      } catch (_) {}
    }
    art = _lastArtBytes;

    if (Platform.isLinux) {
      await linux.MediaControlPlatform.update(
        title: track.displayTitle,
        artist: track.displayArtist,
        album: track.album ?? '',
        isPlaying: isPlaying,
        position: state.position,
        duration: track.duration,
        artBytes: art,
      );
    } else if (Platform.isWindows) {
      await windows.MediaControlPlatform.update(
        title: track.displayTitle,
        artist: track.displayArtist,
        album: track.album ?? '',
        isPlaying: isPlaying,
        position: state.position,
        duration: track.duration,
        artBytes: art,
      );
    } else if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      await mobile.MediaControlPlatform.update(
        title: track.displayTitle,
        artist: track.displayArtist,
        album: track.album ?? '',
        isPlaying: isPlaying,
        position: state.position,
        duration: track.duration,
        artBytes: art,
      );
    }
  }

  static void _clear() {
    if (Platform.isLinux) {
      linux.MediaControlPlatform.clear();
    } else if (Platform.isWindows) {
      windows.MediaControlPlatform.clear();
    } else if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      mobile.MediaControlPlatform.clear();
    }
    _lastArtPath = null;
    _lastArtBytes = null;
  }

  static void dispose() {
    if (Platform.isLinux) {
      linux.MediaControlPlatform.dispose();
    } else if (Platform.isWindows) {
      windows.MediaControlPlatform.dispose();
    } else if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      mobile.MediaControlPlatform.dispose();
    }
    _initialized = false;
  }
}
