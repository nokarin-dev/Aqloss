import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

class M3WavePrograms {
  static ui.FragmentProgram? track;
  static ui.FragmentProgram? ring;
  static Future<void>? _loading;

  static Future<void> ensure() => _loading ??= _load();

  static Future<void> _load() async {
    try {
      track = await ui.FragmentProgram.fromAsset('shaders/m3_wave_track.frag');
      ring = await ui.FragmentProgram.fromAsset('shaders/m3_wave_ring.frag');
    } catch (e, st) {
      debugPrint('M3 wave shader failed: $e\n$st');
    }
  }
}

void m3SetPremul(ui.FragmentShader shader, int i, Color c) {
  shader
    ..setFloat(i, c.r * c.a)
    ..setFloat(i + 1, c.g * c.a)
    ..setFloat(i + 2, c.b * c.a)
    ..setFloat(i + 3, c.a);
}

class M3ShaderSeekPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double value;
  final double phase;
  final double amp;
  final double wavelength;
  final double trackHeight;
  final double handleHeight;
  final double handleWidth;
  final double handleGap;
  final Color active;
  final Color inactive;
  final double dpr;

  const M3ShaderSeekPainter({
    required this.shader,
    required this.value,
    required this.phase,
    required this.amp,
    required this.wavelength,
    required this.trackHeight,
    required this.handleHeight,
    required this.handleWidth,
    required this.handleGap,
    required this.active,
    required this.inactive,
    required this.dpr,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height);
    m3SetPremul(shader, 2, active);
    m3SetPremul(shader, 6, inactive);
    shader
      ..setFloat(10, value.clamp(0.0, 1.0))
      ..setFloat(11, phase)
      ..setFloat(12, amp)
      ..setFloat(13, wavelength)
      ..setFloat(14, trackHeight)
      ..setFloat(15, handleWidth)
      ..setFloat(16, handleHeight)
      ..setFloat(17, handleGap)
      ..setFloat(18, dpr)
      ..setFloat(19, 0)
      ..setFloat(20, 0)
      ..setFloat(21, 0);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(M3ShaderSeekPainter old) =>
      old.value != value ||
      old.phase != phase ||
      old.amp != amp ||
      old.active != active ||
      old.inactive != inactive ||
      old.dpr != dpr;
}

class M3ShaderRingPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double progress;
  final double phase;
  final double amp;
  final double wavelength;
  final double strokeWidth;
  final double trackStrokeWidth;
  final bool loading;
  final Color active;
  final Color track;
  final double dpr;

  const M3ShaderRingPainter({
    required this.shader,
    required this.progress,
    required this.phase,
    required this.amp,
    required this.wavelength,
    required this.strokeWidth,
    required this.trackStrokeWidth,
    required this.loading,
    required this.active,
    required this.track,
    required this.dpr,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height);
    m3SetPremul(shader, 2, active);
    m3SetPremul(shader, 6, track);
    shader
      ..setFloat(10, progress.clamp(0.0, 1.0))
      ..setFloat(11, phase)
      ..setFloat(12, amp)
      ..setFloat(13, wavelength)
      ..setFloat(14, strokeWidth)
      ..setFloat(15, trackStrokeWidth)
      ..setFloat(16, loading ? 1.0 : 0.0)
      ..setFloat(17, dpr);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(M3ShaderRingPainter old) =>
      old.progress != progress ||
      old.phase != phase ||
      old.amp != amp ||
      old.loading != loading ||
      old.active != active ||
      old.track != track ||
      old.dpr != dpr;
}
