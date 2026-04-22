import 'dart:async';
import 'dart:convert';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/providers/player_provider.dart';
import 'package:http/http.dart' as http;

class DiscordService {
  static bool _enabled = true;
  static Timer? _updateTimer;

  static final Map<String, String> _artCache = {};

  static bool get enabled => _enabled;
  static set enabled(bool v) {
    _enabled = v;
    if (!v) clear();
  }

  // Public API
  static void update(PlayerState state) {
    if (!_enabled) return;

    final track = state.currentTrack;
    if (track == null) {
      clear();
      return;
    }

    final title = track.title ?? track.path.split(RegExp(r'[/\\]')).last;
    final artist = track.artist ?? 'Unknown Artist';
    final album = track.album ?? '';

    switch (state.status) {
      case PlayerStatus.playing:
        _updateTimer?.cancel();
        _updateTimer = Timer(const Duration(milliseconds: 600), () async {
          final artUrl = await _resolveArtUrl(artist, album);
          backend
              .discordUpdatePlaying(
                title: title,
                artist: artist,
                album: album,
                albumArtUrl: artUrl.isEmpty ? "" : artUrl,
                positionSecs: state.position.inMilliseconds / 1000.0,
                durationSecs: track.duration.inMilliseconds / 1000.0,
              )
              .catchError((_) {});
        });
        break;

      case PlayerStatus.paused:
        _updateTimer?.cancel();
        Future(() async {
          final artUrl = await _resolveArtUrl(artist, album);
          backend
              .discordUpdatePaused(
                title: title,
                artist: artist,
                album: album,
                albumArtUrl: artUrl.isEmpty ? "" : artUrl,
              )
              .catchError((_) {});
        });
        break;

      case PlayerStatus.idle:
      case PlayerStatus.loading:
      case PlayerStatus.error:
        clear();
        break;
    }
  }

  static void clear() {
    _updateTimer?.cancel();
    backend.discordClear().catchError((_) {});
  }

  static void dispose() {
    _updateTimer?.cancel();
  }

  // Cover art resolution
  static Future<String> _resolveArtUrl(String artist, String album) async {
    final cacheKey = '${artist.toLowerCase()}||${album.toLowerCase()}';
    if (_artCache.containsKey(cacheKey)) {
      return _artCache[cacheKey]!;
    }

    // Try iTunes Search first
    final itunesUrl = await _fetchItunesArtUrl(artist, album);
    if (itunesUrl.isNotEmpty) {
      _artCache[cacheKey] = itunesUrl;
      return itunesUrl;
    }

    // Fallback: MusicBrainz Cover Art Archive
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

      // Find best match
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

      final hqUrl = artworkUrl
          .replaceAll('100x100bb.jpg', '600x600bb.jpg')
          .replaceAll('100x100bb.png', '600x600bb.png');

      return hqUrl;
    } catch (e) {
      return '';
    }
  }

  // MusicBrainz Cover Art Archive URL.
  static String _buildMbUrl(String artist, String album) {
    if (album.isEmpty) return '';

    String clean(String s) => s
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), '+');

    final a = clean(artist);
    final al = clean(album);
    if (al.isEmpty) return '';

    return 'https://coverartarchive.org/release-group/$a+$al/front-250';
  }
}
