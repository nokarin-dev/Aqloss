import 'dart:typed_data';

import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class M3QueueDrawer extends ConsumerWidget {
  const M3QueueDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final queue = player.queue;
    final curIdx = player.queueIndex;
    final notifier = ref.read(playerProvider.notifier);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Drawer(
      width: 340,
      backgroundColor: cs.surfaceContainerLow,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.queue_music_rounded, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Queue', style: theme.textTheme.titleMedium),
                        Text(
                          '${queue.length} tracks',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (queue.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        final n = ref.read(playerProvider).queue.length;
                        for (var i = n - 1; i >= 0; i--) {
                          notifier.removeFromQueue(i);
                        }
                      },
                      child: const Text('Clear'),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
            Expanded(
              child: queue.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.queue_music_outlined,
                            size: 40,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Queue is empty',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Play a track or add from Library',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: queue.length,
                      onReorderItem: (oldIndex, newIndex) {
                        final legacyNew = oldIndex < newIndex
                            ? newIndex + 1
                            : newIndex;
                        notifier.reorderQueue(oldIndex, legacyNew);
                      },
                      itemBuilder: (ctx, i) {
                        final track = queue[i];
                        final playing = i == curIdx;
                        return _QueueItem(
                          key: ValueKey('${track.path}_$i'),
                          track: track,
                          playing: playing,
                          onTap: () => notifier.jumpToQueue(i),
                          onRemove: () => notifier.removeFromQueue(i),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueItem extends ConsumerStatefulWidget {
  final Track track;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _QueueItem({
    super.key,
    required this.track,
    required this.playing,
    required this.onTap,
    required this.onRemove,
  });

  @override
  ConsumerState<_QueueItem> createState() => _QueueItemState();
}

class _QueueItemState extends ConsumerState<_QueueItem> {
  Uint8List? _art;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_QueueItem old) {
    super.didUpdateWidget(old);
    if (old.track.path != widget.track.path) _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await backend.readAlbumArtThumbnail(
        path: widget.track.path,
      );
      if (mounted) {
        setState(() => _art = bytes != null ? Uint8List.fromList(bytes) : null);
      }
    } catch (_) {
      if (mounted) setState(() => _art = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: widget.playing
            ? cs.secondaryContainer.withValues(alpha: 0.55)
            : _hovered
            ? cs.onSurface.withValues(alpha: 0.04)
            : Colors.transparent,
        child: ListTile(
          onTap: widget.onTap,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 40,
              height: 40,
              child: _art != null
                  ? Image.memory(_art!, fit: BoxFit.cover)
                  : ColoredBox(
                      color: cs.surfaceContainerHighest,
                      child: Icon(
                        widget.playing
                            ? Icons.equalizer_rounded
                            : Icons.music_note_rounded,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          title: Text(
            widget.track.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: widget.playing ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          subtitle: Text(
            widget.track.displayArtist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hovered)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onRemove,
                )
              else
                Text(
                  widget.track.durationLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              const Icon(Icons.drag_handle_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
