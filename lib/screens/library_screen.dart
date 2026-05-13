import 'dart:io' show Platform;
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final isScanning = library.status == LibraryStatus.scanning;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _searchOpen
                      ? SizedBox(
                          key: const ValueKey('search'),
                          height: 32,
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            style: TextStyle(color: cs.onSurface, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Search tracks…',
                              hintStyle: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.30),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: ref
                                .read(libraryProvider.notifier)
                                .setQuery,
                          ),
                        )
                      : Text(
                          key: const ValueKey('title'),
                          'Library',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -0.3,
                          ),
                        ),
                ),
                const Spacer(),
                _HeaderBtn(
                  icon: _searchOpen
                      ? Icons.close_rounded
                      : Icons.search_rounded,
                  onTap: () {
                    setState(() => _searchOpen = !_searchOpen);
                    if (!_searchOpen) {
                      _searchController.clear();
                      ref.read(libraryProvider.notifier).setQuery('');
                    }
                  },
                ),
              ],
            ),
          ),

          if (library.totalTracks > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: _Stats(library: library),
            ),

          const SizedBox(height: 8),

          _SortBar(library: library),

          const SizedBox(height: 4),

          Expanded(
            child: _TrackList(library: library, isScanning: isScanning),
          ),
        ],
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Icon(
          icon,
          size: 18,
          color: cs.onSurface.withValues(alpha: 0.38),
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  final LibraryState library;
  const _Stats({required this.library});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = library.totalDuration;
    final time = d.inHours > 0
        ? '${d.inHours}h ${d.inMinutes.remainder(60)}m'
        : '${d.inMinutes}m';
    return Row(
      children: [
        _Chip('${library.totalTracks}'),
        Text(
          ' tracks · ',
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurface.withValues(alpha: 0.24),
          ),
        ),
        _Chip(time),
        if (library.losslessTracks.isNotEmpty) ...[
          Text(
            '  ·  ',
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.24),
            ),
          ),
          _Chip('${library.losslessTracks.length} lossless'),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: cs.onSurface.withValues(alpha: 0.30),
      ),
    );
  }
}

