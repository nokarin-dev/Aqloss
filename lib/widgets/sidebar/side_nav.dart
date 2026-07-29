import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/models/playlist.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:aqloss/widgets/q_toast.dart';
import 'package:aqloss/widgets/queue_panel.dart';
import 'package:aqloss/services/playlist_io_service.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/widgets/playlist/playlist_art_icon.dart';
import 'package:aqloss/widgets/shared/input_dialog.dart';
import 'package:aqloss/widgets/sidebar/playlist_nav_item.dart';

class _NavPalette {
  final Color surfaceVariant;
  final Color border;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color indicator;

  const _NavPalette({
    required this.surfaceVariant,
    required this.border,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.indicator,
  });

  factory _NavPalette.of(BuildContext context) {
    if (context.isMaterial3Ui) {
      final cs = Theme.of(context).colorScheme;
      return _NavPalette(
        surfaceVariant: cs.surfaceContainerLow,
        border: cs.outlineVariant.withValues(alpha: 0.35),
        onSurface: cs.onSurface,
        onSurfaceMuted: cs.onSurfaceVariant,
        indicator: cs.secondaryContainer.withValues(alpha: 0.55),
      );
    }
    final aq = context.aq;
    return _NavPalette(
      surfaceVariant: aq.surfaceVariant,
      border: aq.border,
      onSurface: aq.onSurface,
      onSurfaceMuted: aq.onSurfaceMuted,
      indicator: aq.indicator,
    );
  }
}

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

  Future<void> _importPlaylist() async {
    final result = await PlaylistIOService.import();
    if (!mounted) return;
    if (result.success && result.playlist != null) {
      await ref
          .read(playlistProvider.notifier)
          .importPlaylist(result.playlist!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported \'${result.playlist!.name}\''),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else if (result.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: ${result.error}')));
    }
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
    final isM3 = context.isMaterial3Ui;
    final useIslands = !isM3 && appStyle == AppStyle.islands;

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
        isIslands: useIslands,
        isM3: isM3,
        playlists: playlists,
        library: library,
        player: player,
        onSelect: widget.onSelect,
        onToggleCollapse: widget.onToggleCollapse,
        onCreatePlaylist: _createPlaylist,
        onImportPlaylist: _importPlaylist,
        onRenamePlaylist: _renamePlaylist,
        onDeletePlaylist: (pl) =>
            ref.read(playlistProvider.notifier).delete(pl.id),
        onPlayPlaylist: (pl) => ref
            .read(playerProvider.notifier)
            .loadWithQueue(pl.tracks.first, pl.tracks),
        onAddTracksToPlaylist: (pl, tracks) {
          ref.read(playlistProvider.notifier).addTracks(pl.id, tracks);
          if (mounted) {
            QToast.show(
              context,
              tracks.length == 1
                  ? 'Added to "${pl.name}"'
                  : 'Added ${tracks.length} tracks to "${pl.name}"',
            );
          }
        },
      ),
    );
  }
}

// Body
class _SideNavBody extends StatelessWidget {
  final int route;
  final bool collapsed;
  final bool isIslands;
  final bool isM3;
  final List<Playlist> playlists;
  final LibraryState library;
  final PlayerState player;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggleCollapse;
  final VoidCallback onCreatePlaylist;
  final VoidCallback onImportPlaylist;
  final ValueChanged<Playlist> onRenamePlaylist;
  final ValueChanged<Playlist> onDeletePlaylist;
  final ValueChanged<Playlist> onPlayPlaylist;
  final void Function(Playlist, List<Track>) onAddTracksToPlaylist;

