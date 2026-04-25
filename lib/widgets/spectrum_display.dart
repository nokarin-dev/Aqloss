import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/player_provider.dart';
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

class _SpectrumDisplayState extends ConsumerState<SpectrumDisplay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  late List<double> _smoothed;

  DateTime _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);
  static const _fetchInterval = Duration(milliseconds: 30);
  bool _fetchInFlight = false;
  static const _decayRate = 0.82;

  static const _alphaAttack = 0.65;
  static const _alphaRelease = 0.20;

  @override
  void initState() {
    super.initState();
    _smoothed = List.filled(widget.barCount, 0.0);

    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;

    final isPlaying = ref.read(playerProvider).status == PlayerStatus.playing;

    if (!isPlaying) {
      bool changed = false;
      final next = List<double>.generate(widget.barCount, (i) {
        final v = _smoothed[i] * _decayRate;
        if ((v - _smoothed[i]).abs() > 0.001) changed = true;
        return v < 0.001 ? 0.0 : v;
      });
      if (changed) {
        setState(() => _smoothed = next);
      }
      return;
    }

    final now = DateTime.now();
    if (_fetchInFlight || now.difference(_lastFetch) < _fetchInterval) return;

    _fetchInFlight = true;
    _lastFetch = now;

    backend
        .getSpectrumData(bucketCount: widget.barCount)
        .then((raw) {
          _fetchInFlight = false;
          if (!mounted || raw.isEmpty) return;

          setState(() {
            _smoothed = List.generate(widget.barCount, (i) {
              final target = raw[i].toDouble().clamp(0.0, 1.0);
              final prev = _smoothed[i];
              final alpha = target > prev ? _alphaAttack : _alphaRelease;
              return prev + (target - prev) * alpha;
            });
          });
        })
        .catchError((_) {
          _fetchInFlight = false;
        });
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = ref.watch(playerProvider).status == PlayerStatus.playing;

    final barColor =
        widget.color ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70);

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (_, constraints) {
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
        },
      ),
    );
  }
}
