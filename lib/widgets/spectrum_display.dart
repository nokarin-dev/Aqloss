import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

class SpectrumDisplay extends ConsumerStatefulWidget {
  final double height;
  final int barCount;
  final Color? color;

  const SpectrumDisplay({
    super.key,
    this.height = 72,
    this.barCount = 48,
    this.color,
  });

  @override
  ConsumerState<SpectrumDisplay> createState() => _SpectrumDisplayState();
}

class _SpectrumDisplayState extends ConsumerState<SpectrumDisplay>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  late List<double> _smoothed;
  late List<double> _peaks;
  late List<int> _peakHold;

  bool _fetchInFlight = false;
  List<double> _lastRaw = [];
  Duration _lastFetch = Duration.zero;

  static const _fetchIntervalMs = 16;
  static const _alphaAttack = 0.82;
  static const _alphaRelease = 0.28;
  static const _peakHoldFrames = 40;
  static const _peakDecay = 0.018;

  @override
  void initState() {
    super.initState();
    _smoothed = List.filled(widget.barCount, 0.0);
    _peaks = List.filled(widget.barCount, 0.0);
    _peakHold = List.filled(widget.barCount, 0);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;

    final settings = ref.read(settingsProvider);
    if (!settings.spectrumEnabled) {
      if (_smoothed.any((v) => v > 0)) {
        setState(() {
          for (int i = 0; i < _smoothed.length; i++) {
            _smoothed[i] = 0.0;
            _peaks[i] = 0.0;
            _peakHold[i] = 0;
          }
        });
      }
      return;
    }

    final isPlaying = ref.read(playerProvider).status == PlayerStatus.playing;

    if (!isPlaying) {
      bool changed = false;
      final next = List<double>.generate(widget.barCount, (i) {
        final v = _smoothed[i] * 0.88;
        if (v > 0.001) changed = true;
        return v < 0.001 ? 0.0 : v;
      });
      for (int i = 0; i < _peaks.length; i++) {
        _peaks[i] = (_peaks[i] - _peakDecay * 2).clamp(0.0, 1.0);
        if (_peaks[i] < _smoothed[i]) _peaks[i] = _smoothed[i];
      }
      if (changed) setState(() => _smoothed = next);
      return;
    }

    final msSinceFetch = (elapsed - _lastFetch).inMilliseconds;
    if (!_fetchInFlight && msSinceFetch >= _fetchIntervalMs) {
      _lastFetch = elapsed;
      _fetchInFlight = true;
      backend
          .getSpectrumData(bucketCount: widget.barCount)
          .then((raw) {
            _fetchInFlight = false;
            if (!mounted || raw.isEmpty) return;
            _lastRaw = raw.map((v) => v.toDouble().clamp(0.0, 1.0)).toList();
          })
          .catchError((_) => _fetchInFlight = false);
    } 

    if (_lastRaw.isEmpty) return;

    bool changed = false;
    final next = List<double>.generate(widget.barCount, (i) {
      final target = i < _lastRaw.length ? _lastRaw[i] : 0.0;
      final prev = _smoothed[i];
      final alpha = target > prev ? _alphaAttack : _alphaRelease;
      final v = prev + (target - prev) * alpha;
      if ((v - prev).abs() > 0.001) changed = true;
      return v;
    });

    for (int i = 0; i < widget.barCount; i++) {
      if (next[i] >= _peaks[i]) {
        _peaks[i] = next[i];
        _peakHold[i] = _peakHoldFrames;
      } else {
        if (_peakHold[i] > 0) {
          _peakHold[i]--;
        } else {
          _peaks[i] = (_peaks[i] - _peakDecay).clamp(0.0, 1.0);
          if (_peaks[i] < next[i]) _peaks[i] = next[i];
        }
      }
    }

    if (changed) setState(() => _smoothed = next);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isPlaying = ref.watch(playerProvider).status == PlayerStatus.playing;

    if (!settings.spectrumEnabled) return SizedBox(height: widget.height);

    final barColor =
        widget.color ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70);

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final w = constraints.maxWidth;
          final h = widget.height;
          switch (settings.spectrumStyle) {
            case 1:
              return CustomPaint(
                size: Size(w, h),
                painter: _WavePainter(
                  smoothed: _smoothed,
                  color: barColor,
                  isPlaying: isPlaying,
                ),
              );
            case 2:
              return CustomPaint(
                size: Size(w, h),
                painter: _DotsPainter(
                  smoothed: _smoothed,
                  color: barColor,
                  isPlaying: isPlaying,
                ),
              );
            case 3:
              return CustomPaint(
                size: Size(w, h),
                painter: _ClassicPainter(
                  smoothed: _smoothed,
                  peaks: _peaks,
                  color: barColor,
                  isPlaying: isPlaying,
                  canvasWidth: w,
                ),
              );
            default:
              return CustomPaint(
                size: Size(w, h),
                painter: _BarsPainter(
                  smoothed: _smoothed,
                  peaks: _peaks,
                  color: barColor,
                  isPlaying: isPlaying,
                ),
              );
          }
        },
      ),
    );
  }
}

