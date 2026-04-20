import 'dart:async';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/providers/player_provider.dart';

class DiscordService {
  static bool _enabled = true;
  static Timer? _updateTimer;

  static bool get enabled => _enabled;
  static set enabled(bool v) {
    _enabled = v;
    if (!v) clear();
  }

  static void update(PlayerState state) {
    if (!_enabled) return;

    final track = state.currentTrack;
    if (track == null) {
      clear();
      return;
    }

    final title  = track.title  ?? track.path.split(RegExp(r'[/\\]')).last;
    final artist = track.artist ?? 'Unknown Artist';
    final album  = track.album  ?? '';

    switch (state.status) {
      case PlayerStatus.playing:
        _updateTimer?.cancel();
        _updateTimer = Timer(const Duration(milliseconds: 500), () {
          backend.discordUpdatePlaying(
            title: title,
            artist: artist,
            album: album,
            positionSecs: state.position.inMilliseconds / 1000.0,
            durationSecs: (track.duration.inMilliseconds) / 1000.0,
          ).catchError((_) {});
        });

      case PlayerStatus.paused:
        _updateTimer?.cancel();
        backend.discordUpdatePaused(
          title: title,
          artist: artist,
        ).catchError((_) {});

      case PlayerStatus.idle:
      case PlayerStatus.loading:
      case PlayerStatus.error:
        clear();
    }
  }

  static void clear() {
    _updateTimer?.cancel();
    backend.discordClear().catchError((_) {});
  }

  static void dispose() {
    _updateTimer?.cancel();
  }
}