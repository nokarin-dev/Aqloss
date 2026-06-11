import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/history_provider.dart';
import 'package:aqloss/models/playlist.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:aqloss/widgets/shared/now_playing_header.dart';
import 'package:aqloss/services/playlist_io_service.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  final _scroll = ScrollController();
  static const _kItemH = 52.0;
  String? _lastScrolledPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToPlaying([]));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToPlaying(List<Track> tracks) {
    if (!_scroll.hasClients || tracks.isEmpty) return;
    final path = ref.read(playerProvider).currentTrack?.path;
    if (path == null || path == _lastScrolledPath) return;
    final idx = tracks.indexWhere((t) => t.path == path);
    if (idx < 0) return;
    _lastScrolledPath = path;
    final viewportH = _scroll.position.viewportDimension;
    final centered = idx * _kItemH - viewportH / 2 + _kItemH / 2;
    final target = centered.clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistProvider);
    final current = playlists.firstWhere(
      (p) => p.id == widget.playlist.id,
      orElse: () => widget.playlist,
    );
    final notifier = ref.read(playlistProvider.notifier);
    final playerNotifier = ref.read(playerProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 700;

    final currentPath = ref.watch(playerProvider).currentTrack?.path;
    if (currentPath != null && currentPath != _lastScrolledPath) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToPlaying(current.tracks),
      );
    }

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
                // Export button
                _PlaylistHeaderBtn(
                  icon: Icons.upload_rounded,
                  tooltip: 'Export playlist',
                  onTap: () async {
                    final result = await PlaylistIOService.export(current);
                    if (context.mounted) {
                      if (result.success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result.savedPath != null
                                  ? 'Exported to ${result.savedPath}'
                                  : 'Exported',
                            ),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      } else if (result.error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Export failed: ${result.error}'),
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(width: 8),
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
                    scrollController: _scroll,
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
              // Love button
              Consumer(
                builder: (context, ref, _) {
                  final isLoved = ref
                      .watch(historyProvider)
                      .isLoved(widget.track);
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: _hovered || isLoved ? 1.0 : 0.0,
                    child: _PlaylistLoveBtn(
                      track: widget.track,
                      isLoved: isLoved,
                    ),
                  );
                },
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

// Love button
class _PlaylistLoveBtn extends ConsumerStatefulWidget {
  final Track track;
  final bool isLoved;
  const _PlaylistLoveBtn({required this.track, required this.isLoved});

  @override
  ConsumerState<_PlaylistLoveBtn> createState() => _PlaylistLoveBtnState();
}

class _PlaylistLoveBtnState extends ConsumerState<_PlaylistLoveBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.45,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    _busy = true;
    await _anim.forward();
    await _anim.reverse();
    await ref.read(historyProvider.notifier).toggleLove(widget.track);
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: Icon(
              widget.isLoved
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 13,
              color: widget.isLoved
                  ? const Color(0xFFFF6B8A)
                  : cs.onSurface.withValues(alpha: 0.28),
            ),
          ),
        ),
      ),
    );
  }
}

// Header icon button
class _PlaylistHeaderBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _PlaylistHeaderBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_PlaylistHeaderBtn> createState() => _PlaylistHeaderBtnState();
}

class _PlaylistHeaderBtnState extends State<_PlaylistHeaderBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.tooltip,
      preferBelow: false,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hovered
                  ? cs.onSurface.withValues(alpha: 0.07)
                  : cs.onSurface.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
            ),
            child: Icon(
              widget.icon,
              size: 15,
              color: cs.onSurface.withValues(alpha: 0.46),
            ),
          ),
        ),
      ),
    );
  }
}
