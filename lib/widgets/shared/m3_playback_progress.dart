import 'dart:ui' as ui;

import 'package:aqloss/ui/m3/m3_pressable.dart';
import 'package:aqloss/widgets/shared/m3_wave_paint.dart';
import 'package:aqloss/widgets/shared/m3_wave_shaders.dart';
import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

String m3FormatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:$m:$s';
  return '$m:$s';
}

Widget m3eScope(
  BuildContext context,
  Widget child, {
  Color? seed,
  bool compact = false,
}) {
  final theme = Theme.of(context);
  final color = seed ?? theme.colorScheme.primary;
  M3WavePrograms.ensure();
  final base = theme.brightness == Brightness.dark
      ? M3EThemeData.dark(seedColor: color)
      : M3EThemeData.light(seedColor: color);
  return M3ETheme(
    data: base.copyWith(
      sliderTheme: M3ESliderTheme.defaults.copyWith(
        height: compact ? 32 : 40,
        trackHeight: compact ? 3.5 : 4,
        handleHeight: compact ? 14 : 18,
        handleWidth: 3,
        pressedHandleWidth: 2,
        handleGap: 3,
        trackCornerRadius: 2,
        stopIndicatorSize: 3,
        waveAmplitude: compact ? 2.6 : 3.4,
        wavelength: compact ? 56 : 64,
      ),
    ),
    child: child,
  );
}

class M3PlaybackRing extends StatefulWidget {
  final double? progress;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final bool loading;
  final bool wavy;
  final Widget child;

  const M3PlaybackRing({
    super.key,
    this.progress,
    required this.child,
    this.size = 72,
    this.strokeWidth = 6,
    this.color,
    this.trackColor,
    this.loading = false,
    this.wavy = true,
  });

  @override
  State<M3PlaybackRing> createState() => _M3PlaybackRingState();
}

