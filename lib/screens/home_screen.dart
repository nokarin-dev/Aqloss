import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'library_screen.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/models/playlist.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/widgets/mini_player_bar.dart';

const _kSidebarCollapsed = 'aqloss_sidebar_collapsed';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WindowListener {
  int _route = 0;
  bool _isMaximized = false;
  bool _sidebarCollapsed = false;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    if (_isDesktop) windowManager.addListener(this);
    _loadSidebarPref();
  }

  Future<void> _loadSidebarPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(
        () => _sidebarCollapsed = prefs.getBool(_kSidebarCollapsed) ?? false,
      );
    }
  }

  Future<void> _toggleSidebar() async {
    final next = !_sidebarCollapsed;
    setState(() => _sidebarCollapsed = next);
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_kSidebarCollapsed, next);
  }

  @override
  void dispose() {
    if (_isDesktop) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);
  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  Widget _buildScreen() {
    if (_route == 0) return const PlayerScreen();
    if (_route == 1) return const LibraryScreen();
    if (_route == 2) return const SettingsScreen();

    final playlists = ref.read(playlistProvider);
    final idx = _route - 10;
    if (idx >= 0 && idx < playlists.length) {
      return _PlaylistDetailScreen(playlist: playlists[idx]);
    }
    return const PlayerScreen();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    final player = ref.watch(playerProvider);
    final hasTrack = player.currentTrack != null;

    return Scaffold(
      body: Column(
        children: [
          if (_isDesktop) _CustomTitleBar(isMaximized: _isMaximized),
          Expanded(
            child: isWide
                ? Row(
                    children: [
                      _SideNav(
                        route: _route,
                        collapsed: _sidebarCollapsed,
                        onSelect: (r) => setState(() => _route = r),
                        onToggleCollapse: _toggleSidebar,
                      ),
                      Expanded(child: _buildScreen()),
                    ],
                  )
                : _buildScreen(),
          ),
          if (!isWide && hasTrack && _route != 0)
            MiniPlayerBar(onTap: () => setState(() => _route = 0)),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              surfaceTintColor: Colors.transparent,
              selectedIndex: _route.clamp(0, 2),
              onDestinationSelected: (i) => setState(() => _route = i),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.play_circle_outline, size: 22),
                  selectedIcon: Icon(Icons.play_circle_rounded, size: 22),
                  label: 'Now Playing',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined, size: 22),
                  selectedIcon: Icon(Icons.library_music_rounded, size: 22),
                  label: 'Library',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_outlined, size: 22),
                  selectedIcon: Icon(Icons.tune_rounded, size: 22),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }
}

class _SideNav extends ConsumerStatefulWidget {
  final int route;
  final bool collapsed;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggleCollapse;

  const _SideNav({
    required this.route,
    required this.collapsed,
    required this.onSelect,
    required this.onToggleCollapse,
  });

  @override
  ConsumerState<_SideNav> createState() => _SideNavState();
}

