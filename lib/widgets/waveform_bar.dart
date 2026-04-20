import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/player_provider.dart';

class WaveformBar extends ConsumerStatefulWidget {
  final double width;
  final double height;
  final Color? color;

  const WaveformBar({super.key, this.width = 24, this.height = 16, this.color});

  @override
  ConsumerState<WaveformBar> createState() => _WaveformBarState();
}

class _WaveformBarState extends ConsumerState<WaveformBar>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;
  static const _restHeights = [0.30, 0.55, 1.0, 0.55, 0.30];
  static const _durations = [700, 500, 600, 550, 650];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      5,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: _durations[i]),
      ),
    );
    _animations = List.generate(
      5,
      (i) => Tween<double>(begin: _restHeights[i], end: _randomPeak(i)).animate(
        CurvedAnimation(parent: _controllers[i], curve: Curves.easeInOut),
      ),
    );
  }

  double _randomPeak(int i) {
    final r = Random(i * 42);
    return 0.4 + r.nextDouble() * 0.6;
  }

  void _startAnimating() {
    for (var i = 0; i < _controllers.length; i++) {
      _controllers[i].repeat(reverse: true);
    }
  }

  void _stopAnimating() {
    for (final c in _controllers) {
      c.animateTo(0.0, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final isPlaying = player.status == PlayerStatus.playing;

    if (isPlaying) {
      _startAnimating();
    } else {
      _stopAnimating();
    }

    final barColor = widget.color ?? Theme.of(context).colorScheme.onSurface;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(5, (i) {
          return AnimatedBuilder(
            animation: _animations[i],
            builder: (_, _) {
              final h = widget.height * _animations[i].value;
              return Container(
                width: (widget.width - 8) / 5,
                height: h.clamp(2.0, widget.height),
                decoration: BoxDecoration(
                  color: barColor.withValues(
                    alpha: isPlaying ? 1.0 : _restHeights[i].clamp(0.2, 1.0),
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
