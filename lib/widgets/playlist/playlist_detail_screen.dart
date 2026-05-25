import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/models/playlist.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:aqloss/widgets/shared/now_playing_header.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistProvider);
    final current = playlists.firstWhere(
      (p) => p.id == playlist.id,
      orElse: () => playlist,
    );
    final notifier = ref.read(playlistProvider.notifier);
    final playerNotifier = ref.read(playerProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24,
              isMobile ? 16 : 22,
              isMobile ? 18 : 24,
              10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current.name,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${current.length} tracks · ${current.durationLabel}',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.32),
                        ),
                      ),
                    ],
                  ),
                ),
                if (current.tracks.isNotEmpty)
                  GestureDetector(
                    onTap: () => playerNotifier.loadWithQueue(
                      current.tracks.first,
                      current.tracks,
                    ),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: cs.onSurface,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: cs.surface,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: cs.onSurface.withValues(alpha: 0.06)),
          const NowPlayingHeader(),
          Expanded(
            child: current.tracks.isEmpty
                ? _EmptyPlaylist(cs: cs)
                : ReorderableListView.builder(
                    onReorder: (old, newIdx) =>
                        notifier.reorderTrack(current.id, old, newIdx),
                    itemCount: current.tracks.length,
                    itemBuilder: (ctx, i) {
                      final t = current.tracks[i];
                      return Dismissible(
                        key: ValueKey('${current.id}_${t.path}_$i'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: const Color(
                            0xFFFF6B6B,
                          ).withValues(alpha: 0.10),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFFF6B6B),
                            size: 18,
                          ),
                        ),
                        onDismissed: (_) => notifier.removeTrack(current.id, i),
                        child: PlaylistTrackTile(
                          key: ValueKey('tile_${t.path}_$i'),
                          track: t,
                          index: i,
                          onTap: () =>
                              playerNotifier.loadWithQueue(t, current.tracks),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlaylist extends StatelessWidget {
  final ColorScheme cs;
  const _EmptyPlaylist({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 36,
            color: cs.onSurface.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 14),
          Text(
            'No tracks yet',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.32),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Drag tracks here from Library',
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}

class PlaylistTrackTile extends ConsumerStatefulWidget {
  final Track track;
  final int index;
  final VoidCallback onTap;

  const PlaylistTrackTile({
    super.key,
    required this.track,
    required this.index,
    required this.onTap,
  });

  @override
  ConsumerState<PlaylistTrackTile> createState() => _PlaylistTrackTileState();
}

class _PlaylistTrackTileState extends ConsumerState<PlaylistTrackTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isPlaying =
        ref.watch(playerProvider).currentTrack?.path == widget.track.path;
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          color: _hovered
              ? cs.onSurface.withValues(alpha: 0.03)
              : Colors.transparent,
          padding: const EdgeInsets.only(left: 16, right: 0, top: 7, bottom: 7),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Center(
                  child: isPlaying
                      ? Icon(
                          Icons.equalizer_rounded,
                          size: 14,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        )
                      : Text(
                          '${widget.index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.22),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.track.displayTitle,
                      style: TextStyle(
                        color: isPlaying
                            ? cs.onSurface
                            : cs.onSurface.withValues(alpha: 0.68),
                        fontSize: 13,
                        fontWeight: isPlaying
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.track.displayArtist,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.28),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                widget.track.durationLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.20),
                ),
              ),
              const SizedBox(width: 4),
              ReorderableDragStartListener(
                index: widget.index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    size: 16,
                    color: cs.onSurface.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
