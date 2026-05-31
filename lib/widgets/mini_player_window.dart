import 'dart:io';
import 'dart:typed_data';

import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:window_manager/window_manager.dart';

final miniPlayerActiveProvider = StateProvider<bool>((ref) => false);

const _kMiniSize = Size(320, 80);
const _kNormalMin = Size(1100, 700);
const _kNormalSize = Size(1100, 700);

class MiniPlayerWindow {
  MiniPlayerWindow._();

  static bool _active = false;

  static Future<void> toggle(BuildContext context) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    _active = !_active;

    final container = ProviderScope.containerOf(context, listen: false);
    container.read(miniPlayerActiveProvider.notifier).state = _active;

    if (_active) {
      await windowManager.setMinimumSize(_kMiniSize);
      await windowManager.setSize(_kMiniSize);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setResizable(false);
    } else {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setResizable(true);
      await windowManager.setMinimumSize(_kNormalMin);
      await windowManager.setSize(_kNormalSize);
    }
  }
}

// Floating mini player widget
class MiniPlayerView extends ConsumerWidget {
  const MiniPlayerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final cs = Theme.of(context).colorScheme;
    final track = player.currentTrack;

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: _kMiniSize.height,
        color: cs.surface,
        child: Row(
          children: [
            _MiniArt(path: track?.path, size: _kMiniSize.height),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      track?.displayTitle ?? 'Not playing',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface.withValues(alpha: 0.86),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track?.displayArtist ?? '',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurface.withValues(alpha: 0.38),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (track != null) _MiniProgress(player: player),
                  ],
                ),
              ),
            ),
            _MiniControls(player: player),
            _MiniIconBtn(
              icon: Icons.open_in_full_rounded,
              onTap: () => MiniPlayerWindow.toggle(context),
              size: 16,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _MiniArt extends StatefulWidget {
  final String? path;
  final double size;
  const _MiniArt({this.path, required this.size});

  @override
  State<_MiniArt> createState() => _MiniArtState();
}

class _MiniArtState extends State<_MiniArt> {
  Uint8List? _art;
  String? _loadedPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_MiniArt old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _load();
  }

  Future<void> _load() async {
    final path = widget.path;
    if (path == null || path == _loadedPath) return;
    _loadedPath = path;
    try {
      final b = await backend.readAlbumArt(path: path);
      if (mounted && _loadedPath == path) setState(() => _art = b);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_art != null) {
      return Image.memory(
        _art!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
      );
    }
    return Container(
      width: widget.size,
      height: widget.size,
      color: cs.onSurface.withValues(alpha: 0.06),
      child: Icon(
        Icons.music_note_rounded,
        size: widget.size * 0.35,
        color: cs.onSurface.withValues(alpha: 0.16),
      ),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  final PlayerState player;
  const _MiniProgress({required this.player});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = player.currentTrack?.duration.inMilliseconds ?? 1;
    final pos = player.position.inMilliseconds;
    final p = (pos / total).clamp(0.0, 1.0);

    return Container(
      height: 2,
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(1),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: p,
        child: Container(
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.60),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}

class _MiniControls extends ConsumerWidget {
  final PlayerState player;
  const _MiniControls({required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(playerProvider.notifier);
    final isPlaying = player.status == PlayerStatus.playing;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniIconBtn(icon: Icons.skip_previous_rounded, onTap: n.skipPrevious),
        _MiniIconBtn(
          icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          onTap: isPlaying ? n.pause : n.play,
          size: 20,
        ),
        _MiniIconBtn(icon: Icons.skip_next_rounded, onTap: n.skipNext),
      ],
    );
  }
}

class _MiniIconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _MiniIconBtn({required this.icon, required this.onTap, this.size = 16});
  @override
  State<_MiniIconBtn> createState() => _MiniIconBtnState();
}

class _MiniIconBtnState extends State<_MiniIconBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _h
                ? cs.onSurface.withValues(alpha: 0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: cs.onSurface.withValues(alpha: 0.62),
          ),
        ),
      ),
    );
  }
}

class MiniPlayerOverlay extends ConsumerWidget {
  final Widget child;
  const MiniPlayerOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMini = ref.watch(miniPlayerActiveProvider);
    if (isMini) return const MiniPlayerView();
    return child;
  }
}
