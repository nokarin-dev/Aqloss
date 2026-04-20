import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/player_provider.dart';

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
  late List<double> _heights;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _heights = _generateHeights();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..addListener(_updateHeights);
  }

  List<double> _generateHeights() {
    return List.generate(widget.barCount, (i) {
      final x = i / widget.barCount;
      final envelope = exp(-8 * pow(x - 0.3, 2)) * 0.9;
      return envelope + _random.nextDouble() * 0.15;
    });
  }

  void _updateHeights() {
    if (!mounted) return;
    setState(() {
      _heights = List.generate(widget.barCount, (i) {
        final current = _heights[i];
        final target = _generateHeights()[i];
        return (current * 0.7 + target * 0.3).clamp(0.02, 1.0);
      });
    });
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_updateHeights)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final isPlaying = player.status == PlayerStatus.playing;

    if (isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!isPlaying && _controller.isAnimating) {
      _controller.stop();
      setState(() {
        _heights = List.filled(widget.barCount, 0.04);
      });
    }

    final barColor =
        widget.color ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final totalWidth = constraints.maxWidth;
          final barWidth = (totalWidth / widget.barCount * 0.6).clamp(2.0, 8.0);
          final gap = totalWidth / widget.barCount - barWidth;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.barCount, (i) {
              final h = (_heights[i] * widget.height).clamp(2.0, widget.height);
              return Padding(
                padding: EdgeInsets.only(right: gap),
                child: Container(
                  width: barWidth,
                  height: h,
                  decoration: BoxDecoration(
                    color: barColor,
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
