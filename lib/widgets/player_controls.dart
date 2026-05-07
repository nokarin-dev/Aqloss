import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/player_provider.dart';
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

    final double progress;
    if (duration.inMilliseconds > 0 && player.currentTrack != null) {
      progress = (position.inMilliseconds / duration.inMilliseconds)
          .clamp(0.0, 1.0)
          .toDouble();
    } else {
      progress = 0.0;
    }

    final isExclusive = backend.isExclusiveMode();

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            activeTrackColor: cs.onSurface,
            inactiveTrackColor: cs.onSurface.withValues(alpha: 0.10),
            thumbColor: cs.onSurface,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            overlayColor: cs.onSurface.withValues(alpha: 0.10),
          ),
          child: Slider(
            value: progress,
            onChanged: player.currentTrack == null
                ? null
                : (v) {
                    if (duration.inMilliseconds > 0) {
                      notifier.seek(duration * v.clamp(0.0, 1.0));
                    }
                  },
          ),
        ),

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

            if (isExclusive)
              Tooltip(
                message: 'WASAPI Exclusive - bit-perfect output',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: cs.onSurface.withValues(alpha: 0.10),
                    ),
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
              ),

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

            GestureDetector(
              onTap: player.currentTrack == null
                  ? null
                  : isPlaying
                  ? notifier.pause
                  : notifier.play,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: isMobile ? 52 : 56,
                height: isMobile ? 52 : 56,
                decoration: BoxDecoration(
                  color: player.currentTrack == null
                      ? cs.onSurface.withValues(alpha: 0.08)
                      : cs.onSurface,
                  shape: BoxShape.circle,
                ),
                child: isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(17),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.surface,
                        ),
                      )
                    : Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: player.currentTrack == null
                            ? cs.onSurface.withValues(alpha: 0.22)
                            : cs.surface,
                        size: isMobile ? 26 : 28,
                      ),
              ),
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

        Row(
          children: [
            Icon(
              Icons.volume_down_rounded,
              size: 13,
              color: cs.onSurface.withValues(alpha: 0.22),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 1.5,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 3,
                  ),
                  activeTrackColor: cs.onSurface.withValues(alpha: 0.36),
                  inactiveTrackColor: cs.onSurface.withValues(alpha: 0.10),
                  thumbColor: cs.onSurface.withValues(alpha: 0.54),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 10,
                  ),
                  overlayColor: cs.onSurface.withValues(alpha: 0.08),
                ),
                child: Slider(
                  value: player.volume.clamp(0.0, 1.0),
                  onChanged: notifier.setVolume,
                ),
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

class _LoopButton extends StatelessWidget {
  final LoopMode mode;
  final VoidCallback onTap;
  const _LoopButton({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, label, active) = switch (mode) {
      LoopMode.off => (Icons.repeat_rounded, '', false),
      LoopMode.track => (Icons.repeat_one_rounded, 'Track', true),
      LoopMode.album => (Icons.repeat_rounded, 'Album', true),
      LoopMode.playlist => (Icons.repeat_rounded, 'All', true),
    };

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
    );
  }
}

class _IconToggle extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Icon(
            icon,
            size: 17,
            color: active ? cs.onSurface : cs.onSurface.withValues(alpha: 0.22),
          ),
        ),
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(icon),
      iconSize: size,
      color: enabled
          ? cs.onSurface.withValues(alpha: 0.54)
          : cs.onSurface.withValues(alpha: 0.12),
      splashRadius: 20,
      onPressed: enabled ? onTap : null,
    );
  }
}
