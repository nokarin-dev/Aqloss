import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

/// Sub-pixel step so the sine is not tessellated into visible facets.
double m3WaveStep(BuildContext context, {double wavelength = 64}) {
  final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
  final perPixel = 0.25 / dpr.clamp(1.0, 4.0);
  return math.min(perPixel, wavelength / 64);
}

Paint _fill(Color color) => Paint()
  ..style = PaintingStyle.fill
  ..isAntiAlias = true
  ..color = color;

/// Closed ribbon around a sine, plus round end caps. Fill (not stroke) so
/// Skia/Impeller can anti-alias the edges instead of a thin polyline.
Path m3WaveRibbon({
  required double start,
  required double end,
  required double step,
  required double cy,
  required double amp,
  required double phase,
  required double origin,
  required double k,
  required double halfThickness,
}) {
  final path = Path();
  if (end <= start) return path;

  double yAt(double x) => cy + amp * math.sin(phase + (x - origin) * k);

  final xs = <double>[];
  for (var x = start; x < end; x += step) {
    xs.add(x);
  }
  xs.add(end);

  path.moveTo(xs.first, yAt(xs.first) - halfThickness);
  for (var i = 1; i < xs.length; i++) {
    path.lineTo(xs[i], yAt(xs[i]) - halfThickness);
  }
  for (var i = xs.length - 1; i >= 0; i--) {
    path.lineTo(xs[i], yAt(xs[i]) + halfThickness);
  }
  path.close();

  final y0 = yAt(start);
  final y1 = yAt(end);
  path
    ..addOval(Rect.fromCircle(center: Offset(start, y0), radius: halfThickness))
    ..addOval(Rect.fromCircle(center: Offset(end, y1), radius: halfThickness));
  return path;
}

void m3DrawFlatTrack(
  Canvas canvas, {
  required double start,
  required double end,
  required double cy,
  required double halfThickness,
  required Paint paint,
}) {
  if (end <= start) return;
  canvas.drawRRect(
    RRect.fromLTRBR(
      start,
      cy - halfThickness,
      end,
      cy + halfThickness,
      Radius.circular(halfThickness),
    ),
    paint,
  );
}

class M3SmoothSeekPainter extends CustomPainter {
  final double value;
  final bool wavy;
  final double phase;
  final Color active;
  final Color inactive;
  final double trackHeight;
  final double handleHeight;
  final double handleWidth;
  final double handleGap;
  final double waveAmplitude;
  final double wavelength;
  final double sampleStep;

  const M3SmoothSeekPainter({
    required this.value,
    required this.wavy,
    required this.phase,
    required this.active,
    required this.inactive,
    required this.trackHeight,
    required this.handleHeight,
    required this.handleWidth,
    required this.handleGap,
    required this.waveAmplitude,
    required this.wavelength,
    required this.sampleStep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = value.clamp(0.0, 1.0);
    final cy = size.height / 2;
    final pad = handleWidth / 2 + 1;
    final left = pad;
    final right = size.width - pad;
    final span = right - left;
    if (span <= 0) return;

    final thumbX = left + span * t;
    final amp = wavy ? waveAmplitude : 0.0;
    final k = 2 * math.pi / math.max(wavelength, 1);
    final half = trackHeight / 2;
    final activeEnd = thumbX - handleWidth / 2 - handleGap;
    final inactiveStart = thumbX + handleWidth / 2 + handleGap;
    final activePaint = _fill(active);
    final inactivePaint = _fill(inactive);

    if (inactiveStart < right) {
      m3DrawFlatTrack(
        canvas,
        start: inactiveStart,
        end: right,
        cy: cy,
        halfThickness: half,
        paint: inactivePaint,
      );
    }

    if (activeEnd > left) {
      if (amp > 0.05) {
        canvas.drawPath(
          m3WaveRibbon(
            start: left,
            end: activeEnd,
            step: sampleStep,
            cy: cy,
            amp: amp,
            phase: phase,
            origin: left,
            k: k,
            halfThickness: half,
          ),
          activePaint,
        );
      } else {
        m3DrawFlatTrack(
          canvas,
          start: left,
          end: activeEnd,
          cy: cy,
          halfThickness: half,
          paint: activePaint,
        );
      }
    }

    final handle = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(thumbX, cy),
        width: handleWidth,
        height: handleHeight,
      ),
      Radius.circular(handleWidth),
    );
    canvas.drawRRect(handle, _fill(active));
  }

  @override
  bool shouldRepaint(M3SmoothSeekPainter old) =>
      old.value != value ||
      old.wavy != wavy ||
      old.phase != phase ||
      old.active != active ||
      old.inactive != inactive ||
      old.waveAmplitude != waveAmplitude ||
      old.wavelength != wavelength ||
      old.sampleStep != sampleStep;
}

