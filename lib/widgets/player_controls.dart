import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/widgets/ui/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/accent_provider.dart';
import 'package:aqloss/widgets/shared/m3_playback_progress.dart';
import 'package:aqloss/widgets/shared/custom_slider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

class PlayerControls extends ConsumerWidget {
  final bool dense;
  const PlayerControls({super.key, this.dense = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final isPlaying = player.status == PlayerStatus.playing;
    final isLoading = player.status == PlayerStatus.loading;
    final duration = player.currentTrack?.duration ?? Duration.zero;
    final position = player.position;
    final cs = Theme.of(context).colorScheme;
    final isM3 = context.isMaterial3Ui;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    Color onSurfaceAlpha(double a) => onSurface.withValues(alpha: a);

    final double progress =
        duration.inMilliseconds > 0 && player.currentTrack != null
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final isExclusive = backend.isExclusiveMode();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = dense || constraints.maxWidth < 480;
        final playGap = compact ? 12.0 : 26.0;
        final skipSize = compact ? 24.0 : 29.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isM3)
              M3SeekBar(
                progress: progress,
                position: position,
                duration: duration,
                enabled: player.currentTrack != null,
                playing: isPlaying,
                activeColor: ref.accentOrSurface(context),
                onChanged: player.currentTrack == null
                    ? null
                    : (v) {
                        if (duration.inMilliseconds > 0) {
                          notifier.seekPreview(duration * v.clamp(0.0, 1.0));
                        }
                      },
                onChangeEnd: player.currentTrack == null
                    ? null
                    : (v) {
                        if (duration.inMilliseconds > 0) {
                          notifier.seekCommit(duration * v.clamp(0.0, 1.0));
                        }
                      },
              )
            else ...[
              CustomSlider(
                value: progress,
                trackHeight: 2.5,
                thumbRadius: 5,
                activeColor: ref.accentOrSurface(context),
                inactiveColor: onSurfaceAlpha(0.10),
                thumbColor: ref.accentOrSurface(context),
                onChanged: player.currentTrack == null
                    ? null
                    : (v) {
                        if (duration.inMilliseconds > 0) {
                          notifier.seekPreview(duration * v.clamp(0.0, 1.0));
                        }
                      },
                onChangeEnd: player.currentTrack == null
                    ? null
                    : (v) {
                        if (duration.inMilliseconds > 0) {
                          notifier.seekCommit(duration * v.clamp(0.0, 1.0));
                        }
                      },
              ),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmt(position),
                      style: TextStyle(
                        fontSize: 10,
                        color: onSurfaceAlpha(0.30),
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      _fmt(duration),
                      style: TextStyle(
                        fontSize: 10,
                        color: onSurfaceAlpha(0.22),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: compact ? 10 : 20),

            Row(
              children: [
                if (isM3)
                  M3TransportIcon(
                    icon: Icons.shuffle_rounded,
                    selectedIcon: Icons.shuffle_rounded,
                    selected: player.shuffle,
                    tooltip: 'Shuffle',
                    onPressed: notifier.toggleShuffle,
                  )
                else
                  _IconToggle(
                    icon: Icons.shuffle_rounded,
                    active: player.shuffle,
                    tooltip: 'Shuffle',
                    onTap: notifier.toggleShuffle,
                  ),
                const Spacer(),
                if (isExclusive && !compact)
                  _BitPerfectBadge(onSurface: onSurface),
                const Spacer(),
                if (isM3)
                  M3TransportIcon(
                    icon: switch (player.loopMode) {
                      LoopMode.track => Icons.repeat_one_rounded,
                      _ => Icons.repeat_rounded,
                    },
                    selectedIcon: switch (player.loopMode) {
                      LoopMode.track => Icons.repeat_one_rounded,
                      _ => Icons.repeat_rounded,
                    },
                    selected: player.loopMode != LoopMode.off,
                    tooltip: switch (player.loopMode) {
                      LoopMode.off => 'Repeat',
                      LoopMode.track => 'Repeat track',
                      LoopMode.album => 'Repeat album',
                      LoopMode.playlist => 'Repeat all',
                    },
                    onPressed: notifier.cycleLoopMode,
                  )
                else
                  _LoopButton(
                    mode: player.loopMode,
                    compact: compact,
                    onTap: notifier.cycleLoopMode,
                  ),
              ],
            ),

            SizedBox(height: compact ? 8 : 16),

            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isM3)
                    M3TransportIcon(
                      icon: Icons.skip_previous_rounded,
                      tooltip: 'Previous',
                      onPressed: player.currentTrack == null
                          ? null
                          : notifier.skipPrevious,
                    )
                  else
                    _TransportButton(
                      icon: Icons.skip_previous_rounded,
                      size: skipSize,
                      enabled: player.currentTrack != null,
                      onTap: notifier.skipPrevious,
                    ),
                  SizedBox(width: playGap),
                  if (isM3)
                    M3PlayButton(
                      isPlaying: isPlaying,
                      isLoading: isLoading,
                      hasTrack: player.currentTrack != null,
                      progress: progress,
                      size: compact ? 46 : 56,
                      accentColor: ref.watch(accentColorProvider),
                      onTap: player.currentTrack == null
                          ? null
                          : isPlaying
                          ? notifier.pause
                          : notifier.play,
                    )
                  else
                    _PlayButton(
                      isPlaying: isPlaying,
                      isLoading: isLoading,
                      hasTrack: player.currentTrack != null,
                      isMobile: compact,
                      aq: aq,
                      accentColor: ref.watch(accentColorProvider),
                      onTap: player.currentTrack == null
                          ? null
                          : isPlaying
                          ? notifier.pause
                          : notifier.play,
                    ),
                  SizedBox(width: playGap),
                  if (isM3)
                    M3TransportIcon(
                      icon: Icons.skip_next_rounded,
                      tooltip: 'Next',
                      onPressed: player.currentTrack == null
                          ? null
                          : notifier.skipNext,
                    )
                  else
                    _TransportButton(
                      icon: Icons.skip_next_rounded,
                      size: skipSize,
                      enabled: player.currentTrack != null,
                      onTap: notifier.skipNext,
                    ),
                ],
              ),
            ),

            SizedBox(height: compact ? 12 : 22),

            if (isM3 && !compact)
              const UiDivider(margin: EdgeInsets.symmetric(vertical: 8)),

            Row(
              children: [
                Icon(
                  Icons.volume_mute_rounded,
                  size: 14,
                  color: onSurfaceAlpha(0.20),
                ),
                Expanded(
                  child: CustomSlider(
                    value: player.volume.clamp(0.0, 1.0),
                    trackHeight: 1.5,
                    thumbRadius: 4,
                    activeColor: onSurfaceAlpha(0.38),
                    inactiveColor: onSurfaceAlpha(0.09),
                    thumbColor: onSurfaceAlpha(0.60),
                    onChanged: notifier.setVolume,
                  ),
                ),
                Icon(
                  Icons.volume_up_rounded,
                  size: 14,
                  color: onSurfaceAlpha(0.20),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// Play button
class _PlayButton extends StatefulWidget {
  final bool isPlaying, isLoading, hasTrack, isMobile;
  final AqlossTokens aq;
  final Color? accentColor;
  final VoidCallback? onTap;
  const _PlayButton({
    required this.isPlaying,
    required this.isLoading,
    required this.hasTrack,
    required this.isMobile,
    required this.aq,
    this.accentColor,
    this.onTap,
  });
  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = widget.isMobile ? 46.0 : 58.0;
    final onSurface = widget.aq.onSurface;
    final surface = widget.aq.surface;
    final accent = widget.accentColor ?? onSurface;

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      width: sz,
      height: sz,
      decoration: BoxDecoration(
        color: !widget.hasTrack
            ? onSurface.withValues(alpha: 0.07)
            : _hovered
            ? accent.withValues(alpha: 0.86)
            : accent,
        shape: BoxShape.circle,
        boxShadow: widget.hasTrack
            ? [
                BoxShadow(
                  color: (widget.accentColor ?? Colors.black).withValues(
                    alpha: 0.38,
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: widget.isLoading
          ? Padding(
              padding: EdgeInsets.all(sz * 0.28),
              child: CircularProgressIndicator(strokeWidth: 2, color: surface),
            )
          : Icon(
              widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: widget.hasTrack
                  ? surface
                  : onSurface.withValues(alpha: 0.20),
              size: widget.isMobile ? 24 : 30,
            ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => _scaleCtrl.forward(),
        onTapUp: (_) {
          _scaleCtrl.reverse();
          widget.onTap?.call();
        },
        onTapCancel: () => _scaleCtrl.reverse(),
        child: ScaleTransition(scale: _scaleAnim, child: button),
      ),
    );
  }
}

// Loop button
class _LoopButton extends StatefulWidget {
  final LoopMode mode;
  final bool compact;
  final VoidCallback onTap;
  const _LoopButton({
    required this.mode,
    required this.onTap,
    this.compact = false,
  });
  @override
  State<_LoopButton> createState() => _LoopButtonState();
}

class _LoopButtonState extends State<_LoopButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    Color onSurfaceAlpha(double a) => onSurface.withValues(alpha: a);
    final (icon, label, active) = switch (widget.mode) {
      LoopMode.off => (Icons.repeat_rounded, '', false),
      LoopMode.track => (Icons.repeat_one_rounded, 'Track', true),
      LoopMode.album => (Icons.repeat_rounded, 'Album', true),
      LoopMode.playlist => (Icons.repeat_rounded, 'All', true),
    };
    final tooltip = switch (widget.mode) {
      LoopMode.off => 'Repeat',
      LoopMode.track => 'Repeat track',
      LoopMode.album => 'Repeat album',
      LoopMode.playlist => 'Repeat all',
    };
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: _hovered ? onSurfaceAlpha(0.05) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: active ? onSurface : onSurfaceAlpha(0.20),
                ),
                if (!widget.compact && label.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: active
                          ? onSurfaceAlpha(0.68)
                          : onSurfaceAlpha(0.20),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Icon toggle
class _IconToggle extends StatefulWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;
  const _IconToggle({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });
  @override
  State<_IconToggle> createState() => _IconToggleState();
}

class _IconToggleState extends State<_IconToggle> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    Color onSurfaceAlpha(double a) => onSurface.withValues(alpha: a);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: _hovered
                  ? cs.onSurface.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: widget.active ? onSurface : onSurfaceAlpha(0.20),
            ),
          ),
        ),
      ),
    );
  }
}

// Transport button
class _TransportButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final bool enabled;
  final VoidCallback? onTap;
  const _TransportButton({
    required this.icon,
    required this.size,
    required this.enabled,
    this.onTap,
  });
  @override
  State<_TransportButton> createState() => _TransportButtonState();
}

class _TransportButtonState extends State<_TransportButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    Color onSurfaceAlpha(double a) => onSurface.withValues(alpha: a);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _hovered && widget.enabled
                ? onSurfaceAlpha(0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: widget.enabled
                ? onSurfaceAlpha(_hovered ? 0.82 : 0.52)
                : onSurfaceAlpha(0.10),
          ),
        ),
      ),
    );
  }
}

// Bit-perfect badge
class _BitPerfectBadge extends StatelessWidget {
  final Color onSurface;
  const _BitPerfectBadge({required this.onSurface});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'WASAPI Exclusive – bit-perfect output',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: onSurface.withValues(alpha: 0.10)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'BIT-PERFECT',
        style: TextStyle(
          fontSize: 7.5,
          color: onSurface.withValues(alpha: 0.25),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    ),
  );
}
