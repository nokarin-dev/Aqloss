import 'dart:async';
import 'package:aqloss/util/logger.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/services/lastfm_service.dart';
import 'package:aqloss/services/listenbrainz_service.dart';
import 'package:aqloss/util/notices.dart';

class ScrobbleController {
  ScrobbleController._();
  static final _i = ScrobbleController._();
  static ScrobbleController get instance => _i;

  String? _lastFmSessionKey;
  LastFmCredentials? _lastFmCreds;
  String? _listenBrainzToken;

  Track? _currentTrack;
  int? _startedAt;
  bool _scrobbled = false;
  Timer? _scrobbleTimer;
  void Function(String message)? onFailed;

  bool get _lastFmReady =>
      _lastFmSessionKey != null && (_lastFmCreds?.isValid ?? false);

  bool get _listenBrainzReady =>
      _listenBrainzToken != null && _listenBrainzToken!.trim().isNotEmpty;

  bool get _active => _lastFmReady || _listenBrainzReady;

  void configure({
    String? lastFmSessionKey,
    LastFmCredentials? lastFmCreds,
    String? listenBrainzToken,
  }) {
    _lastFmSessionKey = lastFmSessionKey;
    _lastFmCreds = lastFmCreds;
    _listenBrainzToken = listenBrainzToken;
  }

  void onTrackStart(Track track) {
    if (!_active) return;
    _scrobbleTimer?.cancel();
    _currentTrack = track;
    _startedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _scrobbled = false;

    if (_lastFmReady) {
      LastFmService.updateNowPlaying(
        sessionKey: _lastFmSessionKey!,
        creds: _lastFmCreds!,
        artist: track.displayArtist,
        track: track.displayTitle,
        album: track.album,
        durationSecs: track.duration.inSeconds,
      );
    }

    if (_listenBrainzReady) {
      ListenBrainzService.updateNowPlaying(
        token: _listenBrainzToken!,
        artist: track.displayArtist,
        track: track.displayTitle,
        album: track.album,
        durationSecs: track.duration.inSeconds,
      );
    }

    final threshold = (track.duration.inSeconds ~/ 2).clamp(0, 240);
    if (threshold <= 0) return;
    _scrobbleTimer = Timer(Duration(seconds: threshold), _doScrobble);
  }

  void onTrackStop() {
    _scrobbleTimer?.cancel();
    _currentTrack = null;
    _scrobbled = false;
  }

  void onPositionUpdate(Duration position) {
    if (_scrobbled || !_active || _currentTrack == null) return;
    final dur = _currentTrack!.duration.inSeconds;
    if (dur <= 0) return;
    if (position.inSeconds / dur >= 0.5 || position.inSeconds >= 240) {
      _doScrobble();
    }
  }

  Future<void> _doScrobble() async {
    if (_scrobbled || !_active || _currentTrack == null) return;
    _scrobbled = true;
    _scrobbleTimer?.cancel();
    final track = _currentTrack!;
    final ts = _startedAt ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);

    var ok = false;
    if (_lastFmReady) {
      ok = await LastFmService.scrobble(
        sessionKey: _lastFmSessionKey!,
        creds: _lastFmCreds!,
        artist: track.displayArtist,
        track: track.displayTitle,
        album: track.album,
        timestamp: ts,
        durationSecs: track.duration.inSeconds,
      );
    }

    if (_listenBrainzReady) {
      final lbOk = await ListenBrainzService.scrobble(
        token: _listenBrainzToken!,
        artist: track.displayArtist,
        track: track.displayTitle,
        album: track.album,
        listenedAt: ts,
        durationSecs: track.duration.inSeconds,
      );
      ok = ok || lbOk;
    }

    Logger.infoScrobble('"${track.displayTitle}" ok=$ok');
    if (!ok) onFailed?.call(kScrobbleFailedMessage);
  }

  void dispose() {
    _scrobbleTimer?.cancel();
  }
}