  const _SideNavBody({
    required this.route,
    required this.collapsed,
    required this.isIslands,
    required this.isM3,
    required this.playlists,
    required this.library,
    required this.player,
    required this.onSelect,
    required this.onToggleCollapse,
    required this.onCreatePlaylist,
    required this.onImportPlaylist,
    required this.onRenamePlaylist,
    required this.onDeletePlaylist,
    required this.onPlayPlaylist,
    required this.onAddTracksToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final p = _NavPalette.of(context);
    final content = _buildContent(context, p);

    if (isIslands) {
      return SizedBox.expand(
        child: Container(
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: p.surfaceVariant,
            border: Border.all(color: p.border),
            borderRadius: const BorderRadius.all(Radius.circular(5)),
          ),
          child: content,
        ),
      );
    }

    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(
          color: p.surfaceVariant,
          border: Border(right: BorderSide(color: p.border)),
        ),
        child: content,
      ),
    );
  }

  Widget _buildContent(BuildContext context, _NavPalette p) {
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
        _NavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Artists',
          isActive: route == 5,
          collapsed: collapsed,
          onTap: () => onSelect(5),
        ),
        _NavItem(
          icon: Icons.history_rounded,
          activeIcon: Icons.history_rounded,
          label: 'History',
          isActive: route == 4,
          collapsed: collapsed,
          onTap: () => onSelect(4),
        ),

        if (!collapsed && library.totalTracks > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 14, 0),
            child: Text(
              '${library.totalTracks} tracks',
              style: TextStyle(
                fontSize: 9.5,
                color: p.onSurface.withValues(alpha: 0.20),
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
                padding: const EdgeInsets.only(right: 4),
                child: _IconBtn(
                  icon: Icons.upload_file_rounded,
                  tooltip: 'Import playlist (.aqp)',
                  onTap: onImportPlaylist,
                ),
              ),
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
                      color: p.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 13,
                      color: p.onSurface.withValues(alpha: 0.30),
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
                                  color: p.onSurface.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: p.onSurface.withValues(alpha: 0.14),
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
          color: p.onSurface.withValues(alpha: 0.06),
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
        const SizedBox(height: 4),
        _QueueToggleItem(collapsed: collapsed),

        const SizedBox(height: 8),
      ],
    );
  }
}

// Sub-widgets
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
    final p = _NavPalette.of(context);
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
                  ? p.onSurface.withValues(alpha: 0.04)
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
                        color: p.onSurface.withValues(alpha: 0.25),
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
                          color: p.onSurface.withValues(alpha: 0.25),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AQLOSS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: p.onSurface.withValues(alpha: 0.18),
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
    final p = _NavPalette.of(context);
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
                ? p.onSurface.withValues(alpha: 0.08)
                : _hovered
                ? p.onSurface.withValues(alpha: 0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.collapsed
              ? Center(
                  child: Icon(
                    widget.isActive ? widget.activeIcon : widget.icon,
                    size: 18,
                    color: widget.isActive
                        ? p.onSurface
                        : p.onSurface.withValues(alpha: 0.32),
                  ),
                )
              : Row(
                  children: [
                    Icon(
                      widget.isActive ? widget.activeIcon : widget.icon,
                      size: 16,
                      color: widget.isActive
                          ? p.onSurface
                          : widget.onTap == null
                          ? p.onSurface.withValues(alpha: 0.18)
                          : p.onSurface.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: widget.isActive
                              ? p.onSurface
                              : widget.onTap == null
                              ? p.onSurface.withValues(alpha: 0.18)
                              : p.onSurface.withValues(alpha: 0.55),
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
    final p = _NavPalette.of(context);
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
                  ? p.onSurface.withValues(alpha: 0.09)
                  : _hovered
                  ? p.onSurface.withValues(alpha: 0.04)
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
            : Theme.of(context).extension<AqlossTokens>()?.onSurface.withValues(
                    alpha: 0.20,
                  ) ??
                  AqlossTokens.dark.onSurface.withValues(alpha: 0.20),
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
    final p = _NavPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: p.onSurface.withValues(alpha: 0.18),
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
    final p = _NavPalette.of(context);
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
              color: p.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 13,
              color: p.onSurface.withValues(alpha: 0.32),
            ),
          ),
        ),
      ),
    );
  }
}

// Queue panel toggle
class _QueueToggleItem extends ConsumerWidget {
  final bool collapsed;
  const _QueueToggleItem({required this.collapsed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(queuePanelOpenProvider);
    final p = _NavPalette.of(context);

    return _NavItem(
      icon: Icons.queue_music_outlined,
      activeIcon: Icons.queue_music_rounded,
      label: 'Queue',
      isActive: open,
      collapsed: collapsed,
      trailing: open
          ? Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.onSurface.withValues(alpha: 0.50),
              ),
            )
          : null,
      onTap: () {
        final notifier = ref.read(queuePanelOpenProvider.notifier);
        notifier.state = !notifier.state;
      },
    );
  }
}
