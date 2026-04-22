import 'package:flutter/material.dart';
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
  late final AnimationController _controller;
  late List<double> _smoothed;

  @override
  void initState() {
    super.initState();
    _smoothed = List.filled(widget.barCount, 0.02);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 60),
    )..addListener(_tick);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_tick)
      ..dispose();
    super.dispose();
  }

  Future<void> _tick() async {
    if (!mounted) return;
    final player = ref.read(playerProvider);
    final isPlaying = player.status == PlayerStatus.playing;

    if (!isPlaying) {
      setState(() {
        _smoothed = _smoothed.map((v) => (v * 0.80).clamp(0.02, 1.0)).toList();
      });
      return;
    }

    final raw = await backend.getSpectrumData(bucketCount: widget.barCount);
    if (!mounted) return;
    if (raw.isEmpty) return;

    setState(() {
      _smoothed = List.generate(widget.barCount, (i) {
        final target = raw[i].toDouble();
        final prev = _smoothed[i];
        final alpha = target > prev ? 0.55 : 0.18;
        return (prev + (target - prev) * alpha).clamp(0.02, 1.0);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final isPlaying = player.status == PlayerStatus.playing;

    if (isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!isPlaying && _controller.isAnimating) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted &&
            ref.read(playerProvider).status != PlayerStatus.playing) {
          _controller.stop();
        }
      });
    }

    final barColor =
        widget.color ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60);

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
              final h = (_smoothed[i] * widget.height).clamp(
                2.0,
                widget.height,
              );
              final opacity = (0.45 + _smoothed[i] * 0.55).clamp(0.0, 1.0);

              return Padding(
                padding: EdgeInsets.only(right: gap),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 40),
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