class _SideNavState extends ConsumerState<_SideNav>
    with SingleTickerProviderStateMixin {
  static const _collapsedWidth = 48.0;
  static const _expandedWidth = 200.0;
  late final AnimationController _ctrl;
  late final Animation<double> _widthAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: widget.collapsed ? 0 : 1,
    );
    _widthAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
  }

  @override
  void didUpdateWidget(_SideNav old) {
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
      builder: (_) => const _FolderManagerDialog(),
    );
  }

  Future<void> _createPlaylist() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => _InputDialog(
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

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistProvider);
    final library = ref.watch(libraryProvider);
    final player = ref.watch(playerProvider);
    final isScanning = library.status == LibraryStatus.scanning;
    final collapsed = widget.collapsed;
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _widthAnim,
      builder: (context, child) {
        final w =
            _collapsedWidth +
            (_expandedWidth - _collapsedWidth) * _widthAnim.value;
        return SizedBox(width: w, child: child);
      },
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          border: Border(right: BorderSide(color: cs.outline)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: _CollapseBtn(
                collapsed: collapsed,
                onTap: widget.onToggleCollapse,
              ),
            ),

            const SizedBox(height: 6),

            _NavItem(
              icon: Icons.play_circle_outline_rounded,
              activeIcon: Icons.play_circle_rounded,
              label: 'Now Playing',
              isActive: widget.route == 0,
              collapsed: collapsed,
              trailing: player.currentTrack != null
                  ? _NowPlayingDot(status: player.status)
                  : null,
              onTap: () => widget.onSelect(0),
            ),
            _NavItem(
              icon: Icons.library_music_outlined,
              activeIcon: Icons.library_music_rounded,
              label: 'Library',
              isActive: widget.route == 1,
              collapsed: collapsed,
              onTap: () => widget.onSelect(1),
            ),

            if (!collapsed) const _SectionLabel('LIBRARY'),
            if (collapsed) const SizedBox(height: 4),

            _NavItem(
              icon: Icons.folder_open_outlined,
              activeIcon: Icons.folder_open_rounded,
              label: 'Folders',
              isActive: false,
              collapsed: collapsed,
              trailing: isScanning
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.2,
                        color: cs.onSurface.withValues(alpha: 0.24),
                      ),
                    )
                  : null,
              onTap: _showFolderManager,
            ),
            _NavItem(
              icon: Icons.refresh_rounded,
              activeIcon: Icons.refresh_rounded,
              label: 'Rescan',
              isActive: false,
              collapsed: collapsed,
              onTap: isScanning
                  ? null
                  : () => ref.read(libraryProvider.notifier).rescanAll(),
            ),

            if (!collapsed && library.totalTracks > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  '${library.totalTracks} tracks',
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.withValues(alpha: 0.24),
                  ),
                ),
              ),

            if (!collapsed)
              Row(
                children: [
                  const _SectionLabel('PLAYLISTS'),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _IconBtn(
                      icon: Icons.add_rounded,
                      tooltip: 'New playlist',
                      onTap: _createPlaylist,
                    ),
                  ),
                ],
              )
            else
              Tooltip(
                message: 'New playlist',
                preferBelow: false,
                child: GestureDetector(
                  onTap: _createPlaylist,
                  child: SizedBox(
                    height: 32,
                    child: Center(
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: cs.onSurface.withValues(alpha: 0.38),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            Expanded(
              child: collapsed || playlists.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      itemCount: playlists.length,
                      itemBuilder: (ctx, i) {
                        final pl = playlists[i];
                        return DragTarget<List<Track>>(
                          onAcceptWithDetails: (details) => ref
                              .read(playlistProvider.notifier)
                              .addTracks(pl.id, details.data),
                          builder: (ctx, candidates, rejected) {
                            final isOver = candidates.isNotEmpty;
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: isOver
                                    ? cs.onSurface.withValues(alpha: 0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: isOver
                                    ? Border.all(
                                        color: cs.onSurface.withValues(
                                          alpha: 0.2,
                                        ),
                                      )
                                    : null,
                              ),
                              child: _PlaylistNavItem(
                                playlist: pl,
                                isActive: widget.route == (i + 10),
                                onTap: () => widget.onSelect(i + 10),
                                onDelete: () => ref
                                    .read(playlistProvider.notifier)
                                    .delete(pl.id),
                                onRename: () => _renamePlaylist(context, pl),
                                onPlay: pl.tracks.isNotEmpty
                                    ? () => ref
                                          .read(playerProvider.notifier)
                                          .loadWithQueue(
                                            pl.tracks.first,
                                            pl.tracks,
                                          )
                                    : null,
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),

            Divider(color: cs.outline, height: 1),
            const SizedBox(height: 4),

            _NavItem(
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings_rounded,
              label: 'Settings',
              isActive: widget.route == 2,
              collapsed: collapsed,
              onTap: () => widget.onSelect(2),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _renamePlaylist(BuildContext context, Playlist pl) async {
    final ctrl = TextEditingController(text: pl.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => _InputDialog(
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
}

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
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.collapsed ? 'Expand sidebar' : 'Collapse sidebar',
        preferBelow: false,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: widget.collapsed ? 0 : 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: _hovered
                  ? cs.onSurface.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: widget.collapsed
                ? Center(
                    child: AnimatedRotation(
                      turns: 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOutCubic,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: cs.onSurface.withValues(alpha: 0.30),
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
                          size: 18,
                          color: cs.onSurface.withValues(alpha: 0.30),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AQLOSS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.24),
                          letterSpacing: 2.5,
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
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: EdgeInsets.symmetric(
            horizontal: widget.collapsed ? 0 : 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: widget.isActive
                ? cs.onSurface.withValues(alpha: 0.08)
                : _hovered
                ? cs.onSurface.withValues(alpha: 0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: widget.collapsed
              ? Center(
                  child: Icon(
                    widget.isActive ? widget.activeIcon : widget.icon,
                    size: 18,
                    color: widget.isActive
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.38),
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
                          ? cs.onSurface.withValues(alpha: 0.24)
                          : cs.onSurface.withValues(alpha: 0.54),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.isActive
                              ? cs.onSurface
                              : widget.onTap == null
                              ? cs.onSurface.withValues(alpha: 0.24)
                              : cs.onSurface.withValues(alpha: 0.60),
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

class _FolderManagerDialog extends ConsumerWidget {
  const _FolderManagerDialog();

  Future<void> _addFolder(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select music folder',
    );
    if (result != null) {
      ref.read(libraryProvider.notifier).addFolder(result);
    }
  }

  String _shortPath(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    if (parts.length <= 3) return path;
    return '…/${parts.sublist(parts.length - 2).join('/')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final folders = library.folders;
    final isScanning = library.status == LibraryStatus.scanning;
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, minWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Music Folders',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const Spacer(),
                  if (isScanning)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: cs.onSurface.withValues(alpha: 0.38),
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: cs.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (folders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No folders added yet.',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.38),
                      fontSize: 13,
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: folders.length,
                    separatorBuilder: (_, _) =>
                        Divider(color: cs.outline, height: 1),
                    itemBuilder: (ctx, i) {
                      final folder = folders[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.folder_rounded,
                              size: 16,
                              color: cs.onSurface.withValues(alpha: 0.30),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _shortPath(folder),
                                    style: TextStyle(
                                      color: cs.onSurface.withValues(
                                        alpha: 0.70,
                                      ),
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    folder,
                                    style: TextStyle(
                                      color: cs.onSurface.withValues(
                                        alpha: 0.24,
                                      ),
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => ref
                                  .read(libraryProvider.notifier)
                                  .removeFolder(folder),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: cs.onSurface.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.remove_rounded,
                                  size: 14,
                                  color: cs.onSurface.withValues(alpha: 0.38),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Divider(color: cs.outline, height: 1),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isScanning ? null : () => _addFolder(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add folder'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.onSurface.withValues(alpha: 0.54),
                    side: BorderSide(color: cs.outline),
                    padding: const EdgeInsets.symmetric(vertical: 10),
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

class _PlaylistNavItem extends StatefulWidget {
  final Playlist playlist;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final VoidCallback? onPlay;

  const _PlaylistNavItem({
    required this.playlist,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
    this.onPlay,
  });

  @override
  State<_PlaylistNavItem> createState() => _PlaylistNavItemState();
}

class _PlaylistNavItemState extends State<_PlaylistNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: widget.isActive
                ? cs.onSurface.withValues(alpha: 0.07)
                : _hovered
                ? cs.onSurface.withValues(alpha: 0.03)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(
                Icons.queue_music_rounded,
                size: 14,
                color: widget.isActive
                    ? cs.onSurface.withValues(alpha: 0.70)
                    : cs.onSurface.withValues(alpha: 0.30),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.playlist.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isActive
                            ? cs.onSurface
                            : cs.onSurface.withValues(alpha: 0.60),
                        fontWeight: widget.isActive
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${widget.playlist.length} tracks',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: 0.24),
                      ),
                    ),
                  ],
                ),
              ),
              if (_hovered || widget.isActive)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    size: 14,
                    color: cs.onSurface.withValues(alpha: 0.38),
                  ),
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  itemBuilder: (_) => [
                    if (widget.onPlay != null)
                      PopupMenuItem(
                        value: 'play',
                        height: 36,
                        child: Text(
                          'Play',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.70),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    PopupMenuItem(
                      value: 'rename',
                      height: 36,
                      child: Text(
                        'Rename',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.70),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      height: 36,
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  ],
                  onSelected: (v) {
                    if (v == 'play') widget.onPlay?.call();
                    if (v == 'rename') widget.onRename();
                    if (v == 'delete') widget.onDelete();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistDetailScreen extends ConsumerWidget {
  final Playlist playlist;
  const _PlaylistDetailScreen({required this.playlist});

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

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
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
                          fontSize: 22,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${current.length} tracks · ${current.durationLabel}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.38),
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
              ],
            ),
          ),
          Divider(color: cs.outline, height: 1),
          Expanded(
            child: current.tracks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.queue_music_rounded,
                          size: 36,
                          color: cs.onSurface.withValues(alpha: 0.12),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No tracks yet',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.38),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Drag tracks here or long-press in Library',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.20),
                          ),
                        ),
                      ],
                    ),
                  )
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
                          color: Colors.red.withValues(alpha: 0.15),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                        ),
                        onDismissed: (_) => notifier.removeTrack(current.id, i),
                        child: _PlaylistTrackTile(
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

class _PlaylistTrackTile extends ConsumerWidget {
  final Track track;
  final int index;
  final VoidCallback onTap;
  const _PlaylistTrackTile({
    super.key,
    required this.track,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying =
        ref.watch(playerProvider).currentTrack?.path == track.path;
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 0),
      leading: SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: Text(
            isPlaying ? '▶' : '${index + 1}',
            style: TextStyle(
              fontSize: isPlaying ? 12 : 11,
              color: isPlaying
                  ? cs.onSurface
                  : cs.onSurface.withValues(alpha: 0.30),
            ),
          ),
        ),
      ),
      title: Text(
        track.displayTitle,
        style: TextStyle(
          color: isPlaying
              ? cs.onSurface
              : cs.onSurface.withValues(alpha: 0.70),
          fontSize: 13,
          fontWeight: isPlaying ? FontWeight.w500 : FontWeight.w400,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        track.displayArtist,
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.30),
          fontSize: 11,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            track.durationLabel,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.24),
            ),
          ),
          const SizedBox(width: 4),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Icon(
                Icons.drag_handle_rounded,
                size: 16,
                color: cs.onSurface.withValues(alpha: 0.24),
              ),
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _InputDialog extends StatelessWidget {
  final String title;
  final String hint;
  final String confirmLabel;
  final TextEditingController controller;
  const _InputDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        title,
        style: TextStyle(
          color: cs.onSurface,
          fontWeight: FontWeight.w400,
          fontSize: 16,
        ),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: TextStyle(color: cs.onSurface, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.30)),
          filled: true,
          fillColor: cs.onSurface.withValues(alpha: 0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.38),
              fontSize: 13,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.70),
              fontSize: 13,
            ),
          ),
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: cs.onSurface.withValues(alpha: 0.24),
          letterSpacing: 1.4,
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
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(
            icon,
            size: 14,
            color: cs.onSurface.withValues(alpha: 0.38),
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
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: status == PlayerStatus.playing
            ? Colors.greenAccent.withValues(alpha: 0.8)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _CustomTitleBar extends StatelessWidget {
  final bool isMaximized;
  const _CustomTitleBar({required this.isMaximized});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          windowManager.unmaximize();
        } else {
          windowManager.maximize();
        }
      },
      child: Container(
        height: 36,
        color: cs.surfaceContainerHighest,
        child: Row(
          children: [
            const Spacer(),
            _TitleBarBtn(
              icon: Icons.remove_rounded,
              onTap: windowManager.minimize,
            ),
            _TitleBarBtn(
              icon: isMaximized
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              onTap: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
            ),
            _TitleBarBtn(
              icon: Icons.close_rounded,
              onTap: windowManager.close,
              isClose: true,
            ),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }
}

class _TitleBarBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isClose;
  const _TitleBarBtn({
    required this.icon,
    required this.onTap,
    this.isClose = false,
  });

  @override
  State<_TitleBarBtn> createState() => _TitleBarBtnState();
}

class _TitleBarBtnState extends State<_TitleBarBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _hovered
                    ? widget.isClose
                          ? const Color(0xFFE81123)
                          : cs.onSurface.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                widget.icon,
                size: 13,
                color: _hovered && widget.isClose
                    ? Colors.white
                    : cs.onSurface.withValues(alpha: 0.54),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
