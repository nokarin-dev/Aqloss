import 'package:aqloss/models/playlist.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/widgets/track_tile.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final result = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select music folder');
    if (result != null && mounted) {
      ref.read(libraryProvider.notifier).addFolder(result);
    }
  }

  void _showFolderManager() {
    final library = ref.read(libraryProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FolderManagerSheet(
        folders: library.folders,
        onAdd: _pickFolder,
        onRemove: (f) => ref.read(libraryProvider.notifier).removeFolder(f),
        onRescan: () => ref.read(libraryProvider.notifier).rescanAll(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final isScanning = library.status == LibraryStatus.scanning;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: _buildHeader(context, library, isScanning),
          ),
        ],
        body: Column(
          children: [
            // Tab bar
            _buildTabBar(),
            // Sort & Filter strip
            AnimatedBuilder(
              animation: _tabController,
              builder: (_, __) => _tabController.index == 0
                  ? _SortFilterBar(library: library)
                  : const SizedBox.shrink(),
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _TracksTab(library: library, isScanning: isScanning,
                      onAddFolder: _pickFolder),
                  _PlaylistsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, LibraryState library, bool isScanning) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _searchOpen
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: 'Search…',
                          hintStyle: TextStyle(color: Colors.white30),
                          border: InputBorder.none,
                        ),
                        onChanged:
                            ref.read(libraryProvider.notifier).setQuery,
                      )
                    : const Text('Library',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -0.5,
                        )),
              ),
              IconButton(
                icon: Icon(
                    _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                    color: Colors.white38,
                    size: 20),
                onPressed: () {
                  setState(() => _searchOpen = !_searchOpen);
                  if (!_searchOpen) {
                    _searchController.clear();
                    ref.read(libraryProvider.notifier).setQuery('');
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.folder_open_rounded,
                    color: Colors.white38, size: 20),
                tooltip: 'Manage folders',
                onPressed: isScanning ? null : _showFolderManager,
              ),
            ],
          ),
          if (library.totalTracks > 0) ...[
            const SizedBox(height: 4),
            _LibraryStats(library: library),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white30,
      indicatorColor: Colors.white,
      indicatorSize: TabBarIndicatorSize.label,
      indicatorWeight: 1.5,
      labelStyle: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      unselectedLabelStyle:
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
      dividerColor: Colors.white.withValues(alpha: 0.06),
      tabs: const [Tab(text: 'TRACKS'), Tab(text: 'PLAYLISTS')],
    );
  }
}

// Library stats bar
class _LibraryStats extends StatelessWidget {
  final LibraryState library;
  const _LibraryStats({required this.library});

