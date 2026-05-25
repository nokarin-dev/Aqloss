import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/models/playlist.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/widgets/playlist_art_icon.dart';
import 'package:aqloss/widgets/shared/input_dialog.dart';
import 'package:aqloss/widgets/sidebar/folder_manager_dialog.dart';
import 'package:aqloss/widgets/sidebar/playlist_nav_item.dart';

class SideNav extends ConsumerStatefulWidget {
  final int route;
  final bool collapsed;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggleCollapse;

  const SideNav({
    super.key,
    required this.route,
    required this.collapsed,
    required this.onSelect,
    required this.onToggleCollapse,
  });

  @override
  ConsumerState<SideNav> createState() => _SideNavState();
}

class _SideNavState extends ConsumerState<SideNav>
    with SingleTickerProviderStateMixin {
  static const _collapsedWidth = 58.0;
  static const _expandedWidth = 232.0;
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: widget.collapsed ? 0 : 1,
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
  }

  @override
  void didUpdateWidget(SideNav old) {
    super.didUpdateWidget(old);
    if (widget.collapsed != old.collapsed) {
      widget.collapsed ? _ctrl.reverse() : _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _showFolderManager() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const FolderManagerDialog(),
    );
  }

  Future<void> _createPlaylist() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => InputDialog(
        title: 'New playlist',
        hint: 'Playlist name',
        confirmLabel: 'Create',
        controller: ctrl,
      ),
    );
    if (name != null && name.isNotEmpty) {
      ref.read(playlistProvider.notifier).create(name);
    }
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

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistProvider);
    final library = ref.watch(libraryProvider);
    final player = ref.watch(playerProvider);
    final appStyle = ref.watch(settingsProvider).appStyle;
    final isScanning = library.status == LibraryStatus.scanning;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final w =
            _collapsedWidth + (_expandedWidth - _collapsedWidth) * _anim.value;
        return SizedBox(width: w, child: child);
      },
      child: _SideNavBody(
        route: widget.route,
        collapsed: widget.collapsed,
        isIslands: appStyle == AppStyle.islands,
        isScanning: isScanning,
        playlists: playlists,
        library: library,
        player: player,
        onSelect: widget.onSelect,
        onToggleCollapse: widget.onToggleCollapse,
        onShowFolderManager: _showFolderManager,
        onCreatePlaylist: _createPlaylist,
        onRenamePlaylist: _renamePlaylist,
        onDeletePlaylist: (pl) =>
            ref.read(playlistProvider.notifier).delete(pl.id),
        onPlayPlaylist: (pl) => ref
            .read(playerProvider.notifier)
            .loadWithQueue(pl.tracks.first, pl.tracks),
        onRescan: () => ref.read(libraryProvider.notifier).rescanAll(),
        onAddTracksToPlaylist: (pl, tracks) =>
            ref.read(playlistProvider.notifier).addTracks(pl.id, tracks),
      ),
    );
  }
}

// ── Body (stateless, all data passed in) ──────────────────────────────────────

class _SideNavBody extends StatelessWidget {
  final int route;
  final bool collapsed;
  final bool isIslands;
  final bool isScanning;
  final List<Playlist> playlists;
  final LibraryState library;
  final PlayerState player;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggleCollapse;
  final VoidCallback onShowFolderManager;
  final VoidCallback onCreatePlaylist;
  final ValueChanged<Playlist> onRenamePlaylist;
  final ValueChanged<Playlist> onDeletePlaylist;
  final ValueChanged<Playlist> onPlayPlaylist;
  final VoidCallback onRescan;
  final void Function(Playlist, List<Track>) onAddTracksToPlaylist;

