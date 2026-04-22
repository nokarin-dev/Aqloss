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
        // Seek bar
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white12,
            thumbColor: Colors.white,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            overlayColor: Colors.white10,
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

        // Time labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(position),
                style: const TextStyle(fontSize: 11, color: Colors.white24),
              ),
              Text(
                _fmt(duration),
                style: const TextStyle(fontSize: 11, color: Colors.white24),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

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
                message: 'WASAPI Exclusive — bit-perfect output',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'BIT-PERFECT',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.white30,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),

            const Spacer(),

            _LoopButton(mode: player.loopMode, onTap: notifier.cycleLoopMode),
          ],
        ),

        const SizedBox(height: 16),

        // Transport
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Prev
            _TransportButton(
              icon: Icons.skip_previous_rounded,
              size: 28,
              enabled: player.currentTrack != null,
              onTap: notifier.skipPrevious,
            ),

            const SizedBox(width: 24),

            // Play/Pause
            GestureDetector(
              onTap: player.currentTrack == null
                  ? null
                  : isPlaying
                  ? notifier.pause
                  : notifier.play,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: player.currentTrack == null
                      ? Colors.white10
                      : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: player.currentTrack == null
                            ? Colors.white24
                            : Colors.black,
                        size: 28,
                      ),
              ),
            ),

            const SizedBox(width: 24),

            // Next
            _TransportButton(
              icon: Icons.skip_next_rounded,
              size: 28,
              enabled: player.currentTrack != null,
              onTap: notifier.skipNext,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Volume
        Row(
          children: [
            const Icon(
              Icons.volume_down_rounded,
              size: 14,
              color: Colors.white24,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 1.5,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 3,
                  ),
                  activeTrackColor: Colors.white38,
                  inactiveTrackColor: Colors.white12,
                  thumbColor: Colors.white54,
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 10,
                  ),
                  overlayColor: Colors.white10,
                ),
                child: Slider(
                  value: player.volume.clamp(0.0, 1.0),
                  onChanged: notifier.setVolume,
                ),
              ),
            ),
            const Icon(
              Icons.volume_up_rounded,
              size: 14,
              color: Colors.white24,
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

// Loop button
class _LoopButton extends StatelessWidget {
  final LoopMode mode;
  final VoidCallback onTap;
  const _LoopButton({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
            Icon(icon, size: 18, color: active ? Colors.white : Colors.white24),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: active ? Colors.white70 : Colors.white24,
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

// Generic icon toggle
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
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Icon(
            icon,
            size: 18,
            color: active ? Colors.white : Colors.white24,
          ),
        ),
      ),
    );
  }
}

// Transport button
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
    return IconButton(
      icon: Icon(icon),
      iconSize: size,
      color: enabled ? Colors.white54 : Colors.white12,
      splashRadius: 20,
      onPressed: enabled ? onTap : null,
    );
  }
}
