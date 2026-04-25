import 'dart:async';
import 'dart:convert';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/providers/player_provider.dart';
import 'package:http/http.dart' as http;

class DiscordService {
  static bool _enabled = true;
  static Timer? _refreshTimer;
  static final Map<String, String> _artCache = {};
  static String _lastFingerprint = '';
  static bool get enabled => _enabled;
  static set enabled(bool v) {
    _enabled = v;
    if (!v) clear();
  }

  // Public API
  static void update(PlayerState state, {double? positionSecs}) {
    if (!_enabled) return;

    final track = state.currentTrack;
    if (track == null) {
      clear();
      return;
    }

    final title = track.title ?? track.path.split(RegExp(r'[/\\]')).last;
    final artist = track.artist ?? 'Unknown Artist';
    final album = track.album ?? '';
    final durSec = track.duration.inMilliseconds / 1000.0;

    switch (state.status) {
      case PlayerStatus.playing:
        final posSec = positionSecs ?? state.position.inMilliseconds / 1000.0;

        final fp = 'playing|$title|$artist|$durSec';
        final sameTrackSameStatus = fp == _lastFingerprint;

        if (sameTrackSameStatus) return;
        _lastFingerprint = fp;

        _cancelRefresh();
        _sendPlaying(title, artist, album, posSec, durSec);

        _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
          if (!_enabled) return;
          backend
              .getPosition()
              .then((pos) {
                _sendPlaying(
                  title,
                  artist,
                  album,
                  pos.positionSecs,
                  pos.durationSecs > 0 ? pos.durationSecs : durSec,
                );
              })
              .catchError((_) {});
        });
        break;

      case PlayerStatus.paused:
        _cancelRefresh();
        _lastFingerprint = 'paused|$title|$artist';
        _sendPaused(title, artist, album);
        break;

      case PlayerStatus.idle:
      case PlayerStatus.loading:
      case PlayerStatus.error:
        clear();
        break;
    }
  }

  static void updateAfterSeek(PlayerState state, double positionSecs) {
    _lastFingerprint = '';
    update(state, positionSecs: positionSecs);
  }

  static void clear() {
    _cancelRefresh();
    _lastFingerprint = '';
    backend.discordClear().catchError((_) {});
  }

  static void dispose() {
    _cancelRefresh();
  }

  // Internal helpers
  static void _cancelRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  static void _sendPlaying(
    String title,
    String artist,
    String album,
    double positionSecs,
    double durationSecs,
  ) {
    _resolveArtUrl(artist, album).then((artUrl) {
      backend
          .discordUpdatePlaying(
            title: title,
            artist: artist,
            album: album,
            albumArtUrl: artUrl,
            positionSecs: positionSecs,
            durationSecs: durationSecs,
          )
          .catchError((_) {});
    });
  }

  static void _sendPaused(String title, String artist, String album) {
    _resolveArtUrl(artist, album).then((artUrl) {
      backend
          .discordUpdatePaused(
            title: title,
            artist: artist,
            album: album,
            albumArtUrl: artUrl,
          )
          .catchError((_) {});
    });
  }

  // Cover art resolution
  static Future<String> _resolveArtUrl(String artist, String album) async {
    final cacheKey = '${artist.toLowerCase()}||${album.toLowerCase()}';
    if (_artCache.containsKey(cacheKey)) return _artCache[cacheKey]!;

    final itunesUrl = await _fetchItunesArtUrl(artist, album);

    if (itunesUrl.isNotEmpty) {
      _artCache[cacheKey] = itunesUrl;
      return itunesUrl;
    }

    final mbUrl = _buildMbUrl(artist, album);
    _artCache[cacheKey] = mbUrl;
    return mbUrl;
  }

  static Future<String> _fetchItunesArtUrl(String artist, String album) async {
    try {
      final query = Uri.encodeQueryComponent(
        [artist, album].where((s) => s.isNotEmpty).join(' '),
      );

      final uri = Uri.parse(
        'https://itunes.apple.com/search?term=$query&media=music&entity=album&limit=5',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return '';

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final results = json['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return '';

      Map<String, dynamic>? best;
      final albumLower = album.toLowerCase();
      final artistLower = artist.toLowerCase();

      for (final r in results.cast<Map<String, dynamic>>()) {
        final rAlbum = (r['collectionName'] as String? ?? '').toLowerCase();
        final rArtist = (r['artistName'] as String? ?? '').toLowerCase();

        if (rAlbum.contains(albumLower) || rArtist.contains(artistLower)) {
          best = r;
          break;
        }
      }
      best ??= results.first as Map<String, dynamic>;

      final artworkUrl = best['artworkUrl100'] as String?;
      if (artworkUrl == null || artworkUrl.isEmpty) return '';

      return artworkUrl
          .replaceAll('100x100bb.jpg', '600x600bb.jpg')
          .replaceAll('100x100bb.png', '600x600bb.png');
    } catch (_) {
      return '';
    }
  }

  static String _buildMbUrl(String artist, String album) {
    if (album.isEmpty) return '';
    String clean(String s) => s
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), '+');
    final al = clean(album);
    if (al.isEmpty) return '';
    return 'https://coverartarchive.org/release-group/${clean(artist)}+$al/front-250';
  }
}
