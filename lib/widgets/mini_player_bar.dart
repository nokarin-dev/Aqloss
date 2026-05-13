import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:aqloss/models/track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

class MiniPlayerBar extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  const MiniPlayerBar({super.key, required this.onTap});

  @override
  ConsumerState<MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends ConsumerState<MiniPlayerBar> {
  Uint8List? _artBytes;
  String? _loadedPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final path = ref.read(playerProvider).currentTrack?.path;
    if (path != _loadedPath) _loadArt(path);
  }

  Future<void> _loadArt(String? path) async {
    if (path == null) {
      if (mounted) {
        setState(() {
          _artBytes = null;
          _loadedPath = null;
        });
      }
      return;
    }
    _loadedPath = path;
    try {
      final bytes = await backend.readAlbumArt(path: path);
      if (mounted && _loadedPath == path) {
        setState(
          () => _artBytes = bytes != null ? Uint8List.fromList(bytes) : null,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _artBytes = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final track = player.currentTrack;
    if (track == null) return const SizedBox.shrink();

    if (track.path != _loadedPath) {
      Future.microtask(() => _loadArt(track.path));
    }

    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    return isDesktop
        ? _DesktopBar(
            artBytes: _artBytes,
            notifier: notifier,
            player: player,
            onTap: widget.onTap,
          )
        : _MobileBar(
            artBytes: _artBytes,
            notifier: notifier,
            player: player,
            onTap: widget.onTap,
          );
  }
}

// Desktop bar
class _DesktopBar extends ConsumerWidget {
  final Uint8List? artBytes;
  final PlayerNotifier notifier;
  final PlayerState player;
  final VoidCallback onTap;

  const _DesktopBar({
    required this.artBytes,
    required this.notifier,
    required this.player,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final track = player.currentTrack!;
    final isPlaying = player.status == PlayerStatus.playing;
    final isLoading = player.status == PlayerStatus.loading;
    final duration = track.duration;
    final progress = duration.inMilliseconds > 0
        ? (player.position.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    final isExclusive = backend.isExclusiveMode();

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seekbar
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: SliderComponentShape.noThumb,
              overlayShape: SliderComponentShape.noOverlay,
              activeTrackColor: cs.onSurface.withValues(alpha: 0.54),
              inactiveTrackColor: cs.onSurface.withValues(alpha: 0.08),
            ),
            child: SizedBox(
              height: 14,
              child: Slider(
                value: progress,
                onChanged: (v) {
                  if (duration.inMilliseconds > 0) notifier.seek(duration * v);
                },
              ),
            ),
          ),

          // Main bar row
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 12, 8),
            child: Row(
              children: [
                // Album art
                GestureDetector(
                  onTap: onTap,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: Container(
                      key: ValueKey(track.path),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: cs.onSurface.withValues(alpha: 0.06),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: artBytes != null
                          ? Image.memory(artBytes!, fit: BoxFit.cover)
                          : Center(
                              child: Icon(
                                Icons.music_note_rounded,
                                size: 14,
                                color: cs.onSurface.withValues(alpha: 0.22),
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Track info
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: onTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track.displayTitle,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          track.displayArtist,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.38),
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Transport controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BarBtn(
                      icon: Icons.shuffle_rounded,
                      active: player.shuffle,
                      size: 14,
                      tooltip: 'Shuffle',
                      onTap: notifier.toggleShuffle,
                    ),
                    const SizedBox(width: 2),
                    _BarBtn(
                      icon: Icons.skip_previous_rounded,
                      size: 18,
                      tooltip: 'Previous',
                      onTap: notifier.skipPrevious,
                    ),
                    const SizedBox(width: 2),
                    _PlayBtn(
                      isPlaying: isPlaying,
                      isLoading: isLoading,
                      enabled: true,
                      cs: cs,
                      onTap: isPlaying ? notifier.pause : notifier.play,
                    ),
                    const SizedBox(width: 2),
                    _BarBtn(
                      icon: Icons.skip_next_rounded,
                      size: 18,
                      tooltip: 'Next',
                      onTap: notifier.skipNext,
                    ),
                    const SizedBox(width: 2),
                    _LoopBtn(
                      mode: player.loopMode,
                      onTap: notifier.cycleLoopMode,
                    ),
                  ],
                ),

                const SizedBox(width: 12),

                // Time
                Text(
                  _fmt(player.position),
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: cs.onSurface.withValues(alpha: 0.38),
                  ),
                ),
                Text(
                  ' / ',
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.withValues(alpha: 0.20),
                  ),
                ),
                Text(
                  _fmt(duration),
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: cs.onSurface.withValues(alpha: 0.22),
                  ),
                ),

                const SizedBox(width: 12),

                // Format badge
                if (isExclusive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: cs.onSurface.withValues(alpha: 0.12),
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
                  )
                else
                  _FormatBadge(track: track, cs: cs),

                const SizedBox(width: 10),

                // Volume
                Icon(
                  Icons.volume_down_rounded,
                  size: 13,
                  color: cs.onSurface.withValues(alpha: 0.22),
                ),
                SizedBox(
                  width: 80,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 1.5,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 3,
                      ),
                      activeTrackColor: cs.onSurface.withValues(alpha: 0.40),
                      inactiveTrackColor: cs.onSurface.withValues(alpha: 0.10),
                      thumbColor: cs.onSurface.withValues(alpha: 0.60),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 8,
                      ),
                      overlayColor: cs.onSurface.withValues(alpha: 0.08),
                    ),
                    child: Slider(
                      value: player.volume.clamp(0.0, 1.0),
                      onChanged: notifier.setVolume,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// Mobile bar
class _MobileBar extends StatelessWidget {
  final Uint8List? artBytes;
  final PlayerNotifier notifier;
  final PlayerState player;
  final VoidCallback onTap;

  const _MobileBar({
    required this.artBytes,
    required this.notifier,
    required this.player,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final track = player.currentTrack!;
    final isPlaying = player.status == PlayerStatus.playing;
    final duration = track.duration;
    final progress = duration.inMilliseconds > 0
        ? (player.position.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          border: Border(top: BorderSide(color: cs.outline)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 1.5,
                thumbShape: SliderComponentShape.noThumb,
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: cs.onSurface.withValues(alpha: 0.36),
                inactiveTrackColor: cs.onSurface.withValues(alpha: 0.08),
              ),
              child: Slider(
                value: progress,
                onChanged: (v) {
                  if (duration.inMilliseconds > 0) notifier.seek(duration * v);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 6, 8),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: Container(
                      key: ValueKey(track.path),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: cs.onSurface.withValues(alpha: 0.06),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: artBytes != null
                          ? Image.memory(artBytes!, fit: BoxFit.cover)
                          : Center(
                              child: Icon(
                                Icons.music_note_rounded,
                                size: 14,
                                color: cs.onSurface.withValues(alpha: 0.22),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track.displayTitle,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          track.displayArtist,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.36),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _BarBtn(
                    icon: Icons.skip_previous_rounded,
                    size: 20,
                    tooltip: 'Previous',
                    onTap: notifier.skipPrevious,
                  ),
                  _PlayBtn(
                    isPlaying: isPlaying,
                    isLoading: false,
                    enabled: true,
                    cs: cs,
                    small: true,
                    onTap: isPlaying ? notifier.pause : notifier.play,
                  ),
                  _BarBtn(
                    icon: Icons.skip_next_rounded,
                    size: 20,
                    tooltip: 'Next',
                    onTap: notifier.skipNext,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared components ─────────────────────────────────────────────────────────

class _PlayBtn extends StatelessWidget {
  final bool isPlaying, isLoading, enabled;
  final bool small;
  final ColorScheme cs;
  final VoidCallback? onTap;

  const _PlayBtn({
    required this.isPlaying,
    required this.isLoading,
    required this.enabled,
    required this.cs,
    required this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final sz = small ? 32.0 : 34.0;
    final iconSz = small ? 18.0 : 20.0;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: sz,
        height: sz,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(color: cs.onSurface, shape: BoxShape.circle),
        child: isLoading
            ? Padding(
                padding: const EdgeInsets.all(9),
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: cs.surface,
                ),
              )
            : Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: cs.surface,
                size: iconSz,
              ),
      ),
    );
  }
}

class _BarBtn extends StatefulWidget {
  final IconData icon;
  final double size;
  final bool active;
  final String tooltip;
  final VoidCallback? onTap;

  const _BarBtn({
    required this.icon,
    required this.size,
    required this.tooltip,
    this.active = false,
    this.onTap,
  });

  @override
  State<_BarBtn> createState() => _BarBtnState();
}

class _BarBtnState extends State<_BarBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.tooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: _hovered
                  ? cs.onSurface.withValues(alpha: 0.06)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: widget.size,
              color: widget.active
                  ? cs.onSurface
                  : cs.onSurface.withValues(alpha: _hovered ? 0.70 : 0.42),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoopBtn extends StatefulWidget {
  final LoopMode mode;
  final VoidCallback onTap;
  const _LoopBtn({required this.mode, required this.onTap});
  @override
  State<_LoopBtn> createState() => _LoopBtnState();
}

class _LoopBtnState extends State<_LoopBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, label, active) = switch (widget.mode) {
      LoopMode.off => (Icons.repeat_rounded, '', false),
      LoopMode.track => (Icons.repeat_one_rounded, '1', true),
      LoopMode.album => (Icons.repeat_rounded, 'A', true),
      LoopMode.playlist => (Icons.repeat_rounded, '∞', true),
    };
    return Tooltip(
      message: switch (widget.mode) {
        LoopMode.off => 'Loop: off',
        LoopMode.track => 'Loop: track',
        LoopMode.album => 'Loop: album',
        LoopMode.playlist => 'Loop: all',
      },
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
                  size: 14,
                  color: active
                      ? cs.onSurface
                      : cs.onSurface.withValues(alpha: 0.42),
                ),
                if (label.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      color: active
                          ? cs.onSurface
                          : cs.onSurface.withValues(alpha: 0.42),
                      fontWeight: FontWeight.w700,
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

class _FormatBadge extends StatelessWidget {
  final Track track;
  final ColorScheme cs;
  const _FormatBadge({required this.track, required this.cs});
  @override
  Widget build(BuildContext context) {
    final khz = (track.sampleRate / 1000).toStringAsFixed(
      track.sampleRate % 1000 == 0 ? 0 : 1,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        '${track.format} · ${khz}kHz',
        style: TextStyle(
          fontSize: 8,
          letterSpacing: 0.3,
          color: cs.onSurface.withValues(alpha: 0.24),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
