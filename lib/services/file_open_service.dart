import 'dart:io' show File, Platform;

import 'package:aqloss/plugins/plugin_io_service.dart';
import 'package:aqloss/services/playlist_io_service.dart';
import 'package:aqloss/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// File open service
typedef _FileOpenCallback =
    Future<void> Function(String path, BuildContext context);

class FileOpenService {
  FileOpenService._();
  static final FileOpenService instance = FileOpenService._();
  static const _channel = MethodChannel('xyz.nokarin.aqloss/file_open');
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  _FileOpenCallback? onPlaylist;

  void init() {
    _channel.setMethodCallHandler(_handle);
    _checkStartupArg();
    Logger.debugFrontend('[file_open] channel ready');
  }

  void _checkStartupArg() {
    if (!Platform.isLinux && !Platform.isWindows) return;
    final args = Platform.executableArguments;
    for (final arg in args) {
      final lower = arg.toLowerCase();
      if (lower.endsWith('.aqp') || lower.endsWith('.aqx')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handle(MethodCall('openFile', arg));
        });
        break;
      }
    }
  }

  Future<void> _handle(MethodCall call) async {
    if (call.method != 'openFile') return;
    final path = call.arguments as String?;
    if (path == null || path.isEmpty) return;

    Logger.debugFrontend('[file_open] received: $path');

    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      Logger.warnPlayerProvider('[file_open] no context - dropping: $path');
      return;
    }

    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'aqp':
        await _handlePlaylist(path, ctx);
      case 'aqx':
        await _handlePlugin(path, ctx);
      default:
        Logger.warnPlayerProvider('[file_open] unknown extension: .$ext');
    }
  }

  // Handlers
  Future<void> _handlePlaylist(String path, BuildContext context) async {
    final cb = onPlaylist;
    if (cb != null) {
      await cb(path, context);
      return;
    }

    // Fallback
    try {
      final result = await PlaylistIOService.importFromPath(path);
      if (!context.mounted) return;
      if (result.success && result.playlist != null) {
        _showToast(context, 'Playlist "${result.playlist!.name}" imported.');
      } else if (result.error != null) {
        _showToast(context, result.error!);
      }
    } catch (e) {
      Logger.errorPlayerProvider('[file_open] playlist import failed: $e');
    }
  }

  Future<void> _handlePlugin(String path, BuildContext context) async {
    try {
      final bytes = await File(path).readAsBytes();
      final result = await PluginIOService.importFromBytes(bytes);
      if (context.mounted && !result.cancelled) {
        _showToast(context, result.userMessage);
      }
    } catch (e) {
      Logger.errorPlayerProvider('[file_open] plugin import failed: $e');
    }
  }

  // Minimal toast fallback
  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