  @override
  Widget build(BuildContext context) {
    final d = library.totalDuration;
    final timeStr = d.inHours > 0
        ? '${d.inHours}h ${d.inMinutes.remainder(60)}m'
        : '${d.inMinutes}m';
    return Wrap(
      spacing: 12,
      children: [
        _Stat('${library.totalTracks} tracks'),
        _Stat(timeStr),
        if (library.losslessTracks.isNotEmpty)
          _Stat('${library.losslessTracks.length} lossless',
              highlight: true),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final bool highlight;
  const _Stat(this.label, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(
          fontSize: 11,
          color: highlight
              ? Colors.white38
              : Colors.white24,
        ));
  }
}

// Sort & Filter strip
class _SortFilterBar extends ConsumerWidget {
  final LibraryState library;
  const _SortFilterBar({required this.library});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(libraryProvider.notifier);

    return Container(
      height: 40,
      color: const Color(0xFF0A0A0A),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Filter chips
          _FilterChip(
            label: 'All',
            selected: library.filter == LibraryFilter.all,
            onTap: () => notifier.setFilter(LibraryFilter.all),
          ),
          _FilterChip(
            label: 'Lossless',
            selected: library.filter == LibraryFilter.lossless,
            onTap: () => notifier.setFilter(LibraryFilter.lossless),
          ),
          _FilterChip(
            label: 'Hi-Res',
            selected: library.filter == LibraryFilter.hiRes,
            onTap: () => notifier.setFilter(LibraryFilter.hiRes),
          ),

          const SizedBox(width: 8),
          Container(width: 1, height: 20, color: Colors.white10,
              margin: const EdgeInsets.symmetric(vertical: 10)),
          const SizedBox(width: 8),

          // Sort pills
          _SortPill(
            label: 'Artist',
            selected: library.sortField == SortField.artist,
            order: library.sortField == SortField.artist ? library.sortOrder : null,
            onTap: () {
              if (library.sortField == SortField.artist) {
                notifier.toggleSortOrder();
              } else {
                notifier.setSortField(SortField.artist);
              }
            },
          ),
          _SortPill(
            label: 'Album',
            selected: library.sortField == SortField.album,
            order: library.sortField == SortField.album ? library.sortOrder : null,
            onTap: () {
              if (library.sortField == SortField.album) {
                notifier.toggleSortOrder();
              } else {
                notifier.setSortField(SortField.album);
              }
            },
          ),
          _SortPill(
            label: 'Title',
            selected: library.sortField == SortField.title,
            order: library.sortField == SortField.title ? library.sortOrder : null,
            onTap: () {
              if (library.sortField == SortField.title) {
                notifier.toggleSortOrder();
              } else {
                notifier.setSortField(SortField.title);
              }
            },
          ),
          _SortPill(
            label: 'Duration',
            selected: library.sortField == SortField.duration,
            order: library.sortField == SortField.duration ? library.sortOrder : null,
            onTap: () {
              if (library.sortField == SortField.duration) {
                notifier.toggleSortOrder();
              } else {
                notifier.setSortField(SortField.duration);
              }
            },
          ),
          _SortPill(
            label: 'Format',
            selected: library.sortField == SortField.format,
            order: library.sortField == SortField.format ? library.sortOrder : null,
            onTap: () {
              if (library.sortField == SortField.format) {
                notifier.toggleSortOrder();
              } else {
                notifier.setSortField(SortField.format);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6, top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
              color: selected ? Colors.white30 : Colors.white12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              color: selected ? Colors.white : Colors.white38,
              fontWeight:
                  selected ? FontWeight.w500 : FontWeight.w400,
            )),
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  final String label;
  final bool selected;
  final SortOrder? order;
  final VoidCallback onTap;
  const _SortPill({
    required this.label,
    required this.selected,
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6, top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? Colors.white70 : Colors.white24,
                )),
            if (selected && order != null) ...[
              const SizedBox(width: 2),
              Icon(
                order == SortOrder.ascending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 10,
                color: Colors.white38,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Tracks tab
class _TracksTab extends ConsumerWidget {
  final LibraryState library;
  final bool isScanning;
  final VoidCallback onAddFolder;
  const _TracksTab(
      {required this.library,
      required this.isScanning,
      required this.onAddFolder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isScanning) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: Colors.white24)),
            SizedBox(height: 16),
            Text('Scanning…',
                style: TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }

    if (library.status == LibraryStatus.idle || library.tracks.isEmpty) {
      return _EmptyState(onAddFolder: onAddFolder);
    }

    final tracks = library.filteredTracks;
    if (tracks.isEmpty) {
      return const Center(
          child: Text('No results',
              style: TextStyle(color: Colors.white24, fontSize: 13)));
    }

    final notifier = ref.read(playerProvider.notifier);
    final playlists = ref.watch(playlistProvider);
    final playlistNotifier = ref.read(playlistProvider.notifier);

    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (ctx, i) => TrackTile(
        track: tracks[i],
        index: i,
        onTap: () => notifier.loadWithQueue(tracks[i], tracks),
        onLongPress: () => _showTrackOptions(
            ctx, tracks[i], playlists, playlistNotifier),
      ),
    );
  }

  void _showTrackOptions(
    BuildContext context,
    Track track,
    List<Playlist> playlists,
    PlaylistNotifier playlistNotifier,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _TrackOptionsSheet(
        track: track,
        playlists: playlists,
        playlistNotifier: playlistNotifier,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddFolder;
  const _EmptyState({required this.onAddFolder});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.folder_open_rounded,
                size: 32, color: Colors.white24),
          ),
          const SizedBox(height: 20),
          const Text('No music loaded',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 15,
                  fontWeight: FontWeight.w300)),
          const SizedBox(height: 8),
          const Text('Add a folder to scan your music library',
              style: TextStyle(color: Colors.white24, fontSize: 12)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onAddFolder,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add folder'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white54,
              side: const BorderSide(color: Colors.white12),
            ),
          ),
        ],
      ),
    );
  }
}

// Track long-press options sheet
class _TrackOptionsSheet extends ConsumerStatefulWidget {
  final Track track;
  final List<Playlist> playlists;
  final PlaylistNotifier playlistNotifier;
  const _TrackOptionsSheet({
    required this.track,
    required this.playlists,
    required this.playlistNotifier,
  });

  @override
  ConsumerState<_TrackOptionsSheet> createState() =>
      _TrackOptionsSheetState();
}

