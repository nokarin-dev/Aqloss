import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaControlPlatform {
  static const _channel = MethodChannel('xyz.nokarin.aqloss/media_controls');
  static bool _listening = false;
  static bool _nativeReady = false;

  static Future<void> init({
    required void Function() onPlay,
    required void Function() onPause,
    required void Function() onNext,
    required void Function() onPrevious,
    required void Function(Duration) onSeek,
  }) async {
    if (!_listening) {
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
    }

    if (Platform.isAndroid) {
      await Permission.notification.request();
    }

    await _ensureNative();
  }

  static Future<void> ensureSession() async {
    await _ensureNative();
    try {
      await _channel.invokeMethod('ensureSession');
    } on MissingPluginException {
      _nativeReady = false;
    } catch (_) {}
  }

  static Future<void> _ensureNative() async {
    if (_nativeReady) return;
    try {
      await _channel.invokeMethod('init');
      _nativeReady = true;
    } on MissingPluginException {
      _nativeReady = false;
    } catch (_) {
      _nativeReady = false;
    }
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
    await _ensureNative();
    try {
      await _channel.invokeMethod('update', {
        'title': title,
        'artist': artist,
        'album': album,
        'isPlaying': isPlaying,
        'positionMs': (position?.inMilliseconds ?? 0).toDouble(),
        'durationMs': (duration?.inMilliseconds ?? 0).toDouble(),
        'artBytes': artBytes,
      });
    } on MissingPluginException {
      _nativeReady = false;
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
    _nativeReady = false;
  }
}