  const _SideNavBody({
    required this.route,
    required this.collapsed,
    required this.isIslands,
    required this.isScanning,
    required this.playlists,
    required this.library,
    required this.player,
    required this.onSelect,
    required this.onToggleCollapse,
    required this.onShowFolderManager,
    required this.onCreatePlaylist,
    required this.onRenamePlaylist,
    required this.onDeletePlaylist,
    required this.onPlayPlaylist,
    required this.onRescan,
    required this.onAddTracksToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = _buildContent(context, cs);

    if (isIslands) {
      return Container(
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.06)),
          borderRadius: const BorderRadius.all(Radius.circular(5)),
        ),
        child: content,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(
          right: BorderSide(color: cs.onSurface.withValues(alpha: 0.06)),
        ),
      ),
      child: content,
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          child: _CollapseBtn(collapsed: collapsed, onTap: onToggleCollapse),
        ),
        const SizedBox(height: 6),

        collapsed ? const SizedBox(height: 2) : _SectionLabel('NAVIGATE'),

        _NavItem(
          icon: Icons.play_circle_outline_rounded,
          activeIcon: Icons.play_circle_rounded,
          label: 'Now Playing',
          isActive: route == 0,
          collapsed: collapsed,
          trailing: player.currentTrack != null
              ? _NowPlayingDot(status: player.status)
              : null,
          onTap: () => onSelect(0),
        ),
        _NavItem(
          icon: Icons.library_music_outlined,
          activeIcon: Icons.library_music_rounded,
          label: 'Library',
          isActive: route == 1,
          collapsed: collapsed,
          onTap: () => onSelect(1),
        ),
        _NavItem(
          icon: Icons.album_outlined,
          activeIcon: Icons.album_rounded,
          label: 'Albums',
          isActive: route == 2,
          collapsed: collapsed,
          onTap: () => onSelect(2),
        ),

        const SizedBox(height: 4),
        collapsed ? const SizedBox(height: 2) : _SectionLabel('LIBRARY'),

        _NavItem(
          icon: Icons.folder_open_outlined,
          activeIcon: Icons.folder_open_rounded,
          label: 'Folders',
          isActive: false,
          collapsed: collapsed,
          trailing: isScanning
              ? SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.2,
                    color: cs.onSurface.withValues(alpha: 0.25),
                  ),
                )
              : null,
          onTap: onShowFolderManager,
        ),
        _NavItem(
          icon: Icons.refresh_rounded,
          activeIcon: Icons.refresh_rounded,
          label: 'Rescan',
          isActive: false,
          collapsed: collapsed,
          onTap: isScanning ? null : onRescan,
        ),

        if (!collapsed && library.totalTracks > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 14, 0),
            child: Text(
              '${library.totalTracks} tracks',
              style: TextStyle(
                fontSize: 9.5,
                color: cs.onSurface.withValues(alpha: 0.20),
              ),
            ),
          ),

        const SizedBox(height: 4),

        // Playlists header
        if (!collapsed)
          Row(
            children: [
              _SectionLabel('PLAYLISTS'),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _IconBtn(
                  icon: Icons.add_rounded,
                  tooltip: 'New playlist (Ctrl+N)',
                  onTap: onCreatePlaylist,
                ),
              ),
            ],
          )
        else ...[
          const SizedBox(height: 2),
          Tooltip(
            message: 'New playlist',
            preferBelow: false,
            child: GestureDetector(
              onTap: onCreatePlaylist,
              child: SizedBox(
                height: 30,
                child: Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 13,
                      color: cs.onSurface.withValues(alpha: 0.30),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],

        // Playlist list
        Expanded(
          child: playlists.isEmpty
              ? const SizedBox.shrink()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  itemCount: playlists.length,
                  itemBuilder: (ctx, i) {
                    final pl = playlists[i];
                    return DragTarget<List<Track>>(
                      onAcceptWithDetails: (details) =>
                          onAddTracksToPlaylist(pl, details.data),
                      builder: (ctx, candidates, _) {
                        final isOver = candidates.isNotEmpty;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 130),
                          margin: EdgeInsets.symmetric(
                            horizontal: collapsed ? 6 : 7,
                            vertical: 1,
                          ),
                          decoration: isOver
                              ? BoxDecoration(
                                  color: cs.onSurface.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: cs.onSurface.withValues(alpha: 0.14),
                                  ),
                                )
                              : null,
                          child: collapsed
                              ? _PlaylistCollapsedIcon(
                                  playlist: pl,
                                  isActive: route == (i + 10),
                                  onTap: () => onSelect(i + 10),
                                )
                              : PlaylistNavItem(
                                  playlist: pl,
                                  isActive: route == (i + 10),
                                  onTap: () => onSelect(i + 10),
                                  onDelete: () => onDeletePlaylist(pl),
                                  onRename: () => onRenamePlaylist(pl),
                                  onPlay: pl.tracks.isNotEmpty
                                      ? () => onPlayPlaylist(pl)
                                      : null,
                                ),
                        );
                      },
                    );
                  },
                ),
        ),

        Container(
          height: 1,
          color: cs.onSurface.withValues(alpha: 0.06),
          margin: const EdgeInsets.symmetric(horizontal: 7),
        ),
        const SizedBox(height: 4),

        _NavItem(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings_rounded,
          label: 'Settings',
          isActive: route == 3,
          collapsed: collapsed,
          onTap: () => onSelect(3),
        ),

        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _CollapseBtn extends StatefulWidget {
  final bool collapsed;
  final VoidCallback onTap;
  const _CollapseBtn({required this.collapsed, required this.onTap});

  @override
  State<_CollapseBtn> createState() => _CollapseBtnState();
}

