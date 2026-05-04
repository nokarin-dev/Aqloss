import 'dart:async';
import 'package:flutter/material.dart';
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
    this.height = 48,
    this.barCount = 32,
    this.color,
  });

  @override
  ConsumerState<SpectrumDisplay> createState() => _SpectrumDisplayState();
}

class _SpectrumDisplayState extends ConsumerState<SpectrumDisplay> {
  Timer? _timer;
  late List<double> _smoothed;
  bool _fetchInFlight = false;

  static const _fetchInterval = Duration(milliseconds: 50);
  static const _decayRate = 0.82;
  static const _alphaAttack = 0.65;
  static const _alphaRelease = 0.20;
  static const _changeThreshold = 0.005;

  @override
  void initState() {
    super.initState();
    _smoothed = List.filled(widget.barCount, 0.0);
    _timer = Timer.periodic(_fetchInterval, _onTick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTick(Timer _) {
    if (!mounted) return;

    final settings = ref.read(settingsProvider);
    if (!settings.spectrumEnabled) {
      if (_smoothed.any((v) => v > 0)) {
        setState(() => _smoothed = List.filled(widget.barCount, 0.0));
      }
      return;
    }

    final isPlaying = ref.read(playerProvider).status == PlayerStatus.playing;

    if (!isPlaying) {
      bool changed = false;
      final next = List<double>.generate(widget.barCount, (i) {
        final v = _smoothed[i] * _decayRate;
        if (v > 0.001) changed = true;
        return v < 0.001 ? 0.0 : v;
      });
      if (changed) setState(() => _smoothed = next);
      return;
    }

    if (_fetchInFlight) return;
    _fetchInFlight = true;

    backend
        .getSpectrumData(bucketCount: widget.barCount)
        .then((raw) {
          _fetchInFlight = false;
          if (!mounted || raw.isEmpty) return;

          final next = List<double>.generate(widget.barCount, (i) {
            final target = raw[i].toDouble().clamp(0.0, 1.0);
            final prev = _smoothed[i];
            final alpha = target > prev ? _alphaAttack : _alphaRelease;
            return prev + (target - prev) * alpha;
          });

          bool hasChange = false;
          for (int i = 0; i < next.length; i++) {
            if ((next[i] - _smoothed[i]).abs() > _changeThreshold) {
              hasChange = true;
              break;
            }
          }
          if (!hasChange) return;
          setState(() => _smoothed = next);
        })
        .catchError((_) {
          _fetchInFlight = false;
        });
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
            case 1: // Wave
              return _WaveRenderer(
                smoothed: _smoothed,
                height: widget.height,
                color: barColor,
                isPlaying: isPlaying,
              );
            case 2: // Dots
              return _DotsRenderer(
                smoothed: _smoothed,
                height: widget.height,
                color: barColor,
                isPlaying: isPlaying,
              );
            default: // Bars (0)
              final totalWidth = constraints.maxWidth;
              final barWidth = (totalWidth / widget.barCount * 0.62).clamp(
                2.0,
                8.0,
              );
              final gap = totalWidth / widget.barCount - barWidth;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(widget.barCount, (i) {
                  final level = _smoothed[i];
                  final h = (level * widget.height).clamp(2.0, widget.height);
                  final opacity = isPlaying
                      ? (0.35 + level * 0.65).clamp(0.0, 1.0)
                      : (level * 0.5).clamp(0.0, 0.5);
                  return Padding(
                    padding: EdgeInsets.only(right: gap),
                    child: Container(
                      width: barWidth,
                      height: h,
                      decoration: BoxDecoration(
                        color: barColor.withValues(alpha: opacity),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(barWidth / 2),
                        ),
                      ),
                    ),
                  );
                }),
              );
          }
        },
      ),
    );
  }
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
      ..color = color.withValues(alpha: isPlaying ? 0.65 : 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final n = smoothed.length;
    final step = size.width / (n - 1);

    // Mirror wave
    final midY = size.height * 0.5;
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

    // Mirror bottom half
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
      paint..color = color.withValues(alpha: isPlaying ? 0.30 : 0.12),
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
    const maxDots = 6;
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
            ? (isPlaying ? (0.4 + (d / maxDots) * 0.6) : 0.25)
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
