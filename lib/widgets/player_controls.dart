import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/widgets/shared/custom_slider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final isPlaying = player.status == PlayerStatus.playing;
    final isLoading = player.status == PlayerStatus.loading;
    final duration = player.currentTrack?.duration ?? Duration.zero;
    final position = player.position;
    final cs = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 700;

    final double progress =
        duration.inMilliseconds > 0 && player.currentTrack != null
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final isExclusive = backend.isExclusiveMode();

    return Column(
      children: [
        // Seek bar
        CustomSlider(
          value: progress,
          trackHeight: 2.5,
          thumbRadius: 5,
          activeColor: cs.onSurface,
          inactiveColor: cs.onSurface.withValues(alpha: 0.10),
          thumbColor: cs.onSurface,
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

        // Time labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(position),
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurface.withValues(alpha: 0.30),
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                _fmt(duration),
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurface.withValues(alpha: 0.22),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: isMobile ? 16 : 20),

        // Shuffle / bit-perfect / loop row
        Row(
          children: [
            _IconToggle(
              icon: Icons.shuffle_rounded,
              active: player.shuffle,
              tooltip: 'Shuffle',
              onTap: notifier.toggleShuffle,
            ),
            const Spacer(),
            if (isExclusive) _BitPerfectBadge(cs: cs),
            const Spacer(),
            _LoopButton(mode: player.loopMode, onTap: notifier.cycleLoopMode),
          ],
        ),

        SizedBox(height: isMobile ? 14 : 16),

        // Transport controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _TransportButton(
              icon: Icons.skip_previous_rounded,
              size: isMobile ? 27 : 29,
              enabled: player.currentTrack != null,
              onTap: notifier.skipPrevious,
            ),
            SizedBox(width: isMobile ? 22 : 26),
            _PlayButton(
              isPlaying: isPlaying,
              isLoading: isLoading,
              hasTrack: player.currentTrack != null,
              isMobile: isMobile,
              cs: cs,
              onTap: player.currentTrack == null
                  ? null
                  : isPlaying
                  ? notifier.pause
                  : notifier.play,
            ),
            SizedBox(width: isMobile ? 22 : 26),
            _TransportButton(
              icon: Icons.skip_next_rounded,
              size: isMobile ? 27 : 29,
              enabled: player.currentTrack != null,
              onTap: notifier.skipNext,
            ),
          ],
        ),

        SizedBox(height: isMobile ? 18 : 22),

        // Volume
        Row(
          children: [
            Icon(
              Icons.volume_mute_rounded,
              size: 14,
              color: cs.onSurface.withValues(alpha: 0.20),
            ),
            Expanded(
              child: CustomSlider(
                value: player.volume.clamp(0.0, 1.0),
                trackHeight: 1.5,
                thumbRadius: 4,
                activeColor: cs.onSurface.withValues(alpha: 0.38),
                inactiveColor: cs.onSurface.withValues(alpha: 0.09),
                thumbColor: cs.onSurface.withValues(alpha: 0.60),
                onChanged: notifier.setVolume,
              ),
            ),
            Icon(
              Icons.volume_up_rounded,
              size: 14,
              color: cs.onSurface.withValues(alpha: 0.20),
            ),
          ],
        ),
      ],
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
  final ColorScheme cs;
  final VoidCallback? onTap;
  const _PlayButton({
    required this.isPlaying,
    required this.isLoading,
    required this.hasTrack,
    required this.isMobile,
    required this.cs,
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
    final sz = widget.isMobile ? 54.0 : 58.0;
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
        child: ScaleTransition(
          scale: _scaleAnim,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            width: sz,
            height: sz,
            decoration: BoxDecoration(
              color: !widget.hasTrack
                  ? widget.cs.onSurface.withValues(alpha: 0.07)
                  : _hovered
                  ? widget.cs.onSurface.withValues(alpha: 0.86)
                  : widget.cs.onSurface,
              shape: BoxShape.circle,
              boxShadow: widget.hasTrack
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: widget.isLoading
                ? Padding(
                    padding: const EdgeInsets.all(17),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.cs.surface,
                    ),
                  )
                : Icon(
                    widget.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: widget.hasTrack
                        ? widget.cs.surface
                        : widget.cs.onSurface.withValues(alpha: 0.20),
                    size: widget.isMobile ? 27 : 30,
                  ),
          ),
        ),
      ),
    );
  }
}

// Loop button
class _LoopButton extends StatefulWidget {
  final LoopMode mode;
  final VoidCallback onTap;
  const _LoopButton({required this.mode, required this.onTap});
  @override
  State<_LoopButton> createState() => _LoopButtonState();
}

class _LoopButtonState extends State<_LoopButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, label, active) = switch (widget.mode) {
      LoopMode.off => (Icons.repeat_rounded, '', false),
      LoopMode.track => (Icons.repeat_one_rounded, 'Track', true),
      LoopMode.album => (Icons.repeat_rounded, 'Album', true),
      LoopMode.playlist => (Icons.repeat_rounded, 'All', true),
    };
    return MouseRegion(
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: active
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.20),
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: active
                        ? cs.onSurface.withValues(alpha: 0.68)
                        : cs.onSurface.withValues(alpha: 0.20),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
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
    final cs = Theme.of(context).colorScheme;
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
              color: widget.active
                  ? cs.onSurface
                  : cs.onSurface.withValues(alpha: 0.20),
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
    final cs = Theme.of(context).colorScheme;
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
                ? cs.onSurface.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: widget.enabled
                ? cs.onSurface.withValues(alpha: _hovered ? 0.82 : 0.52)
                : cs.onSurface.withValues(alpha: 0.10),
          ),
        ),
      ),
    );
  }
}

// Bit-perfect badge
class _BitPerfectBadge extends StatelessWidget {
  final ColorScheme cs;
  const _BitPerfectBadge({required this.cs});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'WASAPI Exclusive – bit-perfect output',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'BIT-PERFECT',
        style: TextStyle(
          fontSize: 7.5,
          color: cs.onSurface.withValues(alpha: 0.25),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    ),
  );
}
