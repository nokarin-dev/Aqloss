import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const _channel = MethodChannel('xyz.nokarin.aqloss/ios_folders');

List<String> withIosMusicFolder(List<String> saved, String documentsPath) {
  if (saved.contains(documentsPath)) return saved;
  return [documentsPath, ...saved];
}

class IosFolderAccess {
  static Future<String> documentsPath() async {
    return (await getApplicationDocumentsDirectory()).path;
  }

  static Future<List<String>> ensureMusicFolder(List<String> saved) async {
    if (!Platform.isIOS) return saved;
    return withIosMusicFolder(saved, await documentsPath());
  }

  static Future<bool> isDocumentsFolder(String path) async {
    if (!Platform.isIOS) return false;
    return path == await documentsPath();
  }

  static Future<String?> pickFolder() async {
    if (!Platform.isIOS) return null;
    final path = await _channel.invokeMethod<String>('pickFolder');
    if (path == null || path.isEmpty) return null;
    return path;
  }

  static Future<void> startAll(List<String> folders) async {
    if (!Platform.isIOS) return;
    for (final path in folders) {
      await _channel.invokeMethod<bool>('startAccess', path);
    }
  }

  static Future<void> stop(String path) async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>('stopAccess', path);
  }

  static Future<void> shareFiles(List<String> paths) async {
    if (!Platform.isIOS || paths.isEmpty) return;
    await _channel.invokeMethod<void>('shareFiles', paths);
  }
}