class _CollapseBtnState extends State<_CollapseBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.collapsed
            ? 'Expand sidebar (Ctrl+B)'
            : 'Collapse sidebar (Ctrl+B)',
        preferBelow: false,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: widget.collapsed ? 0 : 9,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: _hovered
                  ? cs.onSurface.withValues(alpha: 0.04)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: widget.collapsed
                ? Center(
                    child: AnimatedRotation(
                      turns: 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOutCubic,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: cs.onSurface.withValues(alpha: 0.25),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      AnimatedRotation(
                        turns: 0.5,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOutCubic,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: cs.onSurface.withValues(alpha: 0.25),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AQLOSS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface.withValues(alpha: 0.18),
                          letterSpacing: 3.0,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final bool collapsed;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.collapsed,
    this.trailing,
    this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          padding: EdgeInsets.symmetric(
            horizontal: widget.collapsed ? 0 : 9,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: widget.isActive
                ? cs.onSurface.withValues(alpha: 0.08)
                : _hovered
                ? cs.onSurface.withValues(alpha: 0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.collapsed
              ? Center(
                  child: Icon(
                    widget.isActive ? widget.activeIcon : widget.icon,
                    size: 18,
                    color: widget.isActive
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.32),
                  ),
                )
              : Row(
                  children: [
                    Icon(
                      widget.isActive ? widget.activeIcon : widget.icon,
                      size: 16,
                      color: widget.isActive
                          ? cs.onSurface
                          : widget.onTap == null
                          ? cs.onSurface.withValues(alpha: 0.18)
                          : cs.onSurface.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: widget.isActive
                              ? cs.onSurface
                              : widget.onTap == null
                              ? cs.onSurface.withValues(alpha: 0.18)
                              : cs.onSurface.withValues(alpha: 0.55),
                          fontWeight: widget.isActive
                              ? FontWeight.w500
                              : FontWeight.w400,
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
    );

    if (widget.collapsed) {
      return Tooltip(
        message: widget.label,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 400),
        child: item,
      );
    }
    return item;
  }
}

class _PlaylistCollapsedIcon extends StatefulWidget {
  final Playlist playlist;
  final bool isActive;
  final VoidCallback onTap;

  const _PlaylistCollapsedIcon({
    required this.playlist,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_PlaylistCollapsedIcon> createState() => _PlaylistCollapsedIconState();
}

class _PlaylistCollapsedIconState extends State<_PlaylistCollapsedIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: '${widget.playlist.name} · ${widget.playlist.length} tracks',
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            height: 38,
            decoration: BoxDecoration(
              color: widget.isActive
                  ? cs.onSurface.withValues(alpha: 0.09)
                  : _hovered
                  ? cs.onSurface.withValues(alpha: 0.04)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: PlaylistArtIcon(
                playlist: widget.playlist,
                size: 26,
                radius: 6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NowPlayingDot extends StatelessWidget {
  final PlayerStatus status;
  const _NowPlayingDot({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: status == PlayerStatus.playing
            ? const Color(0xFF4ADE80).withValues(alpha: 0.85)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.20),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: cs.onSurface.withValues(alpha: 0.18),
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 13,
              color: cs.onSurface.withValues(alpha: 0.32),
            ),
          ),
        ),
      ),
    );
  }
}
