import 'dart:convert';
import 'package:aqloss/app_version.dart';
import 'package:aqloss/util/logger.dart';
import 'package:http/http.dart' as http;

const _kApiRoot = 'https://api.listenbrainz.org/1';

class ListenBrainzService {
  static Future<String?> validateToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return null;
    try {
      final res = await http
          .get(
            Uri.parse('$_kApiRoot/validate-token'),
            headers: _authHeaders(trimmed),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        Logger.errorListenBrainz('validate: HTTP ${res.statusCode}');
        return null;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final user = body['user_name'] as String?;
      if (user == null || user.isEmpty) return null;
      return user;
    } catch (e) {
      Logger.errorListenBrainz('validate exception: $e');
      return null;
    }
  }

  static Future<void> updateNowPlaying({
    required String token,
    required String artist,
    required String track,
    String? album,
    int? durationSecs,
  }) async {
    final payload = [
      {
        'track_metadata': _trackMetadata(
          artist: artist,
          track: track,
          album: album,
          durationSecs: durationSecs,
        ),
      },
    ];
    await _submit(token: token, listenType: 'playing_now', payload: payload);
  }

  static Future<bool> scrobble({
    required String token,
    required String artist,
    required String track,
    String? album,
    required int listenedAt,
    int? durationSecs,
  }) async {
    final payload = [
      {
        'listened_at': listenedAt,
        'track_metadata': _trackMetadata(
          artist: artist,
          track: track,
          album: album,
          durationSecs: durationSecs,
        ),
      },
    ];
    return _submit(token: token, listenType: 'single', payload: payload);
  }

  static Map<String, dynamic> _trackMetadata({
    required String artist,
    required String track,
    String? album,
    int? durationSecs,
  }) {
    return {
      'artist_name': artist,
      'track_name': track,
      if (album != null && album.isNotEmpty) 'release_name': album,
      'additional_info': {
        'submission_client': 'Aqloss',
        'media_player': 'Aqloss',
        'duration': ?durationSecs,
      },
    };
  }

  static Future<bool> _submit({
    required String token,
    required String listenType,
    required List<Map<String, dynamic>> payload,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_kApiRoot/submit-listens'),
            headers: {
              ..._authHeaders(token),
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'listen_type': listenType, 'payload': payload}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode >= 200 && res.statusCode < 300) return true;
      Logger.errorListenBrainz('submit $listenType: HTTP ${res.statusCode}');
      return false;
    } catch (e) {
      Logger.errorListenBrainz('submit $listenType exception: $e');
      return false;
    }
  }

  static Map<String, String> _authHeaders(String token) => {
    'Authorization': 'Token ${token.trim()}',
    'User-Agent':
        'Aqloss/$kAppVersion ( https://github.com/nokarin-dev/Aqloss )',
  };

  static Future<List<({String artist, String title})>> fetchLovedTracks({
    required String token,
    required String user,
  }) async {
    final out = <({String artist, String title})>[];
    var offset = 0;
    const count = 100;
    while (offset < 5000) {
      try {
        final uri =
            Uri.parse(
              '$_kApiRoot/feedback/user/${Uri.encodeComponent(user)}/get-feedback',
            ).replace(
              queryParameters: {
                'score': '1',
                'metadata': 'true',
                'count': '$count',
                'offset': '$offset',
              },
            );
        final res = await http
            .get(uri, headers: _authHeaders(token))
            .timeout(const Duration(seconds: 20));
        if (res.statusCode != 200) break;
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = body['feedback'] as List<dynamic>? ?? const [];
        if (list.isEmpty) break;
        for (final item in list) {
          if (item is! Map) continue;
          final meta = item['track_metadata'] as Map<String, dynamic>?;
          final artist = '${meta?['artist_name'] ?? ''}'.trim();
          final title = '${meta?['track_name'] ?? ''}'.trim();
          if (artist.isEmpty || title.isEmpty) continue;
          out.add((artist: artist, title: title));
        }
        offset += list.length;
        final total = (body['total_count'] as num?)?.toInt() ?? out.length;
        if (offset >= total || list.length < count) break;
      } catch (e) {
        Logger.errorListenBrainz('get-feedback: $e');
        break;
      }
    }
    return out;
  }

  static Future<void> setLoved({
    required String token,
    required String artist,
    required String track,
    required bool loved,
  }) async {
    try {
      final lookup = Uri.parse('$_kApiRoot/metadata/lookup/').replace(
        queryParameters: {'artist_name': artist, 'recording_name': track},
      );
      final found = await http
          .get(lookup, headers: _authHeaders(token))
          .timeout(const Duration(seconds: 12));
      if (found.statusCode != 200) return;
      final body = jsonDecode(found.body) as Map<String, dynamic>;
      final mbid = '${body['recording_mbid'] ?? ''}'.trim();
      if (mbid.isEmpty) return;
      await http
          .post(
            Uri.parse('$_kApiRoot/feedback/recording-feedback'),
            headers: {
              ..._authHeaders(token),
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'recording_mbid': mbid, 'score': loved ? 1 : 0}),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      Logger.debugListenBrainz('setLoved: $e');
    }
  }
}
