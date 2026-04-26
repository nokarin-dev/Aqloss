import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/providers/player_provider.dart';
import 'package:http/http.dart' as http;

class DiscordService {
  static bool _enabled = true;
  static Timer? _refreshTimer;
  static final Map<String, String> _artCache = {};
  static final Map<String, String> _onlineArtCache = {};
  static String _lastFingerprint = '';
  static bool get enabled => _enabled;
  static set enabled(bool v) {
    _enabled = v;
    if (!v) clear();
  }

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
        final isNewTrackOrStatus = fp != _lastFingerprint;
        if (!isNewTrackOrStatus && positionSecs == null) return;
        _lastFingerprint = fp;

        _cancelRefresh();
        _sendPlayingWithArt(track.path, title, artist, album, posSec, durSec);

        _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
          if (!_enabled) return;
          backend
              .getPosition()
              .then((pos) {
                final artUrl = _artCache[track.path] ?? '';
                _sendPlaying(
                  title,
                  artist,
                  album,
                  artUrl,
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
        _sendPausedWithArt(track.path, title, artist, album);
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

  static void _cancelRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  static Future<String> _resolveArtUrl(
    String filePath,
    String artist,
    String album,
  ) async {
    // Check cache
    if (_artCache.containsKey(filePath)) return _artCache[filePath]!;

    // Try to upload embedded art
    try {
      final artBytes = await backend.readAlbumArt(path: filePath);
      if (artBytes != null && artBytes.isNotEmpty) {
        final uploaded = await _uploadImageBytes(Uint8List.fromList(artBytes));
        if (uploaded.isNotEmpty) {
          _artCache[filePath] = uploaded;
          return uploaded;
        }
      }
    } catch (_) {}

    // Fallback to online search
    final cacheKey = '${artist.toLowerCase()}||${album.toLowerCase()}';
    if (_onlineArtCache.containsKey(cacheKey)) {
      final url = _onlineArtCache[cacheKey]!;
      _artCache[filePath] = url;
      return url;
    }

    final onlineUrl = await _fetchOnlineArtUrl(artist, album);
    _onlineArtCache[cacheKey] = onlineUrl;
    _artCache[filePath] = onlineUrl;
    return onlineUrl;
  }

  // Upload image to catbox
  static Future<String> _uploadImageBytes(Uint8List bytes) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://catbox.moe/user/api.php'),
      );
      request.fields['reqtype'] = 'fileupload';
      request.files.add(
        http.MultipartFile.fromBytes(
          'fileToUpload',
          bytes,
          filename: 'cover.jpg',
        ),
      );
      final response = await request.send().timeout(const Duration(seconds: 8));
      final body = await response.stream.bytesToString();
      if (response.statusCode == 200 && body.startsWith('https://')) {
        return body.trim();
      }
    } catch (_) {}

    // Fallback to 0x0.st
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://0x0.st'),
      );
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: 'cover.jpg'),
      );
      final response = await request.send().timeout(const Duration(seconds: 8));
      final body = await response.stream.bytesToString();
      if (response.statusCode == 200 && body.trim().startsWith('https://')) {
        return body.trim();
      }
    } catch (_) {}

    return '';
  }

  static Future<String> _fetchOnlineArtUrl(String artist, String album) async {
    final itunesUrl = await _fetchItunesArtUrl(artist, album);
    if (itunesUrl.isNotEmpty) return itunesUrl;
    return _buildMbUrl(artist, album);
  }

  static void _sendPlayingWithArt(
    String filePath,
    String title,
    String artist,
    String album,
    double posSec,
    double durSec,
  ) {
    _resolveArtUrl(filePath, artist, album).then((artUrl) {
      _sendPlaying(title, artist, album, artUrl, posSec, durSec);
    });
  }

  static void _sendPausedWithArt(
    String filePath,
    String title,
    String artist,
    String album,
  ) {
    _resolveArtUrl(filePath, artist, album).then((artUrl) {
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

  static void _sendPlaying(
    String title,
    String artist,
    String album,
    String artUrl,
    double positionSecs,
    double durationSecs,
  ) {
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
