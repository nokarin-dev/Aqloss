import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/util/logger.dart';
import 'package:flutter/material.dart';

class PluginTheme {
  PluginTheme._();

  static final appBarColor = ValueNotifier<Color?>(null);

  static void syncFromEngine() {
    try {
      final next = parsePluginHexColor(backend.pluginAppBarColor());
      if (appBarColor.value != next) {
        appBarColor.value = next;
      }
    } catch (e) {
      Logger.errorPlayerProvider('[plugins] theme sync: $e');
    }
  }

  static void clear() {
    if (appBarColor.value != null) {
      appBarColor.value = null;
    }
  }
}

Color? parsePluginHexColor(String? raw) {
  if (raw == null) return null;
  var hex = raw.trim();
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 3) {
    hex = hex.split('').map((c) => '$c$c').join();
  }
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return null;
  return Color(value);
}
