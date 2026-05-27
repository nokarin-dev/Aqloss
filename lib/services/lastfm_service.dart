import 'dart:convert';
import 'package:aqloss/util/logger.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

const _kApiUrl = 'https://ws.audioscrobbler.com/2.0/';

const _builtInApiKey = String.fromEnvironment(
  'LASTFM_API_KEY',
  defaultValue: '',
);
const _builtInApiSecret = String.fromEnvironment(
  'LASTFM_API_SECRET',
  defaultValue: '',
);

class LastFmCredentials {
  final String apiKey;
  final String apiSecret;
  const LastFmCredentials({required this.apiKey, required this.apiSecret});
  bool get isValid => apiKey.isNotEmpty && apiSecret.isNotEmpty;
}

class LastFmService {
  static LastFmCredentials resolve({
    String? userApiKey,
    String? userApiSecret,
  }) {
    final key = (userApiKey ?? '').isNotEmpty ? userApiKey! : _builtInApiKey;
    final secret = (userApiSecret ?? '').isNotEmpty
        ? userApiSecret!
        : _builtInApiSecret;
    return LastFmCredentials(apiKey: key, apiSecret: secret);
  }

  static Future<String?> authenticate({
    required String username,
    required String password,
    required LastFmCredentials creds,
  }) async {
    if (!creds.isValid) {
      Logger.errorLastfm(
        '[LastFm] No API key configured. User must provide one in settings.',
      );
      return null;
    }
    final params = {
      'method': 'auth.getMobileSession',
      'username': username,
      'password': password,
      'api_key': creds.apiKey,
    };
    params['api_sig'] = _sign(params, creds.apiSecret);
    params['format'] = 'json';
    try {
      final res = await http
          .post(Uri.parse(_kApiUrl), body: params)
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body.containsKey('error')) {
        Logger.errorLastfm('auth error ${body['error']}: ${body['message']}');
        return null;
      }
      return body['session']?['key'] as String?;
    } catch (e) {
      Logger.errorLastfm('auth exception: $e');
      return null;
    }
  }

  static Future<void> updateNowPlaying({
    required String sessionKey,
    required LastFmCredentials creds,
    required String artist,
    required String track,
    String? album,
    int? durationSecs,
  }) async {
    if (!creds.isValid) return;
    final params = {
      'method': 'track.updateNowPlaying',
      'artist': artist,
      'track': track,
      'album': ?album,
      if (durationSecs != null) 'duration': durationSecs.toString(),
      'api_key': creds.apiKey,
      'sk': sessionKey,
    };
    params['api_sig'] = _sign(params, creds.apiSecret);
    params['format'] = 'json';
    try {
      await http
          .post(Uri.parse(_kApiUrl), body: params)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      Logger.debugLastfm('nowPlaying: $e');
    }
  }

  static Future<bool> scrobble({
    required String sessionKey,
    required LastFmCredentials creds,
    required String artist,
    required String track,
    String? album,
    required int timestamp,
    int? durationSecs,
  }) async {
    if (!creds.isValid) return false;
    final params = {
      'method': 'track.scrobble',
      'artist[0]': artist,
      'track[0]': track,
      'album[0]': ?album,
      'timestamp[0]': timestamp.toString(),
      if (durationSecs != null) 'duration[0]': durationSecs.toString(),
      'api_key': creds.apiKey,
      'sk': sessionKey,
    };
    params['api_sig'] = _sign(params, creds.apiSecret);
    params['format'] = 'json';
    try {
      final res = await http
          .post(Uri.parse(_kApiUrl), body: params)
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body.containsKey('error')) {
        Logger.errorLastfm(
          'scrobble error ${body['error']}: ${body['message']}',
        );
        return false;
      }
      return true;
    } catch (e) {
      Logger.debugLastfm('scrobble: $e');
      return false;
    }
  }

  // Send track.love or track.unlove to Last.fm.
  static Future<bool> setLoved({
    required String sessionKey,
    required LastFmCredentials creds,
    required String artist,
    required String track,
    required bool loved,
  }) async {
    if (!creds.isValid) return false;
    try {
      final params = <String, String>{
        'method': loved ? 'track.love' : 'track.unlove',
        'artist': artist,
        'track': track,
        'sk': sessionKey,
        'api_key': creds.apiKey,
        'format': 'json',
      };
      params['api_sig'] = _sign(params, creds.apiSecret);
      final resp = await http.post(Uri.parse(_kApiUrl), body: params);
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body.containsKey('error')) {
        Logger.debugLastfm(
          '${loved ? 'love' : 'unlove'} error ${body['error']}: ${body['message']}',
        );
        return false;
      }
      return true;
    } catch (e) {
      Logger.debugLastfm('setLoved: $e');
      return false;
    }
  }

  static String _sign(Map<String, String> params, String secret) {
    final keys =
        params.keys.where((k) => k != 'format' && k != 'callback').toList()
          ..sort();
    final sb = StringBuffer();
    for (final k in keys) {
      sb.write(k);
      sb.write(params[k]);
    }
    sb.write(secret);
    return md5.convert(utf8.encode(sb.toString())).toString();
  }
}
