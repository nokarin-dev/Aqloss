import 'dart:io';
import 'dart:typed_data';
import 'package:smtc_windows/smtc_windows.dart';

const _artPath = r'C:\Windows\Temp\aqloss_cover.jpg';

class MediaControlPlatform {
  static SMTCWindows? _smtc;

  static Future<void> initialize() async {
    try {
      await SMTCWindows.initialize();
    } catch (_) {}
  }

  static Future<void> init({
    required void Function() onPlay,
    required void Function() onPause,
    required void Function() onNext,
    required void Function() onPrevious,
    required void Function(Duration) onSeek,
  }) async {
    try {
      _smtc = SMTCWindows(
        metadata: const MusicMetadata(
          title: '',
          artist: '',
          albumArtist: '',
          album: '',
        ),
        timeline: const PlaybackTimeline(
          startTimeMs: 0,
          endTimeMs: 0,
          positionMs: 0,
          minSeekTimeMs: 0,
          maxSeekTimeMs: 0,
        ),
        config: const SMTCConfig(
          playEnabled: true,
          pauseEnabled: true,
          stopEnabled: false,
          nextEnabled: true,
          prevEnabled: true,
          fastForwardEnabled: false,
          rewindEnabled: false,
        ),
      );

      _smtc!.buttonPressStream.listen((btn) {
        switch (btn) {
          case PressedButton.play:
            onPlay();
          case PressedButton.pause:
            onPause();
          case PressedButton.next:
            onNext();
          case PressedButton.previous:
            onPrevious();
          default:
            break;
        }
      });
    } catch (_) {
      _smtc = null;
    }
  }

  static Future<void> update({
    required String title,
    required String artist,
    required String album,
    required bool isPlaying,
    Uint8List? artBytes,
    Duration? position,
    Duration? duration,
  }) async {
    final s = _smtc;
    if (s == null) return;
    try {
      // Write art to temp file
      String? artUri;
      if (artBytes != null) {
        await File(_artPath).writeAsBytes(artBytes);
        artUri = Uri.file(_artPath).toString();
      }

      await s.updateMetadata(
        MusicMetadata(
          title: title,
          artist: artist,
          albumArtist: artist,
          album: album,
          thumbnail: artUri,
        ),
      );

      // Update seek bar timeline
      final durMs = duration?.inMilliseconds ?? 0;
      final posMs = position?.inMilliseconds ?? 0;
      await s.updateTimeline(
        PlaybackTimeline(
          startTimeMs: 0,
          endTimeMs: durMs,
          positionMs: posMs,
          minSeekTimeMs: 0,
          maxSeekTimeMs: durMs,
        ),
      );

      await s.setPlaybackStatus(
        isPlaying ? PlaybackStatus.playing : PlaybackStatus.paused,
      );
    } catch (_) {}
  }

  static void clear() {
    try {
      _smtc?.setPlaybackStatus(PlaybackStatus.stopped);
    } catch (_) {}
  }

  static void dispose() {
    _smtc?.dispose();
    _smtc = null;
  }
}