class _M3PlaybackRingState extends State<M3PlaybackRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave;
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    M3WavePrograms.ensure().then((_) {
      final program = M3WavePrograms.ring;
      if (!mounted || program == null) return;
      setState(() => _shader = program.fragmentShader());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWave();
  }

  @override
  void didUpdateWidget(M3PlaybackRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncWave();
  }

  void _syncWave() {
    if (!mounted) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final run = !reduce && (widget.loading || widget.wavy);
    if (run && !_wave.isAnimating) {
      _wave.repeat();
    } else if (!run && _wave.isAnimating) {
      _wave
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = widget.color ?? cs.primary;
    final track = widget.trackColor ?? cs.secondaryContainer;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final shader = _shader;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final wavy = !reduce && (widget.wavy || widget.loading);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _wave,
            builder: (context, _) {
              final phase = _wave.value * 6.283185307179586;
              return CustomPaint(
                size: Size.square(widget.size),
                painter: shader != null
                    ? M3ShaderRingPainter(
                        shader: shader,
                        progress: widget.loading
                            ? 0
                            : (widget.progress ?? 0).clamp(0.0, 1.0),
                        phase: phase,
                        amp: wavy ? 3.4 : 0,
                        wavelength: 28,
                        strokeWidth: widget.strokeWidth,
                        trackStrokeWidth: widget.strokeWidth * 0.62,
                        loading: widget.loading,
                        active: active,
                        track: track,
                        dpr: dpr,
                      )
                    : M3SmoothRingPainter(
                        progress: widget.loading
                            ? null
                            : widget.progress?.clamp(0.0, 1.0),
                        wavy: wavy,
                        loading: widget.loading,
                        phase: phase,
                        active: active,
                        track: track,
                        strokeWidth: widget.strokeWidth,
                        trackStrokeWidth: widget.strokeWidth * 0.62,
                        maxAmplitude: 3.4,
                        wavelength: 28,
                        devicePixelRatio: dpr,
                      ),
              );
            },
          ),
          widget.child,
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
  double? _local;

  @override
  void didUpdateWidget(M3SeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_local != null && (widget.progress - _local!).abs() < 0.004) {
      _local = null;
    }
  }

  void _preview(double v) {
    setState(() => _local = v);
    widget.onChanged?.call(v);
  }

  void _commit(double v) {
    setState(() => _local = v);
    widget.onChangeEnd?.call(v);
    M3EHaptics.trigger(M3EHapticFeedback.light);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = (_local ?? widget.progress).clamp(0.0, 1.0);
    final position = _local != null && widget.duration.inMilliseconds > 0
        ? widget.duration * _local!
        : widget.position;
    final canSeek = widget.enabled && widget.onChanged != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _M3WaveSlider(
          value: v,
          playing: widget.playing,
          enabled: canSeek,
          compact: false,
          activeColor: widget.activeColor,
          onChanged: canSeek ? _preview : null,
          onChangeEnd: canSeek ? _commit : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                m3FormatDuration(position),
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
  double? _local;

  @override
  void didUpdateWidget(M3MiniPlaybackProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_local != null && (widget.progress - _local!).abs() < 0.004) {
      _local = null;
    }
  }

  void _preview(double v) {
    setState(() => _local = v);
    widget.onChanged?.call(v);
  }

  void _commit(double v) {
    setState(() => _local = v);
    widget.onChangeEnd?.call(v);
    M3EHaptics.trigger(M3EHapticFeedback.light);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = (_local ?? widget.progress).clamp(0.0, 1.0);
    final position = _local != null && widget.duration.inMilliseconds > 0
        ? widget.duration * _local!
        : widget.position;
    final timeStyle = TextStyle(fontSize: 10, color: cs.onSurfaceVariant);

    return Row(
      children: [
        SizedBox(
          width: 38,
          child: Text(
            m3FormatDuration(position),
            textAlign: TextAlign.right,
            maxLines: 1,
            style: timeStyle,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRect(
              child: _M3WaveSlider(
                value: v,
                playing: widget.playing,
                enabled: widget.onChanged != null,
                compact: true,
                onChanged: widget.onChanged == null ? null : _preview,
                onChangeEnd: widget.onChanged == null ? null : _commit,
              ),
            ),
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            m3FormatDuration(widget.duration),
            maxLines: 1,
            style: timeStyle.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.75),
            ),
          ),
        ),
      ],
    );
  }
}

class _M3WaveSlider extends StatefulWidget {
  final double value;
  final bool playing;
  final bool enabled;
  final bool compact;
  final Color? activeColor;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  const _M3WaveSlider({
    required this.value,
    required this.playing,
    required this.enabled,
    required this.compact,
    this.activeColor,
    this.onChanged,
    this.onChangeEnd,
  });

  @override
  State<_M3WaveSlider> createState() => _M3WaveSliderState();
}