class _SortBar extends ConsumerWidget {
  final LibraryState library;
  const _SortBar({required this.library});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(libraryProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterPill(
            label: 'All',
            selected: library.filter == LibraryFilter.all,
            onTap: () => n.setFilter(LibraryFilter.all),
          ),
          _FilterPill(
            label: 'Lossless',
            selected: library.filter == LibraryFilter.lossless,
            onTap: () => n.setFilter(LibraryFilter.lossless),
          ),
          _FilterPill(
            label: 'Hi-Res',
            selected: library.filter == LibraryFilter.hiRes,
            onTap: () => n.setFilter(LibraryFilter.hiRes),
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 9),
            color: cs.outline,
          ),
          const SizedBox(width: 8),
          ...[
            (SortField.artist, 'Artist'),
            (SortField.album, 'Album'),
            (SortField.title, 'Title'),
            (SortField.duration, 'Duration'),
            (SortField.format, 'Format'),
          ].map(
            (e) => _SortPill(
              label: e.$2,
              selected: library.sortField == e.$1,
              order: library.sortField == e.$1 ? library.sortOrder : null,
              onTap: () {
                if (library.sortField == e.$1) {
                  n.toggleSortOrder();
                } else {
                  n.setSortField(e.$1);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        margin: const EdgeInsets.only(right: 5, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? cs.onSurface.withValues(alpha: 0.10)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? cs.onSurface.withValues(alpha: 0.24)
                : cs.onSurface.withValues(alpha: 0.12),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected
                ? cs.onSurface
                : cs.onSurface.withValues(alpha: 0.38),
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
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
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        margin: const EdgeInsets.only(right: 4, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? cs.onSurface.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? cs.onSurface.withValues(alpha: 0.60)
                    : cs.onSurface.withValues(alpha: 0.24),
              ),
            ),
            if (selected && order != null) ...[
              const SizedBox(width: 2),
              Icon(
                order == SortOrder.ascending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 9,
                color: cs.onSurface.withValues(alpha: 0.30),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackList extends ConsumerWidget {
  final LibraryState library;
  final bool isScanning;
  const _TrackList({required this.library, required this.isScanning});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    if (isScanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: cs.onSurface.withValues(alpha: 0.24),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Scanning…',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.24),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (library.status == LibraryStatus.idle || library.tracks.isEmpty) {
      return _Empty();
    }

    final tracks = library.filteredTracks;
    if (tracks.isEmpty) {
      return Center(
        child: Text(
          'No results',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.24),
            fontSize: 12,
          ),
        ),
      );
    }

    final playerNotifier = ref.read(playerProvider.notifier);
    final playlists = ref.watch(playlistProvider);
    final playlistNotifier = ref.read(playlistProvider.notifier);
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (ctx, i) {
        final tile = TrackTile(
          track: tracks[i],
          index: i,
          onTap: () => playerNotifier.loadWithQueue(tracks[i], tracks),
          // Long press for mobile; desktop uses right-click below
          onLongPress: isDesktop
              ? null
              : () => _showMobileOptions(
                  ctx,
                  tracks[i],
                  playlists,
                  playlistNotifier,
                ),
        );
        if (!isDesktop) return tile;
        return GestureDetector(
          onSecondaryTapUp: (details) => _showContextMenu(
            ctx,
            ref,
            details.globalPosition,
            tracks[i],
            tracks,
            playlists,
            playlistNotifier,
          ),
          child: tile,
        );
      },
    );
  }

  void _showMobileOptions(
    BuildContext context,
    Track track,
    List playlists,
    PlaylistNotifier playlistNotifier,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _TrackOptions(
        track: track,
        playlists: playlists,
        notifier: playlistNotifier,
      ),
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
    Track track,
    List<Track> allTracks,
    List playlists,
    PlaylistNotifier playlistNotifier,
  ) async {
    final playerNotifier = ref.read(playerProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final selected = await showMenu<String>(
      context: context,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 8,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'play',
          height: 36,
          child: _ContextMenuItem(
            icon: Icons.play_arrow_rounded,
            label: 'Play',
            cs: cs,
          ),
        ),
        const PopupMenuDivider(height: 1),
        if (playlists.isNotEmpty) ...[
          PopupMenuItem(
            enabled: false,
            height: 28,
            child: Text(
              'Add to playlist',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.5,
                color: cs.onSurface.withValues(alpha: 0.36),
              ),
            ),
          ),
          ...playlists.map(
            (pl) => PopupMenuItem<String>(
              value: 'playlist_${pl.id}',
              height: 36,
              child: _ContextMenuItem(
                icon: Icons.queue_music_rounded,
                label: pl.name,
                sub: '${pl.length} tracks',
                cs: cs,
              ),
            ),
          ),
          const PopupMenuDivider(height: 1),
        ],
        PopupMenuItem(
          value: 'info',
          height: 36,
          child: _ContextMenuItem(
            icon: Icons.info_outline_rounded,
            label: 'File info',
            cs: cs,
          ),
        ),
      ],
    );

    if (selected == null || !context.mounted) return;

    if (selected == 'play') {
      playerNotifier.loadWithQueue(track, allTracks);
    } else if (selected.startsWith('playlist_')) {
      final id = selected.substring('playlist_'.length);
      await playlistNotifier.addTrack(id, track);
      if (context.mounted) {
        try {
          final pl = playlists.firstWhere((p) => p.id == id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added to "${pl.name}"',
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: Theme.of(context).cardColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        } catch (_) {}
      }
    } else if (selected == 'info') {
      if (context.mounted) _showFileInfo(context, track, cs);
    }
  }

  void _showFileInfo(BuildContext context, Track track, ColorScheme cs) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          track.displayTitle,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FileInfoRow('Artist', track.displayArtist, cs),
            _FileInfoRow('Album', track.displayAlbum, cs),
            _FileInfoRow('Format', track.format, cs),
            _FileInfoRow(
              'Sample rate',
              '${(track.sampleRate / 1000).toStringAsFixed(1)} kHz',
              cs,
            ),
            if (track.bitDepth != null)
              _FileInfoRow('Bit depth', '${track.bitDepth}-bit', cs),
            _FileInfoRow('Duration', track.durationLabel, cs),
            _FileInfoRow('Size', track.fileSizeLabel, cs),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.50),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 36,
            color: cs.onSurface.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 16),
          Text(
            'No music yet',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.38),
              fontSize: 14,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add a folder via the sidebar',
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.20),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackOptions extends StatelessWidget {
  final Track track;
  final List playlists;
  final PlaylistNotifier notifier;
  const _TrackOptions({
    required this.track,
    required this.playlists,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              track.displayTitle,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              track.displayArtist,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.38),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 14),
            Divider(color: cs.outline, height: 1),
            const SizedBox(height: 10),
            if (playlists.isNotEmpty)
              Text(
                'Add to playlist',
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurface.withValues(alpha: 0.38),
                  letterSpacing: 0.5,
                ),
              ),
            const SizedBox(height: 6),
            ...playlists.map(
              (pl) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  pl.name,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.60),
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  '${pl.length} tracks',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.24),
                    fontSize: 10,
                  ),
                ),
                onTap: () {
                  notifier.addTrack(pl.id, track);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Added to "${pl.name}"',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Theme.of(context).cardColor,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
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

class _ContextMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final ColorScheme cs;
  const _ContextMenuItem({
    required this.icon,
    required this.label,
    required this.cs,
    this.sub,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 15, color: cs.onSurface.withValues(alpha: 0.50)),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.80),
            ),
          ),
          if (sub != null)
            Text(
              sub!,
              style: TextStyle(
                fontSize: 10,
                color: cs.onSurface.withValues(alpha: 0.36),
              ),
            ),
        ],
      ),
    ],
  );
}

class _FileInfoRow extends StatelessWidget {
  final String label, value;
  final ColorScheme cs;
  const _FileInfoRow(this.label, this.value, this.cs);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.38),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
      ],
    ),
  );
}
