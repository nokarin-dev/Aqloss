import 'dart:math' as math;

import 'package:flutter/material.dart';

String m3FormatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:$m:$s';
  return '$m:$s';
}

/// M3 playback progress
class M3WavyLinearProgress extends StatefulWidget {
  final double? value;
  final Color? color;
  final Color? backgroundColor;
  final double height;
  final double strokeWidth;
  final double wavelength;
  final double amplitude;
  final double gapSize;
  final double stopRadius;
  final bool playing;
  final BorderRadius? borderRadius;

  const M3WavyLinearProgress({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.height = 8,
    this.strokeWidth = 4,
    this.wavelength = 24,
    this.amplitude = 0.85,
    this.gapSize = 4,
    this.stopRadius = 3,
    this.playing = false,
    this.borderRadius,
  });

  @override
  State<M3WavyLinearProgress> createState() => _M3WavyLinearProgressState();
}

class _M3WavyLinearProgressState extends State<M3WavyLinearProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phaseCtrl;

  @override
  void initState() {
    super.initState();
    _phaseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(M3WavyLinearProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing ||
        oldWidget.value != widget.value) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.playing && widget.value != null) {
      _phaseCtrl.repeat();
    } else {
      _phaseCtrl.stop();
      _phaseCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _phaseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final indicator = theme.progressIndicatorTheme;
    final active = widget.color ?? indicator.color ?? cs.primary;
    final track =
        widget.backgroundColor ??
        indicator.linearTrackColor ??
        cs.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: _phaseCtrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _WavyProgressPainter(
            value: widget.value,
            phase: _phaseCtrl.value * math.pi * 2,
            playing: widget.playing,
            activeColor: active,
            trackColor: track,
            strokeWidth: widget.strokeWidth,
            wavelength: widget.wavelength,
            amplitude: widget.amplitude,
            gapSize: widget.gapSize,
            stopRadius: widget.stopRadius,
            borderRadius: widget.borderRadius,
          ),
          size: Size.fromHeight(widget.height),
        );
      },
    );
  }
}

class _WavyProgressPainter extends CustomPainter {
  final double? value;
  final double phase;
  final bool playing;
  final Color activeColor;
  final Color trackColor;
  final double strokeWidth;
  final double wavelength;
  final double amplitude;
  final double gapSize;
  final double stopRadius;
  final BorderRadius? borderRadius;

  const _WavyProgressPainter({
    required this.value,
    required this.phase,
    required this.playing,
    required this.activeColor,
    required this.trackColor,
    required this.strokeWidth,
    required this.wavelength,
    required this.amplitude,
    required this.gapSize,
    required this.stopRadius,
    this.borderRadius,
  });

  double _midY(double height) => height / 2;

  double _waveY(double x, double height) {
    final mid = _midY(height);
    final amp = (height - strokeWidth) / 2 * amplitude;
    return mid + amp * math.sin((x / wavelength) * math.pi * 2 + phase);
  }

  Path _wavePath(double width, double height) {
    final path = Path();
    const step = 2.0;
    path.moveTo(0, _waveY(0, height));
    for (var x = step; x <= width; x += step) {
      path.lineTo(x, _waveY(x, height));
    }
    return path;
  }

  void _drawFlat(
    Canvas canvas,
    double x1,
    double x2,
    double midY,
    Paint paint,
  ) {
    if (x2 <= x1) return;
    canvas.drawLine(Offset(x1, midY), Offset(x2, midY), paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final clipRRect = borderRadius != null
        ? RRect.fromRectAndCorners(
            Offset.zero & size,
            topLeft: borderRadius!.topLeft,
            topRight: borderRadius!.topRight,
            bottomLeft: borderRadius!.bottomLeft,
            bottomRight: borderRadius!.bottomRight,
          )
        : null;

    if (clipRRect != null) {
      canvas.save();
      canvas.clipRRect(clipRRect);
    }

    if (value == null) {
      _paintIndeterminate(canvas, size);
      if (clipRRect != null) canvas.restore();
      return;
    }

    final progress = value!.clamp(0.0, 1.0);
    final midY = _midY(size.height);
    final headX = size.width * progress;
    final activeEnd = math.max(0.0, headX - gapSize);
    final futureStart = math.min(size.width, headX + gapSize);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    _drawFlat(canvas, futureStart, size.width, midY, trackPaint);

    if (activeEnd > 0) {
      if (playing) {
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(0, 0, activeEnd, size.height));
        canvas.drawPath(_wavePath(size.width, size.height), activePaint);
        canvas.restore();
      } else {
        _drawFlat(canvas, 0, activeEnd, midY, activePaint);
      }
    } else if (progress <= 0) {
      _drawFlat(canvas, 0, size.width, midY, trackPaint);
    }

    if (progress > 0) {
      final dotY = playing ? _waveY(headX, size.height) : midY;
      canvas.drawCircle(
        Offset(headX, dotY),
        stopRadius,
        Paint()..color = activeColor,
      );
    }

    if (clipRRect != null) canvas.restore();
  }

  void _paintIndeterminate(Canvas canvas, Size size) {
    final midY = _midY(size.height);
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    _drawFlat(canvas, 0, size.width, midY, trackPaint);

    final t = (phase / (math.pi * 2)).clamp(0.0, 1.0);
    final head = size.width * (0.15 + t * 0.7);
    final tail = (head - size.width * 0.28).clamp(0.0, size.width);

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(tail, 0, head, size.height));
    canvas.drawPath(_wavePath(size.width, size.height), activePaint);
    canvas.restore();

    canvas.drawCircle(
      Offset(head, _waveY(head, size.height)),
      stopRadius,
      Paint()..color = activeColor,
    );
  }

  @override
  bool shouldRepaint(covariant _WavyProgressPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.phase != phase ||
        oldDelegate.playing != playing ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor;
  }
}