class _M3WaveSliderState extends State<_M3WaveSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave;
  ui.FragmentShader? _shader;
  double _width = 1;
  double _value = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    M3WavePrograms.ensure().then((_) {
      final program = M3WavePrograms.track;
      if (!mounted || program == null) return;
      setState(() => _shader = program.fragmentShader());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWave();
  }

  @override
  void didUpdateWidget(_M3WaveSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging) _value = widget.value;
    _syncWave();
  }

  void _syncWave() {
    if (!mounted) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final run = !reduce && widget.playing;
    if (run && !_wave.isAnimating) {
      _wave.repeat();
    } else if (!run && _wave.isAnimating) {
      _wave
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    _wave.dispose();
    super.dispose();
  }

  double _at(Offset local) => (local.dx / _width).clamp(0.0, 1.0);

  void _preview(double v) {
    _value = v;
    widget.onChanged?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = widget.activeColor ?? cs.primary;
    final inactive = cs.secondaryContainer;
    final height = widget.compact ? 32.0 : 40.0;
    final wavelength = widget.compact ? 56.0 : 64.0;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final amp = !reduce && widget.playing ? (widget.compact ? 2.6 : 3.4) : 0.0;
    final step = m3WaveStep(context, wavelength: wavelength);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final shader = _shader;
    final trackHeight = widget.compact ? 3.5 : 4.0;
    final handleHeight = widget.compact ? 14.0 : 18.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        return AnimatedBuilder(
          animation: _wave,
          builder: (context, _) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: !widget.enabled
                  ? null
                  : (d) {
                      final v = _at(d.localPosition);
                      _preview(v);
                      widget.onChangeEnd?.call(v);
                    },
              onHorizontalDragStart: !widget.enabled
                  ? null
                  : (d) {
                      _dragging = true;
                      _preview(_at(d.localPosition));
                    },
              onHorizontalDragUpdate: !widget.enabled
                  ? null
                  : (d) => _preview(_at(d.localPosition)),
              onHorizontalDragEnd: !widget.enabled
                  ? null
                  : (_) {
                      _dragging = false;
                      widget.onChangeEnd?.call(_value);
                    },
              child: SizedBox(
                height: height,
                width: double.infinity,
                child: CustomPaint(
                  painter: shader != null
                      ? M3ShaderSeekPainter(
                          shader: shader,
                          value: _dragging ? _value : widget.value,
                          phase: _wave.value * 6.283185307179586,
                          amp: amp,
                          wavelength: wavelength,
                          trackHeight: trackHeight,
                          handleHeight: handleHeight,
                          handleWidth: 3,
                          handleGap: 3,
                          active: active,
                          inactive: inactive,
                          dpr: dpr,
                        )
                      : M3SmoothSeekPainter(
                          value: _dragging ? _value : widget.value,
                          wavy: widget.playing,
                          phase: _wave.value * 6.283185307179586,
                          active: active,
                          inactive: inactive,
                          trackHeight: trackHeight,
                          handleHeight: handleHeight,
                          handleWidth: 3,
                          handleGap: 3,
                          waveAmplitude: amp,
                          wavelength: wavelength,
                          sampleStep: step,
                        ),
                ),
              ),
            );
          },
        );
      },
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
    this.size = 52,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = accentColor ?? cs.primary;
    final muted = cs.onSurface.withValues(alpha: 0.28);
    final ringSize = size + 22;
    final iconColor = hasTrack ? accent : muted;
    final iconSize = size >= 56
        ? 34.0
        : size >= 48
        ? 28.0
        : 22.0;

    final icon = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Icon(
        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        key: ValueKey(isPlaying),
        color: iconColor,
        size: iconSize,
      ),
    );

    final core = (!hasTrack && !isLoading)
        ? SizedBox(
            width: size,
            height: size,
            child: Center(child: icon),
          )
        : M3PlaybackRing(
            progress: isLoading ? null : progress,
            loading: isLoading,
            wavy: isPlaying,
            size: ringSize,
            strokeWidth: size >= 56 ? 6.5 : 5.5,
            color: accent,
            child: icon,
          );

    return m3eScope(
      context,
      M3Pressable(
        onTap: isLoading ? null : onTap,
        enabled: hasTrack && !isLoading,
        ink: false,
        semanticLabel: isPlaying ? 'Pause' : 'Play',
        child: core,
      ),
      seed: accent,
    );
  }
}

class M3TransportIcon extends StatelessWidget {
  final IconData icon;
  final IconData? selectedIcon;
  final bool selected;
  final String? tooltip;
  final VoidCallback? onPressed;
  final M3EIconButtonSize size;

  const M3TransportIcon({
    super.key,
    required this.icon,
    this.selectedIcon,
    this.selected = false,
    this.tooltip,
    this.onPressed,
    this.size = M3EIconButtonSize.sm,
  });

  @override
  Widget build(BuildContext context) {
    return m3eScope(
      context,
      M3EIconButton(
        icon: Icon(icon),
        selectedIcon: selectedIcon != null ? Icon(selectedIcon) : null,
        isSelected: selectedIcon != null ? selected : null,
        onPressed: onPressed,
        tooltip: tooltip,
        variant: M3EIconButtonVariant.standard,
        size: size,
        haptic: M3EHapticFeedback.light,
        enableFeedback: true,
      ),
    );
  }
}
