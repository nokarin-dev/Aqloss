import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaControlPlatform {
  static const _channel = MethodChannel('xyz.nokarin.aqloss/media_controls');
  static bool _listening = false;

  static Future<void> init({
    required void Function() onPlay,
    required void Function() onPause,
    required void Function() onNext,
    required void Function() onPrevious,
    required void Function(Duration) onSeek,
  }) async {
    if (_listening) return;
    _listening = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPlay':
          onPlay();
          break;
        case 'onPause':
          onPause();
          break;
        case 'onNext':
          onNext();
          break;
        case 'onPrevious':
          onPrevious();
          break;
        case 'onSeek':
          final ms = call.arguments as int?;
          if (ms != null) onSeek(Duration(milliseconds: ms));
          break;
        case 'onStop':
          onPause();
          break;
      }
    });

    if (Platform.isAndroid) {
      await Permission.notification.request();
    }

    try {
      await _channel.invokeMethod('init');
    } on MissingPluginException {
      // iOS/macOS register later in some embeds
    } catch (_) {}
  }

  static Future<void> update({
    required String title,
    required String artist,
    required String album,
    required bool isPlaying,
    Duration? position,
    Duration? duration,
    Uint8List? artBytes,
  }) async {
    try {
      await _channel.invokeMethod('update', {
        'title': title,
        'artist': artist,
        'album': album,
        'isPlaying': isPlaying,
        'positionMs': position?.inMilliseconds ?? 0,
        'durationMs': duration?.inMilliseconds ?? 0,
        'artBytes': artBytes,
      });
    } on MissingPluginException {
      // channel not registered yet
    } catch (_) {}
  }

  static void clear() {
    try {
      _channel.invokeMethod('clear');
    } catch (_) {}
  }

  static void dispose() {
    try {
      _channel.invokeMethod('clear');
    } catch (_) {}
    _listening = false;
  }
}
