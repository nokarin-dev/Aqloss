import 'dart:typed_data';

import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/widgets/shared/m3_playback_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class M3MiniPlayerBar extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  final VoidCallback? onOpenQueue;

  const M3MiniPlayerBar({super.key, required this.onTap, this.onOpenQueue});

  @override
  ConsumerState<M3MiniPlayerBar> createState() => _M3MiniPlayerBarState();
}

class _M3MiniPlayerBarState extends ConsumerState<M3MiniPlayerBar> {
  Uint8List? _art;
  String? _path;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final path = ref.read(playerProvider).currentTrack?.path;
    if (path != null && path != _path) _load(path);
  }

  Future<void> _load(String p) async {
    _path = p;
    try {
      final bytes = await backend.readAlbumArtThumbnail(path: p);
      if (mounted && _path == p) {
        setState(() => _art = bytes != null ? Uint8List.fromList(bytes) : null);
      }
    } catch (_) {
      if (mounted) setState(() => _art = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final track = player.currentTrack;
    if (track == null) return const SizedBox.shrink();

    ref.listen(playerProvider, (prev, next) {
      final nextPath = next.currentTrack?.path;
      if (nextPath != null && nextPath != _path) _load(nextPath);
    });

    final notifier = ref.read(playerProvider.notifier);
    final playing = player.status == PlayerStatus.playing;
    final loading = player.status == PlayerStatus.loading;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final duration = track.duration;
    final progress = duration.inMilliseconds > 0
        ? (player.position.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    final isWide = MediaQuery.sizeOf(context).width > 700;

    final bar = Material(
      color: cs.surfaceContainerHigh,
      elevation: isWide ? 6 : 3,
      shadowColor: cs.shadow.withValues(alpha: 0.18),
      borderRadius: isWide
          ? const BorderRadius.vertical(top: Radius.circular(16))
          : BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _art != null
                        ? Image.memory(
                            _art!,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 52,
                            height: 52,
                            color: cs.surfaceContainerHighest,
                            child: Icon(
                              Icons.album_rounded,
                              color: cs.onSurfaceVariant,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          track.displayArtistAlbum,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded),
                    onPressed: notifier.skipPrevious,
                  ),
                  M3PlayButton(
                    isPlaying: playing,
                    isLoading: loading,
                    hasTrack: true,
                    progress: progress,
                    size: 36,
                    onTap: playing ? notifier.pause : notifier.play,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded),
                    onPressed: notifier.skipNext,
                  ),
                  if (widget.onOpenQueue != null)
                    IconButton(
                      icon: Badge(
                        isLabelVisible: player.queue.isNotEmpty,
                        label: Text('${player.queue.length}'),
                        child: const Icon(Icons.queue_music_rounded),
                      ),
                      tooltip: 'Queue',
                      onPressed: widget.onOpenQueue,
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: M3MiniPlaybackProgress(
              progress: progress,
              position: player.position,
              duration: duration,
              playing: playing,
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
        ],
      ),
      ),
    );

    if (!isWide) return bar;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: bar,
    );
  }
}
