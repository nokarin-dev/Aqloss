import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:flutter_riverpod/legacy.dart';

Future<Uint8List?> _decodeToRgba(Uint8List compressed) async {
  try {
    final codec = await ui.instantiateImageCodec(compressed);
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    frame.image.dispose();
    return byteData?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

Color? _dominantFromRgba(Uint8List rgba) {
  if (rgba.length < 16) return null;

  final bucketWeight = List<double>.filled(12, 0);
  final bucketR = List<double>.filled(12, 0);
  final bucketG = List<double>.filled(12, 0);
  final bucketB = List<double>.filled(12, 0);

  for (int i = 0; i + 3 < rgba.length; i += 32) {
    final r = rgba[i].toDouble();
    final g = rgba[i + 1].toDouble();
    final b = rgba[i + 2].toDouble();

    final brightness = r * 0.299 + g * 0.587 + b * 0.114;
    if (brightness < 20 || brightness > 235) continue;

    final max = r > g ? (r > b ? r : b) : (g > b ? g : b);
    final min = r < g ? (r < b ? r : b) : (g < b ? g : b);
    final chroma = max - min;
    if (chroma < 30) continue;

    double hue;
    if (max == r) {
      hue = ((g - b) / chroma) % 6;
    } else if (max == g) {
      hue = (b - r) / chroma + 2;
    } else {
      hue = (r - g) / chroma + 4;
    }
    if (hue < 0) hue += 6;

    final bucket = (hue * 2).floor().clamp(0, 11);
    final weight = chroma / 255.0;
    bucketWeight[bucket] += weight;
    bucketR[bucket] += r * weight;
    bucketG[bucket] += g * weight;
    bucketB[bucket] += b * weight;
  }

  int best = 0;
  for (int i = 1; i < 12; i++) {
    if (bucketWeight[i] > bucketWeight[best]) best = i;
  }
  if (bucketWeight[best] < 0.5) return null;

  final w = bucketWeight[best];
  final r = (bucketR[best] / w).round().clamp(0, 255);
  final g = (bucketG[best] / w).round().clamp(0, 255);
  final b = (bucketB[best] / w).round().clamp(0, 255);

  final hsv = HSVColor.fromColor(Color.fromARGB(255, r, g, b));
  return hsv
      .withSaturation((hsv.saturation * 1.25).clamp(0.50, 1.0))
      .withValue((hsv.value).clamp(0.55, 1.0))
      .toColor();
}

final accentColorProvider = StateProvider <Color?>((ref) => null);

extension AccentX on WidgetRef {
  Color accentOrSurface(BuildContext context, {double alpha = 1.0}) {
    final accent = watch(accentColorProvider);
    final cs = Theme.of(context).colorScheme;
    if (accent != null) return accent;
    return alpha < 1.0 ? cs.onSurface.withValues(alpha: alpha) : cs.onSurface;
  }
}

Future<Color?> resolveAccentColor({
  required AccentMode mode,
  required int? customArgb,
  required String? trackPath,
}) async {
  switch (mode) {
    case AccentMode.off:
      return null;
    case AccentMode.custom:
      return customArgb != null ? Color(customArgb) : null;
    case AccentMode.auto:
      if (trackPath == null) return null;
      try {
        final compressed = await backend.readAlbumArtThumbnail(path: trackPath);
        if (compressed == null || compressed.isEmpty) return null;
        final rgba = await _decodeToRgba(Uint8List.fromList(compressed));
        if (rgba == null) return null;
        return _dominantFromRgba(rgba);
      } catch (_) {
        return null;
      }
  }
}
