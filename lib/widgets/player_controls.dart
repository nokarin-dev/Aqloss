import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/widgets/custom_slider.dart';
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
          trackHeight: 2,
          thumbRadius: 5,
          activeColor: cs.onSurface,
          inactiveColor: cs.onSurface.withValues(alpha: 0.10),
          thumbColor: cs.onSurface,
          onChanged: player.currentTrack == null
              ? null
              : (v) {
                  if (duration.inMilliseconds > 0) {
                    notifier.seek(duration * v.clamp(0.0, 1.0));
                  }
                },
        ),

        const SizedBox(height: 4),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(position),
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurface.withValues(alpha: 0.22),
                ),
              ),
              Text(
                _fmt(duration),
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurface.withValues(alpha: 0.22),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: isMobile ? 14 : 18),

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

        SizedBox(height: isMobile ? 12 : 14),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _TransportButton(
              icon: Icons.skip_previous_rounded,
              size: isMobile ? 26 : 28,
              enabled: player.currentTrack != null,
              onTap: notifier.skipPrevious,
            ),
            SizedBox(width: isMobile ? 20 : 24),
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
            SizedBox(width: isMobile ? 20 : 24),
            _TransportButton(
              icon: Icons.skip_next_rounded,
              size: isMobile ? 26 : 28,
              enabled: player.currentTrack != null,
              onTap: notifier.skipNext,
            ),
          ],
        ),

        SizedBox(height: isMobile ? 16 : 20),

        // Volume
        Row(
          children: [
            Icon(
              Icons.volume_down_rounded,
              size: 13,
              color: cs.onSurface.withValues(alpha: 0.22),
            ),
            Expanded(
              child: CustomSlider(
                value: player.volume.clamp(0.0, 1.0),
                trackHeight: 1.5,
                thumbRadius: 4,
                activeColor: cs.onSurface.withValues(alpha: 0.38),
                inactiveColor: cs.onSurface.withValues(alpha: 0.10),
                thumbColor: cs.onSurface.withValues(alpha: 0.58),
                onChanged: notifier.setVolume,
              ),
            ),
            Icon(
              Icons.volume_up_rounded,
              size: 13,
              color: cs.onSurface.withValues(alpha: 0.22),
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

class _PlayButtonState extends State<_PlayButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final sz = widget.isMobile ? 52.0 : 56.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: sz,
          height: sz,
          decoration: BoxDecoration(
            color: !widget.hasTrack
                ? widget.cs.onSurface.withValues(alpha: 0.08)
                : _hovered
                ? widget.cs.onSurface.withValues(alpha: 0.88)
                : widget.cs.onSurface,
            shape: BoxShape.circle,
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
                      : widget.cs.onSurface.withValues(alpha: 0.22),
                  size: widget.isMobile ? 26 : 28,
                ),
        ),
      ),
    );
  }
}

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
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered
                ? cs.onSurface.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: active
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.22),
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: active
                        ? cs.onSurface.withValues(alpha: 0.70)
                        : cs.onSurface.withValues(alpha: 0.22),
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
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: _hovered
                  ? cs.onSurface.withValues(alpha: 0.06)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 17,
              color: widget.active
                  ? cs.onSurface
                  : cs.onSurface.withValues(alpha: 0.22),
            ),
          ),
        ),
      ),
    );
  }
}

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
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hovered && widget.enabled
                ? cs.onSurface.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: widget.enabled
                ? cs.onSurface.withValues(alpha: _hovered ? 0.80 : 0.54)
                : cs.onSurface.withValues(alpha: 0.12),
          ),
        ),
      ),
    );
  }
}

class _BitPerfectBadge extends StatelessWidget {
  final ColorScheme cs;
  const _BitPerfectBadge({required this.cs});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'WASAPI Exclusive – bit-perfect output',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        'BIT-PERFECT',
        style: TextStyle(
          fontSize: 7,
          color: cs.onSurface.withValues(alpha: 0.28),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    ),
  );
}
