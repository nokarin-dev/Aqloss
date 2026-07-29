import 'package:aqloss/models/playlist.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:aqloss/ui/m3/m3_route.dart';
import 'package:aqloss/ui/m3/shell/m3_app_drawer.dart';
import 'package:aqloss/widgets/playlist/playlist_art_icon.dart';
import 'package:aqloss/widgets/q_toast.dart';
import 'package:aqloss/widgets/shared/input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class M3DesktopNav extends ConsumerStatefulWidget {
  final int route;
  final bool collapsed;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggleCollapse;
  final VoidCallback onOpenQueue;

  const M3DesktopNav({
    super.key,
    required this.route,
    required this.collapsed,
    required this.onSelect,
    required this.onToggleCollapse,
    required this.onOpenQueue,
  });

  @override
  ConsumerState<M3DesktopNav> createState() => _M3DesktopNavState();
}

class _M3DesktopNavState extends ConsumerState<M3DesktopNav>
    with SingleTickerProviderStateMixin {
  static const _collapsedWidth = 56.0;
  static const _expandedWidth = 212.0;

  late final AnimationController _widthCtrl;
  late final Animation<double> _widthAnim;

  @override
  void initState() {
    super.initState();
    _widthCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: widget.collapsed ? 0 : 1,
    );
    _widthAnim = CurvedAnimation(
      parent: _widthCtrl,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(M3DesktopNav old) {
    super.didUpdateWidget(old);
    if (widget.collapsed != old.collapsed) {
      widget.collapsed ? _widthCtrl.reverse() : _widthCtrl.forward();
    }
  }

  @override
  void dispose() {
    _widthCtrl.dispose();
    super.dispose();
  }

  Future<void> _createPlaylist() async {
    await showM3CreatePlaylistDialog(context, ref);
  }

  Future<void> _renamePlaylist(Playlist pl) async {
    final ctrl = TextEditingController(text: pl.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => InputDialog(
        title: 'Rename',
        hint: pl.name,
        confirmLabel: 'Save',
        controller: ctrl,
      ),
    );
    if (name != null && name.isNotEmpty) {
      ref.read(playlistProvider.notifier).rename(pl.id, name);
    }
  }

  void _onDropToPlaylist(Playlist pl, List<Track> tracks) {
    ref.read(playlistProvider.notifier).addTracks(pl.id, tracks);
    QToast.show(
      context,
      tracks.length == 1
          ? 'Added to "${pl.name}"'
          : 'Added ${tracks.length} tracks to "${pl.name}"',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final playlists = ref.watch(playlistProvider);
    final library = ref.watch(libraryProvider);
    final player = ref.watch(playerProvider);
    final collapsed = widget.collapsed;
    final queueLen = player.queue.length;

    return AnimatedBuilder(
      animation: _widthAnim,
      builder: (context, child) {
        final w =
            _collapsedWidth +
            (_expandedWidth - _collapsedWidth) * _widthAnim.value;
        return SizedBox(width: w, child: child);
      },
      child: Material(
        color: cs.surfaceContainerLow,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CollapseHeader(
                collapsed: collapsed,
                trackCount: library.totalTracks,
                onToggle: widget.onToggleCollapse,
              ),
              const SizedBox(height: 4),
              _NavDest(
                icon: Icons.play_circle_outline_rounded,
                selectedIcon: Icons.play_circle_rounded,
                label: 'Now Playing',
                selected: widget.route == M3Route.player,
                collapsed: collapsed,
                trailing: player.currentTrack != null
                    ? _PlayingDot(
                        playing: player.status == PlayerStatus.playing,
                      )
                    : null,
                onTap: () => widget.onSelect(M3Route.player),
              ),
              _NavDest(
                icon: Icons.library_music_outlined,
                selectedIcon: Icons.library_music_rounded,
                label: 'Library',
                selected: widget.route == M3Route.library,
                collapsed: collapsed,
                onTap: () => widget.onSelect(M3Route.library),
              ),
              _NavDest(
                icon: Icons.album_outlined,
                selectedIcon: Icons.album_rounded,
                label: 'Albums',
                selected: widget.route == M3Route.albums,
                collapsed: collapsed,
                onTap: () => widget.onSelect(M3Route.albums),
              ),
              _NavDest(
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: 'Artists',
                selected: widget.route == M3Route.artists,
                collapsed: collapsed,
                onTap: () => widget.onSelect(M3Route.artists),
              ),
              _NavDest(
                icon: Icons.history_rounded,
                selectedIcon: Icons.history_rounded,
                label: 'History',
                selected: widget.route == M3Route.history,
                collapsed: collapsed,
                onTap: () => widget.onSelect(M3Route.history),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  collapsed ? 8 : 14,
                  10,
                  collapsed ? 8 : 8,
                  4,
                ),
                child: collapsed
                    ? Tooltip(
                        message: 'New playlist',
                        child: IconButton.filledTonal(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          visualDensity: VisualDensity.compact,
                          onPressed: _createPlaylist,
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Playlists',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_rounded, size: 18),
                            tooltip: 'New playlist',
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(
                              backgroundColor: cs.secondaryContainer.withValues(
                                alpha: 0.45,
                              ),
                            ),
                            onPressed: _createPlaylist,
                          ),
                        ],
                      ),
              ),
              Expanded(
                child: playlists.isEmpty
                    ? collapsed
                          ? const SizedBox.shrink()
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  'No playlists yet',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: collapsed ? 6 : 8,
                          vertical: 2,
                        ),
                        itemCount: playlists.length,
                        itemBuilder: (ctx, i) {
                          final pl = playlists[i];
                          final selected =
                              widget.route == M3Route.playlistBase + i;
                          return DragTarget<List<Track>>(
                            onAcceptWithDetails: (d) =>
                                _onDropToPlaylist(pl, d.data),
                            builder: (ctx, candidates, _) {
                              final highlight = candidates.isNotEmpty;
                              if (collapsed) {
                                return Tooltip(
                                  message: pl.name,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: _PlaylistIconDest(
                                      playlist: pl,
                                      selected: selected,
                                      highlighted: highlight,
                                      onTap: () => widget.onSelect(
                                        M3Route.playlistBase + i,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return _PlaylistRow(
                                playlist: pl,
                                selected: selected,
                                highlighted: highlight,
                                onTap: () =>
                                    widget.onSelect(M3Route.playlistBase + i),
                                onPlay: pl.tracks.isNotEmpty
                                    ? () => ref
                                          .read(playerProvider.notifier)
                                          .loadWithQueue(
                                            pl.tracks.first,
                                            pl.tracks,
                                          )
                                    : null,
                                onRename: () => _renamePlaylist(pl),
                                onDelete: () => ref
                                    .read(playlistProvider.notifier)
                                    .delete(pl.id),
                              );
                            },
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 4),
              _NavDest(
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings_rounded,
                label: 'Settings',
                selected: widget.route == M3Route.settings,
                collapsed: collapsed,
                onTap: () => widget.onSelect(M3Route.settings),
              ),
              _NavDest(
                icon: Icons.queue_music_outlined,
                selectedIcon: Icons.queue_music_rounded,
                label: 'Queue',
                selected: false,
                collapsed: collapsed,
                trailing: queueLen > 0
                    ? _QueueBadge(count: queueLen, collapsed: collapsed)
                    : null,
                onTap: widget.onOpenQueue,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapseHeader extends StatefulWidget {
  final bool collapsed;
  final int trackCount;
  final VoidCallback onToggle;

  const _CollapseHeader({
    required this.collapsed,
    required this.trackCount,
    required this.onToggle,
  });

  @override
  State<_CollapseHeader> createState() => _CollapseHeaderState();
}

class _CollapseHeaderState extends State<_CollapseHeader> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Material(
          color: _hovered
              ? cs.onSurface.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Tooltip(
              message: widget.collapsed ? 'Expand sidebar' : 'Collapse sidebar',
              preferBelow: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.collapsed ? 0 : 8,
                  vertical: 8,
                ),
                child: widget.collapsed
                    ? Center(
                        child: Icon(
                          Icons.menu_open_rounded,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                      )
                    : Row(
                        children: [
                          Icon(
                            Icons.menu_rounded,
                            size: 20,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Aqloss',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                if (widget.trackCount > 0)
                                  Text(
                                    '${widget.trackCount} tracks',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_left_rounded,
                            size: 18,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDest extends StatefulWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool collapsed;
  final Widget? trailing;
  final VoidCallback onTap;

  const _NavDest({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.collapsed,
    this.trailing,
    required this.onTap,
  });

  @override
  State<_NavDest> createState() => _NavDestState();
}

class _NavDestState extends State<_NavDest> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (widget.collapsed) {
      return Tooltip(
        message: widget.label,
        preferBelow: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                isSelected: widget.selected,
                icon: Icon(widget.icon, size: 20),
                selectedIcon: Icon(widget.selectedIcon, size: 20),
                onPressed: widget.onTap,
                style: IconButton.styleFrom(
                  backgroundColor: widget.selected
                      ? cs.secondaryContainer
                      : _hovered
                      ? cs.onSurface.withValues(alpha: 0.05)
                      : null,
                  foregroundColor: widget.selected
                      ? cs.onSecondaryContainer
                      : cs.onSurfaceVariant,
                ),
              ),
              if (widget.trailing != null)
                Positioned(right: 2, top: 2, child: widget.trailing!),
            ],
          ),
        ),
      );
    }

    final bg = widget.selected
        ? cs.secondaryContainer
        : _hovered
        ? cs.onSurface.withValues(alpha: 0.05)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  if (widget.selected)
                    Container(
                      width: 3,
                      height: 16,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  else
                    const SizedBox(width: 13),
                  Icon(
                    widget.selected ? widget.selectedIcon : widget.icon,
                    size: 20,
                    color: widget.selected
                        ? cs.onSecondaryContainer
                        : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 13,
                        color: widget.selected
                            ? cs.onSurface
                            : cs.onSurfaceVariant,
                        fontWeight: widget.selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistRow extends StatefulWidget {
  final Playlist playlist;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _PlaylistRow({
    required this.playlist,
    required this.selected,
    required this.highlighted,
    required this.onTap,
    required this.onPlay,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_PlaylistRow> createState() => _PlaylistRowState();
}

class _PlaylistRowState extends State<_PlaylistRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = widget.highlighted
        ? cs.primaryContainer.withValues(alpha: 0.4)
        : widget.selected
        ? cs.secondaryContainer
        : _hovered
        ? cs.onSurface.withValues(alpha: 0.05)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: widget.onTap,
            onSecondaryTapDown: (d) => _showMenu(d.globalPosition),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
              child: Row(
                children: [
                  PlaylistArtIcon(
                    playlist: widget.playlist,
                    size: 26,
                    radius: 6,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 12.5,
                            fontWeight: widget.selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${widget.playlist.length} tracks',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_hovered) ...[
                    if (widget.onPlay != null)
                      IconButton(
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        tooltip: 'Play',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: widget.onPlay,
                      ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, size: 16),
                      tooltip: 'More',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      onPressed: () {
                        final box = context.findRenderObject() as RenderBox?;
                        final pos =
                            box?.localToGlobal(Offset.zero) ?? Offset.zero;
                        _showMenu(pos + const Offset(120, 20));
                      },
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${widget.playlist.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMenu(Offset pos) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      items: [
        if (widget.onPlay != null)
          const PopupMenuItem(value: 'play', child: Text('Play')),
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
    switch (action) {
      case 'play':
        widget.onPlay?.call();
      case 'rename':
        widget.onRename();
      case 'delete':
        widget.onDelete();
    }
  }
}

class _PlayingDot extends StatelessWidget {
  final bool playing;
  const _PlayingDot({required this.playing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: playing
            ? cs.primary
            : cs.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    );
  }
}

class _QueueBadge extends StatelessWidget {
  final int count;
  final bool collapsed;
  const _QueueBadge({required this.count, required this.collapsed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = count > 99 ? '99+' : '$count';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 4 : 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _PlaylistIconDest extends StatelessWidget {
  final Playlist playlist;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;

  const _PlaylistIconDest({
    required this.playlist,
    required this.selected,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: highlighted
          ? cs.primaryContainer.withValues(alpha: 0.4)
          : selected
          ? cs.secondaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: PlaylistArtIcon(playlist: playlist, size: 24, radius: 5),
        ),
      ),
    );
  }
}
