import 'dart:typed_data';
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
    final track = player.currentTrack;
    final notifier = ref.read(playerProvider.notifier);
    final isPlaying = player.status == PlayerStatus.playing;
    final cs = Theme.of(context).colorScheme;

    if (track == null) return const SizedBox.shrink();

    if (track.path != _loadedPath) {
      Future.microtask(() => _loadArt(track.path));
    }

    final duration = track.duration;
    final progress = duration.inMilliseconds > 0
        ? (player.position.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    return GestureDetector(
      onTap: widget.onTap,
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
                trackHeight: 2,
                thumbShape: SliderComponentShape.noThumb,
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: cs.onSurface.withValues(alpha: 0.38),
                inactiveTrackColor: cs.onSurface.withValues(alpha: 0.10),
              ),
              child: Slider(
                value: progress,
                onChanged: (v) {
                  if (duration.inMilliseconds > 0) {
                    notifier.seek(duration * v);
                  }
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 8, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onTap,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(track.path),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: cs.onSurface.withValues(alpha: 0.06),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _artBytes != null
                            ? Image.memory(_artBytes!, fit: BoxFit.cover)
                            : Center(
                                child: Icon(
                                  Icons.music_note_rounded,
                                  size: 16,
                                  color: cs.onSurface.withValues(alpha: 0.24),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

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
                            color: cs.onSurface.withValues(alpha: 0.38),
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
                    onTap: notifier.skipPrevious,
                  ),

                  _MiniBtn(
                    icon: isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 26,
                    color: cs.onSurface,
                    onTap: isPlaying ? notifier.pause : notifier.play,
                  ),

                  _MiniBtn(
                    icon: Icons.skip_next_rounded,
                    size: 20,
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

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final VoidCallback? onTap;

  const _MiniBtn({
    required this.icon,
    required this.size,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Icon(
          icon,
          size: size,
          color: color ?? cs.onSurface.withValues(alpha: 0.54),
        ),
      ),
    );
  }
}
