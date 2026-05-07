import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/services/lastfm_service.dart';

class ScrobbleController {
  ScrobbleController._();
  static final _i = ScrobbleController._();
  static ScrobbleController get instance => _i;

  String? _sessionKey;
  LastFmCredentials? _creds;
  Track? _currentTrack;
  int? _startedAt;
  bool _scrobbled = false;
  Timer? _scrobbleTimer;

  void setSession(String? sessionKey, {LastFmCredentials? creds}) {
    _sessionKey = sessionKey;
    _creds = creds;
  }

  void onTrackStart(Track track) {
    if (_sessionKey == null || _creds == null || !_creds!.isValid) return;
    _scrobbleTimer?.cancel();
    _currentTrack = track;
    _startedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _scrobbled = false;

    LastFmService.updateNowPlaying(
      sessionKey: _sessionKey!,
      creds: _creds!,
      artist: track.displayArtist,
      track: track.displayTitle,
      album: track.album,
      durationSecs: track.duration.inSeconds,
    );

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
    if (_scrobbled ||
        _sessionKey == null ||
        _creds == null ||
        _currentTrack == null) {
      return;
    }
    final dur = _currentTrack!.duration.inSeconds;
    if (dur <= 0) return;
    if (position.inSeconds / dur >= 0.5 || position.inSeconds >= 240) {
      _doScrobble();
    }
  }

  Future<void> _doScrobble() async {
    if (_scrobbled ||
        _sessionKey == null ||
        _creds == null ||
        _currentTrack == null) {
      return;
    }
    _scrobbled = true;
    _scrobbleTimer?.cancel();
    final track = _currentTrack!;
    final ts = _startedAt ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final ok = await LastFmService.scrobble(
      sessionKey: _sessionKey!,
      creds: _creds!,
      artist: track.displayArtist,
      track: track.displayTitle,
      album: track.album,
      timestamp: ts,
      durationSecs: track.duration.inSeconds,
    );
    debugPrint('[ScrobbleController] "${track.displayTitle}" ok=$ok');
  }

  void dispose() {
    _scrobbleTimer?.cancel();
  }
}
