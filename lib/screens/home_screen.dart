import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'library_screen.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/models/playlist.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/widgets/mini_player_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WindowListener {
  int _route = 0;
  bool _isMaximized = false;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    if (_isDesktop) windowManager.addListener(this);
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
    if (_route == 0) return const LibraryScreen();
    if (_route == 1) return const PlayerScreen();
    if (_route == 2) return const SettingsScreen();

    final playlists = ref.read(playlistProvider);
    final idx = _route - 10;
    if (idx >= 0 && idx < playlists.length) {
      return _PlaylistDetailScreen(playlist: playlists[idx]);
    }
    return const LibraryScreen();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    final player = ref.watch(playerProvider);
    final hasTrack = player.currentTrack != null;

    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Column(
        children: [
          if (_isDesktop) _CustomTitleBar(isMaximized: _isMaximized),
          Expanded(
            child: isWide
                ? Row(
                    children: [
                      _SideNav(
                        route: _route,
                        onSelect: (r) => setState(() => _route = r),
                      ),
                      Expanded(child: _buildScreen()),
                    ],
                  )
                : _buildScreen(),
          ),
          if (!isWide && hasTrack && _route != 1)
            MiniPlayerBar(onTap: () => setState(() => _route = 1)),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              backgroundColor: const Color(0xFF0D0D0D),
              surfaceTintColor: Colors.transparent,
              indicatorColor: Colors.white10,
              selectedIndex: _route.clamp(0, 2),
              onDestinationSelected: (i) => setState(() => _route = i),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined, size: 20),
                  selectedIcon: Icon(Icons.library_music_rounded, size: 20),
                  label: 'Library',
                ),
                NavigationDestination(
                  icon: Icon(Icons.play_circle_outline, size: 20),
                  selectedIcon: Icon(Icons.play_circle_rounded, size: 20),
                  label: 'Now Playing',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_outlined, size: 20),
                  selectedIcon: Icon(Icons.tune_rounded, size: 20),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }
}

// Sidebar
class _SideNav extends ConsumerStatefulWidget {
  final int route;
  final void Function(int) onSelect;
  const _SideNav({required this.route, required this.onSelect});

  @override
  ConsumerState<_SideNav> createState() => _SideNavState();
}

class _SideNavState extends ConsumerState<_SideNav> {
  String? _dragOverId;

  // Manage Folders popup
  void _showFolderManager() {
    showDialog(context: context, builder: (ctx) => _FolderManagerDialog());
  }