// Bars
class _BarsPainter extends CustomPainter {
  final List<double> smoothed;
  final List<double> peaks;
  final Color color;
  final bool isPlaying;

  _BarsPainter({
    required this.smoothed,
    required this.peaks,
    required this.color,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (smoothed.isEmpty) return;

    final n = smoothed.length;
    final slotW = size.width / n;
    final barW = (slotW * 0.60).clamp(2.0, 7.0);
    final halfGap = (slotW - barW) / 2;
    final radius = Radius.circular(barW / 2);
    final peakH = (barW * 0.55).clamp(1.5, 3.5);

    final barPaint = Paint()..style = PaintingStyle.fill;
    final peakPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < n; i++) {
      final level = smoothed[i];
      final barH = math.max(level * size.height, 2.0);
      final x = i * slotW + halfGap;
      final opacity = isPlaying
          ? (0.30 + level * 0.70).clamp(0.15, 1.0)
          : level * 0.4;

      barPaint.color = color.withValues(alpha: opacity);
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          x,
          size.height - barH,
          x + barW,
          size.height,
          topLeft: radius,
          topRight: radius,
        ),
        barPaint,
      );

      final peakLevel = peaks[i];
      if (peakLevel > 0.01) {
        final py = size.height - peakLevel * size.height - peakH - 1;
        peakPaint.color = color.withValues(
          alpha: (opacity * 1.4).clamp(0.0, 1.0),
        );
        canvas.drawRRect(
          RRect.fromLTRBR(x, py, x + barW, py + peakH, radius),
          peakPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.smoothed != smoothed ||
      old.peaks != peaks ||
      old.isPlaying != isPlaying;
}

// Wave
class _WavePainter extends CustomPainter {
  final List<double> smoothed;
  final Color color;
  final bool isPlaying;

  _WavePainter({
    required this.smoothed,
    required this.color,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (smoothed.isEmpty) return;

    final n = smoothed.length;
    final step = size.width / (n - 1);
    final midY = size.height * 0.5;
    final baseAlpha = isPlaying ? 1.0 : 0.35;

    // Build upper path
    final path = Path();
    path.moveTo(0, midY - smoothed[0] * midY);
    for (int i = 1; i < n; i++) {
      final x0 = (i - 1) * step;
      final x1 = i * step;
      final y0 = midY - smoothed[i - 1] * midY;
      final y1 = midY - smoothed[i] * midY;
      path.cubicTo((x0 + x1) / 2, y0, (x0 + x1) / 2, y1, x1, y1);
    }

    // Filled area under upper curve
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, midY);
    fillPath.lineTo(0, midY);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, midY), [
        color.withValues(alpha: baseAlpha * 0.55),
        color.withValues(alpha: 0.0),
      ])
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Stroke on top
    final linePaint = Paint()
      ..color = color.withValues(alpha: baseAlpha * 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Mirror lower half
    final pathB = Path();
    pathB.moveTo(0, midY + smoothed[0] * midY);
    for (int i = 1; i < n; i++) {
      final x0 = (i - 1) * step;
      final x1 = i * step;
      final y0 = midY + smoothed[i - 1] * midY;
      final y1 = midY + smoothed[i] * midY;
      pathB.cubicTo((x0 + x1) / 2, y0, (x0 + x1) / 2, y1, x1, y1);
    }

    final fillPathB = Path.from(pathB);
    fillPathB.lineTo(size.width, midY);
    fillPathB.lineTo(0, midY);
    fillPathB.close();

    canvas.drawPath(
      fillPathB,
      fillPaint
        ..shader = ui.Gradient.linear(Offset(0, size.height), Offset(0, midY), [
          color.withValues(alpha: baseAlpha * 0.30),
          color.withValues(alpha: 0.0),
        ]),
    );
    canvas.drawPath(
      pathB,
      linePaint..color = color.withValues(alpha: baseAlpha * 0.40),
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.smoothed != smoothed || old.isPlaying != isPlaying;
}

// Dots
class _DotsPainter extends CustomPainter {
  final List<double> smoothed;
  final Color color;
  final bool isPlaying;

  _DotsPainter({
    required this.smoothed,
    required this.color,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (smoothed.isEmpty) return;

    const rows = 10;
    const gapFraction = 0.18;

    final n = smoothed.length;
    final colW = size.width / n;
    final segW = (colW * 0.72).clamp(2.0, 9.0);
    final colGap = (colW - segW) / 2;

    final rowH = size.height / rows;
    final segH = rowH * (1.0 - gapFraction);
    final rowGap = rowH * gapFraction;
    final radius = Radius.circular(segW * 0.25);

    final litPaint = Paint()..style = PaintingStyle.fill;
    final dimPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.07);

    for (int col = 0; col < n; col++) {
      final level = smoothed[col];
      final litRows = (level * rows).round().clamp(0, rows);
      final x = col * colW + colGap;

      for (int row = 0; row < rows; row++) {
        final y = size.height - (row + 1) * rowH + rowGap / 2;
        final rect = RRect.fromLTRBR(x, y, x + segW, y + segH, radius);

        if (row < litRows) {
          final t = row / (rows - 1);
          Color segColor;
          if (t < 0.6) {
            segColor = Color.lerp(
              const Color(0xFF4ADE80),
              const Color(0xFFFBBF24),
              t / 0.6,
            )!;
          } else {
            segColor = Color.lerp(
              const Color(0xFFFBBF24),
              const Color(0xFFEF4444),
              (t - 0.6) / 0.4,
            )!;
          }
          final alpha = isPlaying ? (0.55 + t * 0.45) : 0.30;
          litPaint.color = segColor.withValues(alpha: alpha);
          canvas.drawRRect(rect, litPaint);
        } else {
          canvas.drawRRect(rect, dimPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.smoothed != smoothed || old.isPlaying != isPlaying;
}

// Classic
class _ClassicPainter extends CustomPainter {
  final List<double> smoothed;
  final List<double> peaks;
  final Color color;
  final bool isPlaying;
  final double canvasWidth;

  _ClassicPainter({
    required this.smoothed,
    required this.peaks,
    required this.color,
    required this.isPlaying,
    required this.canvasWidth,
  });

  double _sample(double t) {
    if (smoothed.isEmpty) return 0.0;
    final idx = t * (smoothed.length - 1);
    final lo = idx.floor().clamp(0, smoothed.length - 1);
    final hi = (lo + 1).clamp(0, smoothed.length - 1);
    return smoothed[lo] + (smoothed[hi] - smoothed[lo]) * (idx - lo);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (smoothed.isEmpty) return;

    final W = size.width;
    final H = size.height;

    // Bar density
    final n = (W / 3.0).round().clamp(smoothed.length, 320);
    final slotW = W / n;
    final barW = (slotW * 0.72).clamp(1.2, 5.0);
    final halfGap = (slotW - barW) / 2;
    final radius = Radius.circular(barW / 2);

    // Center
    final cy = H * 0.52;
    final maxUpH = cy;
    final maxDnH = (H - cy) * 0.42;

    final baseAlpha = isPlaying ? 1.0 : 0.35;

    final barPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < n; i++) {
      final t = i / (n - 1);
      final level = _sample(t);
      if (level < 0.002) continue;

      // Edge-fade
      final fade = 0.25 + 0.75 * math.sin(math.pi * t);
      final x = i * slotW + halfGap;

      // Upper bar
      final upH = math.max(level * maxUpH, 2.0);
      final upTop = cy - upH;

      barPaint.shader = ui.Gradient.linear(Offset(x, cy), Offset(x, upTop), [
        color.withValues(alpha: baseAlpha * fade * 0.92),
        color.withValues(alpha: baseAlpha * fade * 0.38),
      ]);

      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          x,
          upTop,
          x + barW,
          cy,
          topLeft: radius,
          topRight: radius,
        ),
        barPaint,
      );

      // Mirror reflection
      final dnH = math.max(level * maxDnH, 1.0);

      barPaint.shader = ui.Gradient.linear(Offset(x, cy), Offset(x, cy + dnH), [
        color.withValues(alpha: baseAlpha * fade * 0.32),
        color.withValues(alpha: 0.0),
      ]);

      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          x,
          cy,
          x + barW,
          cy + dnH,
          bottomLeft: radius,
          bottomRight: radius,
        ),
        barPaint,
      );
    }

    // Subtle center anchor line
    canvas.drawLine(
      Offset(0, cy),
      Offset(W, cy),
      Paint()
        ..color = color.withValues(alpha: baseAlpha * 0.10)
        ..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(_ClassicPainter old) =>
      old.smoothed != smoothed ||
      old.peaks != peaks ||
      old.color != color ||
      old.isPlaying != isPlaying;
}
