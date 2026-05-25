import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:aqloss/models/track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/widgets/shared/custom_slider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/providers/settings_provider.dart';

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
    final track = player.currentTrack;
    if (track == null) return const SizedBox.shrink();

    if (track.path != _loadedPath) {
      Future.microtask(() => _loadArt(track.path));
    }

    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    return isDesktop
        ? _DesktopBar(artBytes: _artBytes, player: player, onTap: widget.onTap)
        : _MobileBar(artBytes: _artBytes, player: player, onTap: widget.onTap);
  }
}

// Desktop bar
class _DesktopBar extends ConsumerWidget {
  final Uint8List? artBytes;
  final PlayerState player;
  final VoidCallback onTap;
  const _DesktopBar({
    required this.artBytes,
    required this.player,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final notifier = ref.read(playerProvider.notifier);
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
    final isIslands = ref.watch(settingsProvider).appStyle == AppStyle.islands;

    final content = _DesktopBarContent(
      artBytes: artBytes,
      player: player,
      track: track,
      notifier: notifier,
      isPlaying: isPlaying,
      isLoading: isLoading,
      isExclusive: isExclusive,
      duration: duration,
      progress: progress,
      cs: cs,
      onTap: onTap,
    );

    if (isIslands) {
      return Container(
        margin: const EdgeInsets.fromLTRB(0, 0, 5, 5),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.06)),
        ),
        child: content,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: cs.onSurface.withValues(alpha: 0.06)),
        ),
      ),
      child: content,
    );
  }
}