  Future<void> _createPlaylist() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => _InputDialog(
        title: 'New Playlist',
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

    return Container(
      width: 200,
      color: const Color(0xFF0D0D0D),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // Main nav
          _NavItem(
            icon: Icons.library_music_outlined,
            activeIcon: Icons.library_music_rounded,
            label: 'Library',
            isActive: widget.route == 0,
            onTap: () => widget.onSelect(0),
          ),
          _NavItem(
            icon: Icons.play_circle_outline_rounded,
            activeIcon: Icons.play_circle_rounded,
            label: 'Now Playing',
            isActive: widget.route == 1,
            trailing: player.currentTrack != null
                ? _NowPlayingDot(status: player.status)
                : null,
            onTap: () => widget.onSelect(1),
          ),

          // Library section
          const _SectionDivider('LIBRARY'),
          _NavItem(
            icon: Icons.folder_open_outlined,
            activeIcon: Icons.folder_open_rounded,
            label: 'Manage Folders',
            isActive: false,
            trailing: isScanning
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.2,
                      color: Colors.white24,
                    ),
                  )
                : null,
            onTap: _showFolderManager,
          ),
          _NavItem(
            icon: Icons.refresh_rounded,
            activeIcon: Icons.refresh_rounded,
            label: 'Rescan Library',
            isActive: false,
            onTap: isScanning
                ? null
                : () => ref.read(libraryProvider.notifier).rescanAll(),
          ),
          if (library.totalTracks > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                '${library.totalTracks} tracks',
                style: const TextStyle(fontSize: 10, color: Colors.white24),
              ),
            ),

          // Playlists section
          Row(
            children: [
              const _SectionDivider('PLAYLISTS'),
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
          ),

          // Playlist list
          Expanded(
            child: playlists.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text(
                      'No playlists yet',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.18),
                        height: 1.6,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: playlists.length,
                    itemBuilder: (_, i) {
                      final pl = playlists[i];
                      final isOver = _dragOverId == pl.id;
                      return DragTarget<Track>(
                        onWillAcceptWithDetails: (_) {
                          setState(() => _dragOverId = pl.id);
                          return true;
                        },
                        onLeave: (_) => setState(() => _dragOverId = null),
                        onAcceptWithDetails: (details) {
                          setState(() => _dragOverId = null);
                          ref
                              .read(playlistProvider.notifier)
                              .addTrack(pl.id, details.data);
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(_snackBar('Added to "${pl.name}"'));
                        },
                        builder: (_, _, _) => AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isOver
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: isOver
                                ? Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
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
                                      .loadWithQueue(pl.tracks.first, pl.tracks)
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),
          _NavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: 'Settings',
            isActive: widget.route == 2,
            onTap: () => widget.onSelect(2),
          ),
          const SizedBox(height: 8),
        ],
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

// Folder Manager Dialog
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

    return Dialog(
      backgroundColor: const Color(0xFF141414),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, minWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Text(
                    'Music Folders',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const Spacer(),
                  if (isScanning)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white24,
                      ),
                    ),
                  if (!isScanning && folders.isNotEmpty)
                    TextButton.icon(
                      onPressed: () =>
                          ref.read(libraryProvider.notifier).rescanAll(),
                      icon: const Icon(Icons.refresh_rounded, size: 13),
                      label: const Text('Rescan'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white38,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Folder list
              if (folders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No folders added yet',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 13,
                      ),
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
                        const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (ctx, i) {
                      final folder = folders[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.folder_rounded,
                              size: 16,
                              color: Colors.white30,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _shortPath(folder),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    folder,
                                    style: const TextStyle(
                                      color: Colors.white24,
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
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.remove_rounded,
                                  size: 14,
                                  color: Colors.white38,
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
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 12),

              // Add folder button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isScanning ? null : () => _addFolder(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add folder'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white12),
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

// Playlist nav item
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
                ? Colors.white.withValues(alpha: 0.07)
                : _hovered
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(
                Icons.queue_music_rounded,
                size: 14,
                color: widget.isActive ? Colors.white70 : Colors.white30,
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
                        color: widget.isActive ? Colors.white : Colors.white60,
                        fontWeight: widget.isActive
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${widget.playlist.length} tracks',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white24,
                      ),
                    ),
                  ],
                ),
              ),
              // Context menu
              if (_hovered || widget.isActive)
                GestureDetector(
                  onTap: () {},
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      size: 14,
                      color: Colors.white38,
                    ),
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    itemBuilder: (_) => [
                      if (widget.onPlay != null)
                        const PopupMenuItem(
                          value: 'play',
                          height: 36,
                          child: Text(
                            'Play',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'rename',
                        height: 36,
                        child: Text(
                          'Rename',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        height: 36,
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    onSelected: (v) {
                      if (v == 'play') widget.onPlay?.call();
                      if (v == 'rename') widget.onRename();
                      if (v == 'delete') widget.onDelete();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Playlist detail
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

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${current.length} tracks · ${current.durationLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white38,
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: current.tracks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.queue_music_rounded,
                          size: 36,
                          color: Colors.white12,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No tracks yet',
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Drag tracks here or long-press in Library',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.2),
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

// Playlist track tile
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
              color: isPlaying ? Colors.white : Colors.white30,
            ),
          ),
        ),
      ),
      title: Text(
        track.displayTitle,
        style: TextStyle(
          color: isPlaying ? Colors.white : Colors.white70,
          fontSize: 13,
          fontWeight: isPlaying ? FontWeight.w500 : FontWeight.w400,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        track.displayArtist,
        style: const TextStyle(color: Colors.white30, fontSize: 11),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            track.durationLabel,
            style: const TextStyle(fontSize: 11, color: Colors.white24),
          ),
          const SizedBox(width: 4),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Icon(
                Icons.drag_handle_rounded,
                size: 16,
                color: Colors.white24,
              ),
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

// Shared helpers
SnackBar _snackBar(String text) => SnackBar(
  content: Text(text, style: const TextStyle(fontSize: 12)),
  backgroundColor: const Color(0xFF1E1E1E),
  behavior: SnackBarBehavior.floating,
  duration: const Duration(seconds: 2),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
);

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
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w400,
          fontSize: 16,
        ),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
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
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(
            confirmLabel,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

// Nav helpers
class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
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
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: widget.isActive
                ? Colors.white.withValues(alpha: 0.08)
                : _hovered
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                widget.isActive ? widget.activeIcon : widget.icon,
                size: 16,
                color: widget.isActive
                    ? Colors.white
                    : widget.onTap == null
                    ? Colors.white24
                    : Colors.white54,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isActive
                        ? Colors.white
                        : widget.onTap == null
                        ? Colors.white24
                        : Colors.white60,
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
  }
}

class _SectionDivider extends StatelessWidget {
  final String label;
  const _SectionDivider(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.white24,
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
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, size: 14, color: Colors.white38),
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
            : Colors.white24,
        shape: BoxShape.circle,
      ),
    );
  }
}

// Custom title bar
class _CustomTitleBar extends StatelessWidget {
  final bool isMaximized;
  const _CustomTitleBar({required this.isMaximized});

  @override
  Widget build(BuildContext context) {
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
        color: const Color(0xFF080808),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Text(
              'AQLOSS',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w400,
                color: Colors.white24,
                letterSpacing: 3,
              ),
            ),
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
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 30,
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          color: _hovered
              ? widget.isClose
                    ? const Color(0xFFE81123)
                    : Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 13,
            color: _hovered && widget.isClose ? Colors.white : Colors.white38,
          ),
        ),
      ),
    );
  }
}
