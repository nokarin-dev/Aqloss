import 'dart:convert';

import 'package:aqloss/models/track.dart';
import 'package:aqloss/plugins/plugin_api.dart';
import 'package:aqloss/util/logger.dart';
import 'package:http/http.dart' as http;

class WebhookDispatcher {
  WebhookDispatcher._();
  static final WebhookDispatcher instance = WebhookDispatcher._();

  Future<void> dispatch(
    PluginManifest manifest,
    WebhookEvent event,
    Map<String, dynamic> payload,
  ) async {
    if (!manifest.isWebhook) return;
    final url = manifest.webhookUrl;
    if (url == null || url.isEmpty) return;

    final subscribed = manifest.webhookEvents;
    if (subscribed != null && !subscribed.contains(event)) return;

    final body = jsonEncode({
      'event': event.name,
      'plugin_id': manifest.id,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      ...payload,
    });

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'User-Agent': 'Aqloss/${manifest.minAqlossVersion}',
        ...?manifest.webhookHeaders,
      };

      final response = await http
          .post(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 400) {
        Logger.warnPlayerProvider(
          '[plugins/${manifest.id}] webhook ${event.name} → ${response.statusCode}',
        );
      }
    } catch (e) {
      Logger.warnPlayerProvider(
        '[plugins/${manifest.id}] webhook ${event.name} failed: $e',
      );
    }
  }

  // Payload builders
  static Map<String, dynamic> trackPayload(Track track) => {
    'track': {
      'title': track.displayTitle,
      'artist': track.displayArtist,
      'album': track.album,
      'duration_secs': track.durationSecs,
      'path': track.path,
      if (track.trackNumber != null) 'track_number': track.trackNumber,
    },
  };

  static Map<String, dynamic> playPausePayload(
    bool isPlaying,
    Duration position,
  ) => {
    'is_playing': isPlaying,
    'position_secs': position.inMilliseconds / 1000.0,
  };

  static Map<String, dynamic> positionPayload(
    Duration position,
    Duration duration,
  ) => {
    'position_secs': position.inMilliseconds / 1000.0,
    'duration_secs': duration.inMilliseconds / 1000.0,
    'progress': duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0,
  };

  static Map<String, dynamic> lovedPayload(Track track, bool loved) => {
    ...trackPayload(track),
    'loved': loved,
  };
}
