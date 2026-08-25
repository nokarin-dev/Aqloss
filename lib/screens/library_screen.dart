import 'dart:io';
import 'package:aqloss/models/audio_format.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/widgets/shared/now_playing_header.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:aqloss/widgets/q_sheet.dart';
import 'package:aqloss/widgets/q_spinner.dart';
import 'package:aqloss/widgets/q_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/providers/library_nav_provider.dart';
import 'package:aqloss/widgets/shared/track_context_menu.dart';
import 'package:aqloss/widgets/track_tile.dart';
import 'package:aqloss/widgets/track_grid_item.dart';
import 'package:aqloss/widgets/shared/search_box.dart';
import 'package:aqloss/widgets/ui/app_shell.dart';
import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/ui/m3/widgets/m3_search_field.dart';
import 'package:aqloss/ui/m3/widgets/m3_page_scaffold.dart';
import 'package:aqloss/widgets/ui/ui_kit.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final isScanning = library.status == LibraryStatus.scanning;
    final viewMode = ref.watch(settingsProvider).libraryViewMode;

    if (context.isMaterial3Ui) {
      return M3PageScaffold(
        title: 'Library',
        subtitle: library.totalTracks > 0
            ? '${library.totalTracks} tracks'
            : null,
        toolbar: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: M3SearchField(
                    controller: _searchController,
                    hintText: 'Search library',
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
                const SizedBox(width: 8),
                SegmentedButton<LibraryViewMode>(
                  segments: const [
                    ButtonSegment(
                      value: LibraryViewMode.detail,
                      icon: Icon(Icons.view_list_rounded),
                    ),
                    ButtonSegment(
                      value: LibraryViewMode.grid,
                      icon: Icon(Icons.grid_view_rounded),
                    ),
                  ],
                  selected: {viewMode},
                  onSelectionChanged: (s) => ref
                      .read(settingsProvider.notifier)
                      .setLibraryViewMode(s.first),
                ),
              ],
            ),
            if (library.query.trim().isNotEmpty &&
                library.filteredTracks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => ref
                      .read(playerProvider.notifier)
                      .loadWithQueue(
                        library.filteredTracks.first,
                        library.filteredTracks,
                      ),
                  icon: const Icon(Icons.playlist_play_rounded, size: 18),
                  label: const Text('Play all'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            _M3SortBar(library: library),
          ],
        ),
        body: _TrackList(
          library: library,
          isScanning: isScanning,
          viewMode: viewMode,
        ),
      );
    }

    return AppShell(
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
                  child: SearchBox(
                    controller: _searchController,
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

          if (library.query.trim().isNotEmpty &&
              library.filteredTracks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _PlayAllBtn(
                  onTap: () => ref
                      .read(playerProvider.notifier)
                      .loadWithQueue(
                        library.filteredTracks.first,
                        library.filteredTracks,
                      ),
                ),
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
    return IconButton(
      icon: Icon(icon, size: 20),
      color: active ? cs.onSurface : cs.onSurface.withValues(alpha: 0.38),
      onPressed: onTap,
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

// Format Selection Dropdown Button for standard UI
class _FormatMenuButton extends ConsumerWidget {
  final LibraryState library;
  const _FormatMenuButton({required this.library});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(libraryProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final selectedFormats = library.selectedFormats;
    final isFormatSelected =
        library.filter == LibraryFilter.format && selectedFormats.isNotEmpty;

    final label = isFormatSelected
        ? selectedFormats.length == 1
            ? selectedFormats.first.name.toUpperCase()
            : '${selectedFormats.length} Formats'
        : 'Format';

    return GestureDetector(
      onTapDown: (TapDownDetails details) async {
        final position = details.globalPosition;
        await showMenu<void>(
          context: context,
          position: RelativeRect.fromLTRB(
            position.dx,
            position.dy,
            position.dx,
            position.dy,
          ),
          items: [
            PopupMenuItem<void>(
              enabled: false,
              child: StatefulBuilder(
                builder: (context, menuSetState) {
                  final currentSelected =
                      ref.watch(libraryProvider).selectedFormats;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Formats',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                            ),
                          ),
                          if (currentSelected.isNotEmpty)
                            InkWell(
                              onTap: () {
                                n.clearFormatFilters();
                                menuSetState(() {});
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Text(
                                  'Clear',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Divider(),
                      ...library.availableFormats.map((fmt) {
                        final isSelected = currentSelected.contains(fmt);
                        return InkWell(
                          onTap: () {
                            n.toggleFormatFilter(fmt);
                            menuSetState(() {});
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (_) {
                                    n.toggleFormatFilter(fmt);
                                    menuSetState(() {});
                                  },
                                ),
                                const SizedBox(width: 8),
                                Text(fmt.name.toUpperCase()),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        margin: const EdgeInsets.only(right: 5, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isFormatSelected
              ? cs.onSurface.withValues(alpha: 0.10)
              : Colors.transparent,
          border: Border.all(
            color: isFormatSelected
                ? cs.onSurface.withValues(alpha: 0.24)
                : cs.onSurface.withValues(alpha: 0.12),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isFormatSelected
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.38),
                fontWeight:
                    isFormatSelected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 14,
              color: isFormatSelected
                  ? cs.onSurface
                  : cs.onSurface.withValues(alpha: 0.38),
            ),
          ],
        ),
      ),
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
          if (library.availableFormats.isNotEmpty)
            _FormatMenuButton(library: library),
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

class _M3SortBar extends ConsumerWidget {
  final LibraryState library;
  const _M3SortBar({required this.library});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(libraryProvider.notifier);
    final theme = Theme.of(context);
    final selectedFormats = library.selectedFormats;
    final isFormatSelected = library.filter == LibraryFilter.format && selectedFormats.isNotEmpty;

    final formatLabel = isFormatSelected
        ? selectedFormats.length == 1
            ? selectedFormats.first.name.toUpperCase()
            : '${selectedFormats.length} Formats'
        : 'Format';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: library.filter == LibraryFilter.all,
            onSelected: (_) => n.setFilter(LibraryFilter.all),
          ),
          const SizedBox(width: 6),
          FilterChip(
            label: const Text('Lossless'),
            selected: library.filter == LibraryFilter.lossless,
            onSelected: (_) => n.setFilter(LibraryFilter.lossless),
          ),
          const SizedBox(width: 6),
          FilterChip(
            label: const Text('Hi-Res'),
            selected: library.filter == LibraryFilter.hiRes,
            onSelected: (_) => n.setFilter(LibraryFilter.hiRes),
          ),
          if (library.availableFormats.isNotEmpty) ...[
            const SizedBox(width: 6),
            PopupMenuButton<AudioFormat>(
              tooltip: 'Filter by format',
              onSelected: (format) {
                n.toggleFormatFilter(format);
              },
              itemBuilder: (context) => [
                PopupMenuItem<AudioFormat>(
                  enabled: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Formats',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (selectedFormats.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            n.clearFormatFilters();
                          },
                          child: const Text('Clear', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                ...library.availableFormats.map(
                  (fmt) {
                    final isSelected = selectedFormats.contains(fmt);
                    return PopupMenuItem<AudioFormat>(
                      value: fmt,
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(fmt.name.toUpperCase())),
                        ],
                      ),
                    );
                  },
                ),
              ],
              child: FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatLabel),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down_rounded, size: 18),
                  ],
                ),
                selected: isFormatSelected,
                onSelected: null,
              ),
            ),
          ],
          const SizedBox(width: 12),
          Text('Sort', style: theme.textTheme.labelMedium),
          const SizedBox(width: 8),
          ...[
            (SortField.artist, 'Artist'),
            (SortField.album, 'Album'),
            (SortField.title, 'Title'),
            (SortField.duration, 'Duration'),
            (SortField.format, 'Format'),
          ].map((e) {
            final selected = library.sortField == e.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.$2),
                    if (selected) ...[
                      const SizedBox(width: 4),
                      Icon(
                        library.sortOrder == SortOrder.ascending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 14,
                      ),
                    ],
                  ],
                ),
                selected: selected,
                onSelected: (_) {
                  if (library.sortField == e.$1) {
                    n.toggleSortOrder();
                  } else {
                    n.setSortField(e.$1);
                  }
                },
              ),
            );
          }),
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
class _TrackList extends ConsumerStatefulWidget {
  final LibraryState library;
  final bool isScanning;
  final LibraryViewMode viewMode;
  const _TrackList({
    required this.library,
    required this.isScanning,
    required this.viewMode,
  });

  @override
  ConsumerState<_TrackList> createState() => _TrackListState();
}

class _TrackListState extends ConsumerState<_TrackList> {
  final _scroll = ScrollController();
  static const _kItemH = 56.0;
  String? _lastScrolledPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(libraryProvider.notifier).setQuery('');
      _scrollToPlaying();
    });
  }

  @override
  void didUpdateWidget(_TrackList old) {
    super.didUpdateWidget(old);
    final currentPath = ref.read(playerProvider).currentTrack?.path;
    if (currentPath != null && currentPath != _lastScrolledPath) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToPlaying());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToPlaying() {
    if (!_scroll.hasClients) return;
    final path = ref.read(playerProvider).currentTrack?.path;
    if (path == null) return;
    final tracks = widget.library.filteredTracks;
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (widget.isScanning) {
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

    if (widget.library.status == LibraryStatus.idle ||
        widget.library.tracks.isEmpty) {
      return _Empty();
    }

    final tracks = widget.library.filteredTracks;
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

    if (widget.viewMode == LibraryViewMode.grid) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isDesktop ? 8 : 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.78,
        ),
        itemCount: tracks.length,
        itemBuilder: (ctx, i) => TrackGridItem(
          key: ValueKey(tracks[i].path),
          track: tracks[i],
          onTap: () => widget.library.query.trim().isEmpty
              ? playerNotifier.loadWithQueue(tracks[i], tracks)
              : playerNotifier.playKeepingQueue(tracks[i]),
          onLongPress: isDesktop
              ? null
              : () => _showOptions(ctx, tracks[i], playlists, playlistNotifier),
          onSecondaryTapDown: isDesktop
              ? (d) => showTrackContextMenu(
                  context: ctx,
                  globalPosition: d.globalPosition,
                  track: tracks[i],
                  ref: ref,
                )
              : null,
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      itemExtent: _kItemH,
      itemCount: tracks.length,
      itemBuilder: (ctx, i) => TrackTile(
        key: ValueKey(tracks[i].path),
        track: tracks[i],
        index: i,
        onTap: () => widget.library.query.trim().isEmpty
            ? playerNotifier.loadWithQueue(tracks[i], tracks)
            : playerNotifier.playKeepingQueue(tracks[i]),
        onLongPress: isDesktop
            ? null
            : () => _showOptions(ctx, tracks[i], playlists, playlistNotifier),
        onSecondaryTapDown: isDesktop
            ? (d) => showTrackContextMenu(
                context: ctx,
                globalPosition: d.globalPosition,
                track: tracks[i],
                ref: ref,
              )
            : null,
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
            'Add folders in Settings → Library',
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
class _TrackOptions extends ConsumerWidget {
  final Track track;
  final List playlists;
  final PlaylistNotifier notifier;
  const _TrackOptions({
    required this.track,
    required this.playlists,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const UiDivider(),
          const SizedBox(height: 8),
          UiListTile(
            title: 'Play next',
            onTap: () async {
              Navigator.pop(context);
              await ref.read(playerProvider.notifier).playNext(track);
              if (context.mounted) QToast.show(context, 'Playing next');
            },
          ),
          UiListTile(
            title: 'Add to queue',
            onTap: () {
              ref.read(playerProvider.notifier).addToQueueLast(track);
              Navigator.pop(context);
              QToast.show(context, 'Added to queue');
            },
          ),
          UiListTile(
            title: 'Show album',
            onTap: () {
              Navigator.pop(context);
              requestShowAlbum(
                context,
                ref,
                album: libraryAlbumOf(track),
                artist: libraryArtistOf(track),
              );
            },
          ),
          UiListTile(
            title: 'Show artist',
            onTap: () {
              Navigator.pop(context);
              requestShowArtist(context, ref, artist: libraryArtistOf(track));
            },
          ),
          if (playlists.isNotEmpty) ...[
            const SizedBox(height: 8),
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

class _PlaylistOptionRow extends StatelessWidget {
  final dynamic pl;
  final VoidCallback onTap;
  const _PlaylistOptionRow({required this.pl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return UiListTile(
      title: pl.name,
      subtitle: '${pl.length} tracks',
      onTap: onTap,
    );
  }
}

class _PlayAllBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _PlayAllBtn({required this.onTap});

  @override
  State<_PlayAllBtn> createState() => _PlayAllBtnState();
}

class _PlayAllBtnState extends State<_PlayAllBtn> {
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered
                ? cs.onSurface.withValues(alpha: 0.08)
                : cs.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_arrow_rounded,
                size: 14,
                color: cs.onSurface.withValues(alpha: 0.70),
              ),
              const SizedBox(width: 4),
              Text(
                'Play all',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.70),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}