class _DesktopBarContent extends StatelessWidget {
  final Uint8List? artBytes;
  final PlayerState player;
  final Track track;
  final PlayerNotifier notifier;
  final bool isPlaying, isLoading, isExclusive;
  final Duration duration;
  final double progress;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _DesktopBarContent({
    required this.artBytes,
    required this.player,
    required this.track,
    required this.notifier,
    required this.isPlaying,
    required this.isLoading,
    required this.isExclusive,
    required this.duration,
    required this.progress,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Track info
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: SizedBox(
                width: 210,
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOut,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(
                          scale: Tween(begin: 0.94, end: 1.0).animate(anim),
                          child: child,
                        ),
                      ),
                      child: _ArtBox(
                        key: ValueKey(track.path),
                        artBytes: artBytes,
                        cs: cs,
                        size: 44,
                        radius: 7,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            track.displayTitle,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            track.displayArtist,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.38),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          _InlineBadge(
                            isExclusive
                                ? 'BIT-PERFECT'
                                : '${track.format} · ${_khz(track.sampleRate)}',
                            cs,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Center
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MiniBtn(
                      icon: Icons.shuffle_rounded,
                      size: 15,
                      active: player.shuffle,
                      tooltip: 'Shuffle',
                      onTap: notifier.toggleShuffle,
                    ),
                    const SizedBox(width: 4),
                    _MiniBtn(
                      icon: Icons.skip_previous_rounded,
                      size: 20,
                      tooltip: 'Previous',
                      onTap: notifier.skipPrevious,
                    ),
                    const SizedBox(width: 6),
                    _MiniPlayBtn(
                      isPlaying: isPlaying,
                      isLoading: isLoading,
                      cs: cs,
                      onTap: isPlaying ? notifier.pause : notifier.play,
                    ),
                    const SizedBox(width: 6),
                    _MiniBtn(
                      icon: Icons.skip_next_rounded,
                      size: 20,
                      tooltip: 'Next',
                      onTap: notifier.skipNext,
                    ),
                    const SizedBox(width: 4),
                    _MiniLoopBtn(
                      mode: player.loopMode,
                      onTap: notifier.cycleLoopMode,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const SizedBox(width: 16),
                    Text(
                      _fmt(player.position),
                      style: TextStyle(
                        fontSize: 9.5,
                        color: cs.onSurface.withValues(alpha: 0.38),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: CustomSlider(
                        value: progress,
                        trackHeight: 2,
                        showThumb: false,
                        activeColor: cs.onSurface.withValues(alpha: 0.45),
                        inactiveColor: cs.onSurface.withValues(alpha: 0.08),
                        onChanged: (v) {
                          if (duration.inMilliseconds > 0) {
                            notifier.seekPreview(duration * v);
                          }
                        },
                        onChangeEnd: (v) {
                          if (duration.inMilliseconds > 0) {
                            notifier.seekCommit(duration * v);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _fmt(duration),
                      style: TextStyle(
                        fontSize: 9.5,
                        color: cs.onSurface.withValues(alpha: 0.22),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ],
            ),
          ),

          // Volume
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.volume_down_rounded,
                size: 15,
                color: cs.onSurface.withValues(alpha: 0.20),
              ),
              SizedBox(
                width: 110,
                child: CustomSlider(
                  value: player.volume.clamp(0.0, 1.0),
                  trackHeight: 1.5,
                  thumbRadius: 4,
                  activeColor: cs.onSurface.withValues(alpha: 0.36),
                  inactiveColor: cs.onSurface.withValues(alpha: 0.08),
                  thumbColor: cs.onSurface.withValues(alpha: 0.58),
                  onChanged: notifier.setVolume,
                ),
              ),
              Icon(
                Icons.volume_up_rounded,
                size: 15,
                color: cs.onSurface.withValues(alpha: 0.20),
              ),
            ],
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

  String _khz(int sr) =>
      '${(sr / 1000).toStringAsFixed(sr % 1000 == 0 ? 0 : 1)}kHz';
}

// Mobile bar
class _MobileBar extends ConsumerWidget {
  final Uint8List? artBytes;
  final PlayerState player;
  final VoidCallback onTap;
  const _MobileBar({
    required this.artBytes,
    required this.player,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final notifier = ref.read(playerProvider.notifier);
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
          border: Border(
            top: BorderSide(color: cs.onSurface.withValues(alpha: 0.06)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Seek bar
            CustomSlider(
              value: progress,
              trackHeight: 1.5,
              showThumb: false,
              activeColor: cs.onSurface.withValues(alpha: 0.32),
              inactiveColor: cs.onSurface.withValues(alpha: 0.07),
              onChanged: (v) {
                if (duration.inMilliseconds > 0) {
                  notifier.seekPreview(duration * v);
                }
              },
              onChangeEnd: (v) {
                if (duration.inMilliseconds > 0) {
                  notifier.seekCommit(duration * v);
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 6, 8, 8),
              child: Row(
                children: [
                  _ArtBox(artBytes: artBytes, cs: cs, size: 36, radius: 6),
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
                            color: cs.onSurface.withValues(alpha: 0.34),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _MiniBtn(
                    icon: Icons.skip_previous_rounded,
                    size: 20,
                    tooltip: '',
                    onTap: notifier.skipPrevious,
                  ),
                  _MiniPlayBtn(
                    isPlaying: isPlaying,
                    isLoading: false,
                    cs: cs,
                    small: true,
                    onTap: isPlaying ? notifier.pause : notifier.play,
                  ),
                  _MiniBtn(
                    icon: Icons.skip_next_rounded,
                    size: 20,
                    tooltip: '',
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

// Shared sub widgets
class _ArtBox extends StatelessWidget {
  final Uint8List? artBytes;
  final ColorScheme cs;
  final double size, radius;
  const _ArtBox({
    super.key,
    required this.artBytes,
    required this.cs,
    required this.size,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: cs.onSurface.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: cs.onSurface.withValues(alpha: 0.06)),
    ),
    clipBehavior: Clip.antiAlias,
    child: artBytes != null
        ? Image.memory(artBytes!, fit: BoxFit.cover)
        : Center(
            child: Icon(
              Icons.music_note_rounded,
              size: size * 0.35,
              color: cs.onSurface.withValues(alpha: 0.18),
            ),
          ),
  );
}

class _InlineBadge extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  const _InlineBadge(this.text, this.cs);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      border: Border.all(color: cs.onSurface.withValues(alpha: 0.09)),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 8,
        letterSpacing: 0.3,
        color: cs.onSurface.withValues(alpha: 0.26),
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _MiniPlayBtn extends StatefulWidget {
  final bool isPlaying, isLoading, small;
  final ColorScheme cs;
  final VoidCallback? onTap;
  const _MiniPlayBtn({
    required this.isPlaying,
    required this.isLoading,
    required this.cs,
    required this.onTap,
    this.small = false,
  });

  @override
  State<_MiniPlayBtn> createState() => _MiniPlayBtnState();
}

class _MiniPlayBtnState extends State<_MiniPlayBtn>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _pressAnim = Tween(
      begin: 1.0,
      end: 0.90,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = widget.small ? 32.0 : 36.0;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) {
          _pressCtrl.reverse();
          widget.onTap?.call();
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: ScaleTransition(
          scale: _pressAnim,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: sz,
            height: sz,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.cs.onSurface.withValues(alpha: 0.88)
                  : widget.cs.onSurface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: widget.isLoading
                ? Padding(
                    padding: const EdgeInsets.all(9),
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: widget.cs.surface,
                    ),
                  )
                : Icon(
                    widget.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: widget.cs.surface,
                    size: widget.small ? 20 : 22,
                  ),
          ),
        ),
      ),
    );
  }
}

class _MiniBtn extends StatefulWidget {
  final IconData icon;
  final double size;
  final bool active;
  final String tooltip;
  final VoidCallback? onTap;
  const _MiniBtn({
    required this.icon,
    required this.size,
    required this.tooltip,
    this.active = false,
    this.onTap,
  });

  @override
  State<_MiniBtn> createState() => _MiniBtnState();
}

class _MiniBtnState extends State<_MiniBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final child = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          padding: const EdgeInsets.all(6),
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
                : cs.onSurface.withValues(alpha: _hovered ? 0.68 : 0.42),
          ),
        ),
      ),
    );
    if (widget.tooltip.isEmpty) return child;
    return Tooltip(
      message: widget.tooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 600),
      child: child,
    );
  }
}

class _MiniLoopBtn extends StatefulWidget {
  final LoopMode mode;
  final VoidCallback onTap;
  const _MiniLoopBtn({required this.mode, required this.onTap});

  @override
  State<_MiniLoopBtn> createState() => _MiniLoopBtnState();
}

class _MiniLoopBtnState extends State<_MiniLoopBtn> {
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
    final tip = switch (widget.mode) {
      LoopMode.off => 'Loop: off',
      LoopMode.track => 'Loop: track',
      LoopMode.album => 'Loop: album',
      LoopMode.playlist => 'Loop: all',
    };
    return Tooltip(
      message: tip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            padding: const EdgeInsets.all(6),
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
                  size: 15,
                  color: active
                      ? cs.onSurface
                      : cs.onSurface.withValues(alpha: 0.40),
                ),
                if (label.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      color: active
                          ? cs.onSurface
                          : cs.onSurface.withValues(alpha: 0.40),
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
