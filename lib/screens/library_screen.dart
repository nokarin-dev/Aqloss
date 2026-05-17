import 'package:aqloss/models/track.dart';
import 'package:aqloss/widgets/now_playing_header.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:aqloss/widgets/q_sheet.dart';
import 'package:aqloss/widgets/q_spinner.dart';
import 'package:aqloss/widgets/q_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/widgets/track_tile.dart';
import 'package:aqloss/widgets/track_grid_item.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final isScanning = library.status == LibraryStatus.scanning;
    final viewMode = ref.watch(settingsProvider).libraryViewMode;

    return ColoredBox(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NowPlayingHeader(),

          // Search + view toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: _SearchBox(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: (q) {
                      ref.read(libraryProvider.notifier).setQuery(q);
                      setState(() {});
                    },
                    onClear: () {
                      _searchController.clear();
                      ref.read(libraryProvider.notifier).setQuery('');
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 6),
                _ViewModeButton(
                  icon: Icons.view_list_rounded,
                  active: viewMode == LibraryViewMode.detail,
                  onTap: () => ref
                      .read(settingsProvider.notifier)
                      .setLibraryViewMode(LibraryViewMode.detail),
                ),
                const SizedBox(width: 2),
                _ViewModeButton(
                  icon: Icons.grid_view_rounded,
                  active: viewMode == LibraryViewMode.grid,
                  onTap: () => ref
                      .read(settingsProvider.notifier)
                      .setLibraryViewMode(LibraryViewMode.grid),
                ),
              ],
            ),
          ),

          if (library.totalTracks > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: _Stats(library: library),
            ),

          const SizedBox(height: 4),
          _SortBar(library: library),
          const SizedBox(height: 4),

          Expanded(
            child: _TrackList(
              library: library,
              isScanning: isScanning,
              viewMode: viewMode,
            ),
          ),
        ],
      ),
    );
  }
}

// Search box
class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: focusNode.requestFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 36,
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Icon(
              Icons.search_rounded,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.28),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: EditableText(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                style: TextStyle(color: cs.onSurface, fontSize: 13),
                cursorColor: cs.onSurface.withValues(alpha: 0.60),
                backgroundCursorColor: Colors.transparent,
                cursorWidth: 1.2,
                cursorRadius: const Radius.circular(1),
                selectionColor: cs.onSurface.withValues(alpha: 0.15),
              ),
            ),
            if (controller.text.isNotEmpty)
              GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: cs.onSurface.withValues(alpha: 0.28),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Stats row
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
    final style = TextStyle(
      fontSize: 11,
      color: cs.onSurface.withValues(alpha: 0.28),
    );
    return Text(
      '${library.totalTracks} tracks · $time'
      '${library.losslessTracks.isNotEmpty ? ' · ${library.losslessTracks.length} lossless' : ''}',
      style: style,
    );
  }
}

// Sort / filter bar
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
            color: cs.onSurface.withValues(alpha: 0.08),
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

// Track list
class _TrackList extends ConsumerWidget {
  final LibraryState library;
  final bool isScanning;
  final LibraryViewMode viewMode;
  const _TrackList({
    required this.library,
    required this.isScanning,
    required this.viewMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    if (isScanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QSpinner(size: 18, color: cs.onSurface.withValues(alpha: 0.24)),
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

    if (viewMode == LibraryViewMode.grid) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.78,
        ),
        itemCount: tracks.length,
        itemBuilder: (ctx, i) => TrackGridItem(
          track: tracks[i],
          onTap: () => playerNotifier.loadWithQueue(tracks[i], tracks),
          onLongPress: () =>
              _showOptions(ctx, tracks[i], playlists, playlistNotifier),
        ),
      );
    }

    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (ctx, i) => TrackTile(
        key: ValueKey(tracks[i].path),
        track: tracks[i],
        index: i,
        onTap: () => playerNotifier.loadWithQueue(tracks[i], tracks),
        onLongPress: () =>
            _showOptions(ctx, tracks[i], playlists, playlistNotifier),
      ),
    );
  }

  void _showOptions(
    BuildContext ctx,
    Track track,
    List playlists,
    PlaylistNotifier playlistNotifier,
  ) {
    showQSheet(
      context: ctx,
      builder: (_) => _TrackOptions(
        track: track,
        playlists: playlists,
        notifier: playlistNotifier,
      ),
    );
  }
}

// Empty state
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
            color: cs.onSurface.withValues(alpha: 0.10),
          ),
          const SizedBox(height: 16),
          Text(
            'No music yet',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.36),
              fontSize: 14,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add a folder via the sidebar',
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

// Track options sheet
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // drag handle
          Center(
            child: Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.10),
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
              color: cs.onSurface.withValues(alpha: 0.36),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 14),
          // custom divider — no Material Divider widget
          Container(height: 1, color: cs.onSurface.withValues(alpha: 0.06)),
          const SizedBox(height: 12),
          if (playlists.isNotEmpty) ...[
            Text(
              'Add to playlist',
              style: TextStyle(
                fontSize: 10,
                color: cs.onSurface.withValues(alpha: 0.32),
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
          ...playlists.map(
            (pl) => _PlaylistOptionRow(
              pl: pl,
              onTap: () {
                notifier.addTrack(pl.id, track);
                Navigator.pop(context);
                QToast.show(context, 'Added to "${pl.name}"');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistOptionRow extends StatefulWidget {
  final dynamic pl;
  final VoidCallback onTap;
  const _PlaylistOptionRow({required this.pl, required this.onTap});
  @override
  State<_PlaylistOptionRow> createState() => _PlaylistOptionRowState();
}

class _PlaylistOptionRowState extends State<_PlaylistOptionRow> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
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
              ? cs.onSurface.withValues(alpha: 0.04)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.pl.name,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.60),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.pl.length} tracks',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.24),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// View mode button
class _ViewModeButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ViewModeButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: active
              ? cs.onSurface.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? cs.onSurface.withValues(alpha: 0.20)
                : cs.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: active
              ? cs.onSurface.withValues(alpha: 0.70)
              : cs.onSurface.withValues(alpha: 0.28),
        ),
      ),
    );
  }
}