class M3SmoothRingPainter extends CustomPainter {
  final double? progress;
  final bool wavy;
  final bool loading;
  final double phase;
  final Color active;
  final Color track;
  final double strokeWidth;
  final double trackStrokeWidth;
  final double maxAmplitude;
  final double wavelength;
  final double devicePixelRatio;

  const M3SmoothRingPainter({
    required this.progress,
    required this.wavy,
    required this.loading,
    required this.phase,
    required this.active,
    required this.track,
    required this.strokeWidth,
    required this.trackStrokeWidth,
    required this.maxAmplitude,
    required this.wavelength,
    this.devicePixelRatio = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final amp = wavy ? maxAmplitude : 0.0;
    final maxStroke = math.max(strokeWidth, trackStrokeWidth);
    final radius = (size.shortestSide - maxStroke) / 2 - amp;
    if (radius <= 0) return;

    const tau = 2 * math.pi;
    final start = -math.pi / 2;
    final waveK =
        math.max(1, ((tau * radius) / math.max(wavelength, 1)).round()) *
        tau /
        (tau * radius);

    final trackPaint = _fill(track);
    final activePaint = _fill(active);

    if (loading) {
      final sweep = lerpDouble(0.18, 0.72, (math.sin(phase) + 1) / 2)! * tau;
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(phase * 0.85)
        ..translate(-center.dx, -center.dy);
      _drawArcRibbon(
        canvas,
        center: center,
        radius: radius,
        startAngle: start + sweep,
        sweepAngle: tau - sweep - 0.4,
        amplitude: 0,
        waveK: waveK,
        halfStroke: trackStrokeWidth / 2,
        paint: trackPaint,
      );
      _drawArcRibbon(
        canvas,
        center: center,
        radius: radius,
        startAngle: start,
        sweepAngle: sweep,
        amplitude: amp,
        waveK: waveK,
        halfStroke: strokeWidth / 2,
        paint: activePaint,
      );
      canvas.restore();
      return;
    }

    final p = (progress ?? 0).clamp(0.0, 1.0);
    final activeSweep = p * tau;
    if (p < 1) {
      _drawArcRibbon(
        canvas,
        center: center,
        radius: radius,
        startAngle: start + activeSweep + 0.12,
        sweepAngle: tau - activeSweep - 0.24,
        amplitude: 0,
        waveK: waveK,
        halfStroke: trackStrokeWidth / 2,
        paint: trackPaint,
      );
    }
    if (activeSweep > 0.001) {
      _drawArcRibbon(
        canvas,
        center: center,
        radius: radius,
        startAngle: start,
        sweepAngle: activeSweep,
        amplitude: amp,
        waveK: waveK,
        halfStroke: strokeWidth / 2,
        paint: activePaint,
      );
    }
  }

  void _drawArcRibbon(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double startAngle,
    required double sweepAngle,
    required double amplitude,
    required double waveK,
    required double halfStroke,
    required Paint paint,
  }) {
    if (sweepAngle.abs() < 0.001 || halfStroke <= 0) return;

    final arcLen = radius * sweepAngle.abs();
    final px = 0.28 / devicePixelRatio.clamp(1.0, 4.0);
    final steps = math.max(48, (arcLen / px).ceil());

    Offset at(double t, double radial) {
      final angle = startAngle + sweepAngle * t;
      final travelled = radius * (sweepAngle * t).abs();
      final r =
          radius + amplitude * math.sin(phase + travelled * waveK) + radial;
      return Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
    }

    final path = Path();
    final firstOuter = at(0, halfStroke);
    path.moveTo(firstOuter.dx, firstOuter.dy);
    for (var i = 1; i <= steps; i++) {
      final p = at(i / steps, halfStroke);
      path.lineTo(p.dx, p.dy);
    }
    for (var i = steps; i >= 0; i--) {
      final p = at(i / steps, -halfStroke);
      path.lineTo(p.dx, p.dy);
    }
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawCircle(at(0, 0), halfStroke, paint);
    canvas.drawCircle(at(1, 0), halfStroke, paint);
  }

  @override
  bool shouldRepaint(M3SmoothRingPainter old) =>
      old.progress != progress ||
      old.wavy != wavy ||
      old.loading != loading ||
      old.phase != phase ||
      old.active != active ||
      old.track != track ||
      old.maxAmplitude != maxAmplitude ||
      old.devicePixelRatio != devicePixelRatio;
}