class M3PlaybackRing extends StatelessWidget {
  final double? progress;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final bool loading;
  final Widget child;

  const M3PlaybackRing({
    super.key,
    this.progress,
    required this.child,
    this.size = 66,
    this.strokeWidth = 3.5,
    this.color,
    this.trackColor,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicator = theme.progressIndicatorTheme;
    final active = color ?? indicator.color ?? theme.colorScheme.primary;
    final track =
        trackColor ??
        indicator.circularTrackColor ??
        theme.colorScheme.surfaceContainerHighest;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: loading ? null : progress?.clamp(0.0, 1.0),
            strokeWidth: strokeWidth,
            strokeCap: StrokeCap.round,
            color: active,
            backgroundColor: track,
          ),
          child,
        ],
      ),
    );
  }
}

class M3SeekBar extends StatefulWidget {
  final double progress;
  final Duration position;
  final Duration duration;
  final bool enabled;
  final bool playing;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final Color? activeColor;

  const M3SeekBar({
    super.key,
    required this.progress,
    required this.position,
    required this.duration,
    this.enabled = true,
    this.playing = false,
    this.onChanged,
    this.onChangeEnd,
    this.activeColor,
  });

  @override
  State<M3SeekBar> createState() => _M3SeekBarState();
}

class _M3SeekBarState extends State<M3SeekBar> {
  double? _dragValue;

  double get _display => (_dragValue ?? widget.progress).clamp(0.0, 1.0);

  void _update(double dx, double width, {bool end = false}) {
    if (!widget.enabled || width <= 0) return;
    final v = (dx / width).clamp(0.0, 1.0);
    setState(() => _dragValue = v);
    if (end) {
      widget.onChangeEnd?.call(v);
      setState(() => _dragValue = null);
    } else {
      widget.onChanged?.call(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: widget.enabled
                  ? (d) => _update(d.localPosition.dx, width)
                  : null,
              onTapUp: widget.enabled
                  ? (d) => _update(d.localPosition.dx, width, end: true)
                  : null,
              onHorizontalDragUpdate: widget.enabled
                  ? (d) => _update(d.localPosition.dx, width)
                  : null,
              onHorizontalDragEnd: widget.enabled
                  ? (_) {
                      if (_dragValue != null) {
                        widget.onChangeEnd?.call(_dragValue!);
                      }
                      setState(() => _dragValue = null);
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: M3WavyLinearProgress(
                  value: _display,
                  color: widget.activeColor ?? cs.primary,
                  height: 8,
                  strokeWidth: 4,
                  playing: widget.playing && _dragValue == null,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                m3FormatDuration(widget.position),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                m3FormatDuration(widget.duration),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class M3MiniPlaybackProgress extends StatefulWidget {
  final double progress;
  final Duration position;
  final Duration duration;
  final bool playing;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  const M3MiniPlaybackProgress({
    super.key,
    required this.progress,
    required this.position,
    required this.duration,
    this.playing = false,
    this.onChanged,
    this.onChangeEnd,
  });

  @override
  State<M3MiniPlaybackProgress> createState() => _M3MiniPlaybackProgressState();
}

class _M3MiniPlaybackProgressState extends State<M3MiniPlaybackProgress> {
  double? _dragValue;

  double get _display => (_dragValue ?? widget.progress).clamp(0.0, 1.0);

  void _update(double dx, double width, {bool end = false}) {
    if (width <= 0) return;
    final v = (dx / width).clamp(0.0, 1.0);
    setState(() => _dragValue = v);
    if (end) {
      widget.onChangeEnd?.call(v);
      setState(() => _dragValue = null);
    } else {
      widget.onChanged?.call(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Text(
          m3FormatDuration(widget.position),
          style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _update(d.localPosition.dx, width),
                onTapUp: (d) => _update(d.localPosition.dx, width, end: true),
                onHorizontalDragUpdate: (d) =>
                    _update(d.localPosition.dx, width),
                onHorizontalDragEnd: (_) {
                  if (_dragValue != null) widget.onChangeEnd?.call(_dragValue!);
                  setState(() => _dragValue = null);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: M3WavyLinearProgress(
                    value: _display,
                    height: 6,
                    strokeWidth: 3,
                    wavelength: 18,
                    playing: widget.playing && _dragValue == null,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Text(
          m3FormatDuration(widget.duration),
          style: TextStyle(
            fontSize: 10,
            color: cs.onSurfaceVariant.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

class M3PlayButton extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final bool hasTrack;
  final double progress;
  final double size;
  final Color? accentColor;
  final VoidCallback? onTap;

  const M3PlayButton({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.hasTrack,
    required this.progress,
    this.size = 58,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = accentColor ?? cs.primary;
    final onAccent = accentColor != null ? Colors.white : cs.onPrimary;

    final core = Material(
      color: !hasTrack ? cs.onSurface.withValues(alpha: 0.08) : accent,
      shape: const CircleBorder(),
      elevation: hasTrack ? 2 : 0,
      shadowColor: accent.withValues(alpha: 0.35),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: isLoading && !hasTrack
              ? Center(
                  child: SizedBox(
                    width: size * 0.42,
                    height: size * 0.42,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      strokeCap: StrokeCap.round,
                      year2023: false,
                      color: cs.primary,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                )
              : Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: hasTrack
                      ? onAccent
                      : cs.onSurface.withValues(alpha: 0.25),
                  size: size * 0.48,
                ),
        ),
      ),
    );

    if (!hasTrack) return core;

    return M3PlaybackRing(
      progress: isLoading ? null : progress,
      loading: isLoading,
      size: size + 12,
      strokeWidth: 3.5,
      color: accent,
      child: core,
    );
  }
}
