import 'dart:math' as math;
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

  // Fetch state
  bool _fetchInFlight = false;
  List<double> _lastRaw = [];
  Duration _lastFetch = Duration.zero;

  static const _fetchIntervalMs = 16;
  static const _alphaAttack = 0.82;
  static const _alphaRelease = 0.28;

  // Peak hold
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
      final anyNonZero = _smoothed.any((v) => v > 0);
      if (anyNonZero) {
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
          .catchError((_) {
            _fetchInFlight = false;
          });
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

    // Peak hold
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

    if (changed) {
      setState(() => _smoothed = next);
    }
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
          switch (settings.spectrumStyle) {
            case 1:
              return _WaveRenderer(
                smoothed: _smoothed,
                height: widget.height,
                color: barColor,
                isPlaying: isPlaying,
              );
            case 2:
              return _DotsRenderer(
                smoothed: _smoothed,
                height: widget.height,
                color: barColor,
                isPlaying: isPlaying,
              );
            default:
              return CustomPaint(
                size: Size(constraints.maxWidth, widget.height),
                painter: _BarsPainter(
                  smoothed: _smoothed,
                  peaks: _peaks,
                  height: widget.height,
                  color: barColor,
                  isPlaying: isPlaying,
                  totalWidth: constraints.maxWidth,
                ),
              );
          }
        },
      ),
    );
  }
}

// Bars with peak-hold dots
class _BarsPainter extends CustomPainter {
  final List<double> smoothed;
  final List<double> peaks;
  final double height;
  final Color color;
  final bool isPlaying;
  final double totalWidth;

  _BarsPainter({
    required this.smoothed,
    required this.peaks,
    required this.height,
    required this.color,
    required this.isPlaying,
    required this.totalWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (smoothed.isEmpty) return;

    final n = smoothed.length;
    final slotW = size.width / n;
    final barW = (slotW * 0.60).clamp(2.0, 7.0);
    final gap = slotW - barW;
    final halfGap = gap / 2;
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

      // Peak dot
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

// Wave style
class _WaveRenderer extends StatelessWidget {
  final List<double> smoothed;
  final double height;
  final Color color;
  final bool isPlaying;
  const _WaveRenderer({
    required this.smoothed,
    required this.height,
    required this.color,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _WavePainter(
      smoothed: smoothed,
      height: height,
      color: color,
      isPlaying: isPlaying,
    ),
  );
}

class _WavePainter extends CustomPainter {
  final List<double> smoothed;
  final double height;
  final Color color;
  final bool isPlaying;
  _WavePainter({
    required this.smoothed,
    required this.height,
    required this.color,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (smoothed.isEmpty) return;
    final paint = Paint()
      ..color = color.withValues(alpha: isPlaying ? 0.70 : 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final n = smoothed.length;
    final step = size.width / (n - 1);
    final midY = size.height * 0.5;

    final path = Path();
    path.moveTo(0, midY - smoothed[0] * midY);
    for (int i = 1; i < n; i++) {
      final x0 = (i - 1) * step;
      final x1 = i * step;
      final y0 = midY - smoothed[i - 1] * midY;
      final y1 = midY - smoothed[i] * midY;
      final cpx = (x0 + x1) / 2;
      path.cubicTo(cpx, y0, cpx, y1, x1, y1);
    }
    canvas.drawPath(path, paint);

    // Mirror lower half
    final pathB = Path();
    pathB.moveTo(0, midY + smoothed[0] * midY);
    for (int i = 1; i < n; i++) {
      final x0 = (i - 1) * step;
      final x1 = i * step;
      final y0 = midY + smoothed[i - 1] * midY;
      final y1 = midY + smoothed[i] * midY;
      final cpx = (x0 + x1) / 2;
      pathB.cubicTo(cpx, y0, cpx, y1, x1, y1);
    }
    canvas.drawPath(
      pathB,
      paint..color = color.withValues(alpha: isPlaying ? 0.32 : 0.12),
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.smoothed != smoothed || old.isPlaying != isPlaying;
}

// Dots style
class _DotsRenderer extends StatelessWidget {
  final List<double> smoothed;
  final double height;
  final Color color;
  final bool isPlaying;
  const _DotsRenderer({
    required this.smoothed,
    required this.height,
    required this.color,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _DotsPainter(
      smoothed: smoothed,
      height: height,
      color: color,
      isPlaying: isPlaying,
    ),
  );
}

class _DotsPainter extends CustomPainter {
  final List<double> smoothed;
  final double height;
  final Color color;
  final bool isPlaying;
  _DotsPainter({
    required this.smoothed,
    required this.height,
    required this.color,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (smoothed.isEmpty) return;
    final n = smoothed.length;
    final step = size.width / n;
    const maxDots = 8;
    final dotR = (step * 0.22).clamp(1.5, 4.0);
    final dotSpace = size.height / maxDots;

    for (int i = 0; i < n; i++) {
      final cx = i * step + step / 2;
      final level = smoothed[i];
      final lit = (level * maxDots).round().clamp(0, maxDots);
      for (int d = 0; d < maxDots; d++) {
        final cy = size.height - (d + 0.5) * dotSpace;
        final isLit = d < lit;
        final opacity = isLit
            ? (isPlaying ? (0.35 + (d / maxDots) * 0.65) : 0.25)
            : 0.06;
        canvas.drawCircle(
          Offset(cx, cy),
          dotR,
          Paint()..color = color.withValues(alpha: opacity),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.smoothed != smoothed || old.isPlaying != isPlaying;
}