class _TrackOptionsSheetState extends ConsumerState<_TrackOptionsSheet> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Track info
            Text(widget.track.displayTitle,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w400),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(widget.track.displayArtist,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12),
                maxLines: 1),

            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),

            // Add to existing playlist
            if (widget.playlists.isNotEmpty) ...[
              const Text('Add to playlist',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              ...widget.playlists.map((pl) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.queue_music_rounded,
                          size: 16, color: Colors.white38),
                    ),
                    title: Text(pl.name,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    subtitle: Text('${pl.length} tracks',
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 11)),
                    onTap: () {
                      widget.playlistNotifier
                          .addTrack(pl.id, widget.track);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content:
                            Text('Added to "${pl.name}"'),
                        backgroundColor: const Color(0xFF1E1E1E),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ));
                    },
                  )),
              const SizedBox(height: 8),
            ],

            // Create new playlist
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_rounded,
                    size: 16, color: Colors.white38),
              ),
              title: const Text('New playlist',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 13)),
              onTap: () async {
                Navigator.pop(context);
                final name =
                    await _promptPlaylistName(context);
                if (name != null && name.isNotEmpty) {
                  final pl = await widget.playlistNotifier.create(name);
                  await widget.playlistNotifier
                      .addTrack(pl.id, widget.track);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptPlaylistName(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('New Playlist',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w400)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Create',
                  style: TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }
}

// Playlists tab
class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistProvider);
    final notifier = ref.read(playlistProvider.notifier);
    final playerNotifier = ref.read(playerProvider.notifier);

    if (playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.queue_music_rounded,
                size: 48, color: Colors.white12),
            const SizedBox(height: 16),
            const Text('No playlists yet',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 15,
                    fontWeight: FontWeight.w300)),
            const SizedBox(height: 8),
            const Text('Long-press any track to add it to a playlist',
                style: TextStyle(color: Colors.white24, fontSize: 12)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _createPlaylist(context, notifier),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Create playlist'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54,
                side: const BorderSide(color: Colors.white12),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: playlists.length + 1, // +1 for "New" button
      itemBuilder: (ctx, i) {
        if (i == playlists.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: OutlinedButton.icon(
              onPressed: () => _createPlaylist(context, notifier),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('New playlist'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white38,
                side: const BorderSide(color: Colors.white10),
              ),
            ),
          );
        }
        final pl = playlists[i];
        return _PlaylistTile(
          playlist: pl,
          onTap: () => _openPlaylist(context, pl, playerNotifier),
          onDelete: () => notifier.delete(pl.id),
          onRename: () => _renamePlaylist(context, pl, notifier),
        );
      },
    );
  }

  Future<void> _createPlaylist(
      BuildContext context, PlaylistNotifier notifier) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Playlist',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w400)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Create',
                  style: TextStyle(color: Colors.white70))),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) notifier.create(name);
  }

  Future<void> _renamePlaylist(
      BuildContext context, Playlist pl, PlaylistNotifier notifier) async {
    final ctrl = TextEditingController(text: pl.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Playlist',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w400)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save',
                  style: TextStyle(color: Colors.white70))),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) notifier.rename(pl.id, name);
  }

  void _openPlaylist(
      BuildContext context, Playlist pl, PlayerNotifier playerNotifier) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PlaylistDetailScreen(playlist: pl),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  const _PlaylistTile({
    required this.playlist,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.queue_music_rounded,
            size: 20, color: Colors.white38),
      ),
      title: Text(playlist.name,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: Text(
          '${playlist.length} tracks · ${playlist.durationLabel}',
          style: const TextStyle(color: Colors.white38, fontSize: 12)),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz_rounded,
            color: Colors.white24, size: 18),
        color: const Color(0xFF1E1E1E),
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'rename',
              child: Text('Rename',
                  style: TextStyle(color: Colors.white70))),
          const PopupMenuItem(value: 'delete',
              child: Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
        onSelected: (v) {
          if (v == 'rename') onRename();
          if (v == 'delete') onDelete();
        },
      ),
      onTap: onTap,
    );
  }
}

// Playlist detail screen
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: Text(current.name,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w300,
                fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Colors.white38, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (current.tracks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.play_circle_outline_rounded,
                  color: Colors.white38, size: 22),
              tooltip: 'Play all',
              onPressed: () =>
                  playerNotifier.loadWithQueue(current.tracks.first, current.tracks),
            ),
        ],
      ),
      body: current.tracks.isEmpty
          ? const Center(
              child: Text('No tracks yet — long-press a track in Library',
                  style: TextStyle(color: Colors.white24, fontSize: 13),
                  textAlign: TextAlign.center))
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
                    color: Colors.red.withValues(alpha: 0.2),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child:
                        const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  ),
                  onDismissed: (_) => notifier.removeTrack(current.id, i),
                  child: TrackTile(
                    key: ValueKey('tile_${t.path}_$i'),
                    track: t,
                    index: i,
                    onTap: () =>
                        playerNotifier.loadWithQueue(t, current.tracks),
                  ),
                );
              },
            ),
    );
  }
}

// Folder manager sheet
class _FolderManagerSheet extends StatelessWidget {
  final List<String> folders;
  final VoidCallback onAdd;
  final void Function(String) onRemove;
  final VoidCallback onRescan;

  const _FolderManagerSheet({
    required this.folders,
    required this.onAdd,
    required this.onRemove,
    required this.onRescan,
  });

  String _shortPath(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    if (parts.length <= 3) return path;
    return '…/${parts.sublist(parts.length - 2).join('/')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Music Folders',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400)),
                TextButton.icon(
                  onPressed: onRescan,
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Rescan all'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white38,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...folders.map((f) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_rounded,
                      color: Colors.white38, size: 18),
                  title: Text(_shortPath(f),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(f,
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded,
                        size: 18, color: Colors.white24),
                    onPressed: () {
                      Navigator.pop(context);
                      onRemove(f);
                    },
                  ),
                )),
            const Divider(color: Colors.white10, height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onAdd();
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add another folder'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white12),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
