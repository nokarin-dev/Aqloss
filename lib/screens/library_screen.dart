import 'package:aqloss/models/track.dart';
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

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  bool _searchOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final result = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select music folder',
    );
    if (result != null && mounted) {
      ref.read(libraryProvider.notifier).addFolder(result);
    }
  }

  void _showFolderManager(BuildContext context, LibraryState library) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FolderManagerSheet(
        folders: library.folders,
        onAdd: _pickFolder,
        onRemove: (f) =>
            ref.read(libraryProvider.notifier).removeFolder(f),
        onRescan: () =>
            ref.read(libraryProvider.notifier).rescanAll(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final tracks = library.filteredTracks;
    final isScanning = library.status == LibraryStatus.scanning;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        surfaceTintColor: Colors.transparent,
        title: _searchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Search tracks, artists, albums…',
                  hintStyle: TextStyle(color: Colors.white30),
                  border: InputBorder.none,
                ),
                onChanged: ref.read(libraryProvider.notifier).setQuery,
              )
            : const Text(
                'Library',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
        actions: [
          // Search
          IconButton(
            icon: Icon(_searchOpen ? Icons.close : Icons.search_rounded,
                color: Colors.white54, size: 20),
            onPressed: () {
              setState(() => _searchOpen = !_searchOpen);
              if (!_searchOpen) {
                _searchController.clear();
                ref.read(libraryProvider.notifier).setQuery('');
              }
            },
          ),
          // Folder management button
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.folder_open_rounded,
                    color: Colors.white54, size: 20),
                if (library.folders.length > 1)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${library.folders.length}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: library.folders.isEmpty
                ? 'Add music folder'
                : 'Manage folders (${library.folders.length})',
            onPressed: isScanning
                ? null
                : () => library.folders.isEmpty
                    ? _pickFolder()
                    : _showFolderManager(context, library),
          ),
          const SizedBox(width: 4),
        ],
        bottom: library.totalTracks > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: Row(
                    children: [
                      Text('${library.totalTracks} tracks',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white24)),
                      const SizedBox(width: 8),
                      const Text('·',
                          style: TextStyle(color: Colors.white24)),
                      const SizedBox(width: 8),
                      Text(_fmtDuration(library.totalDuration),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white24)),
                      if (library.losslessTracks.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        const Text('·',
                            style: TextStyle(color: Colors.white24)),
                        const SizedBox(width: 8),
                        Text(
                          '${library.losslessTracks.length} lossless',
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.primary.withValues(alpha: 0.5)),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: _buildBody(context, library, tracks, isScanning),
    );
  }

  Widget _buildBody(BuildContext context, LibraryState library,
      List<Track> tracks, bool isScanning) {
    if (isScanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: Colors.white24),
            ),
            const SizedBox(height: 16),
            const Text('Scanning…',
                style: TextStyle(color: Colors.white24, fontSize: 13)),
            if (library.folders.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${library.folders.length} folders',
                  style: const TextStyle(
                      color: Colors.white12, fontSize: 11),
                ),
              ),
          ],
        ),
      );
    }

    if (library.status == LibraryStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 32),
              const SizedBox(height: 12),
              Text(library.errorMessage ?? 'Unknown error',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton(
                  onPressed: _pickFolder,
                  child: const Text('Add another folder')),
            ],
          ),
        ),
      );
    }

    if (library.status == LibraryStatus.idle || library.tracks.isEmpty) {
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
              onPressed: _pickFolder,
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

    if (tracks.isEmpty && library.query.isNotEmpty) {
      return const Center(
        child: Text('No results',
            style: TextStyle(color: Colors.white24, fontSize: 13)),
      );
    }

    final notifier = ref.read(playerProvider.notifier);
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (ctx, i) => TrackTile(
        track: tracks[i],
        index: i,
        onTap: () => notifier.loadWithQueue(tracks[i], tracks),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

// Folder manager
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

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Music Folders',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
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

            // Folder list
            ...folders.map((f) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_rounded,
                      color: Colors.white38, size: 18),
                  title: Text(
                    _shortPath(f),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    f,
                    style: const TextStyle(
                        color: Colors.white24, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded,
                        size: 18, color: Colors.white24),
                    tooltip: 'Remove folder',
                    onPressed: () {
                      Navigator.pop(context);
                      onRemove(f);
                    },
                  ),
                )),

            const Divider(color: Colors.white10, height: 24),

            // Add folder button
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
