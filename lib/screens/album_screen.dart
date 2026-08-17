import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/history_provider.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/providers/library_nav_provider.dart';
import 'package:aqloss/widgets/shared/now_playing_header.dart';
import 'package:aqloss/widgets/shared/track_context_menu.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/widgets/ui/app_shell.dart';
import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/ui/m3/widgets/m3_search_field.dart';
import 'package:aqloss/ui/m3/widgets/m3_page_scaffold.dart';
import 'package:aqloss/widgets/shared/search_box.dart';
import 'package:aqloss/widgets/ui/ui_kit.dart';
import 'package:aqloss/widgets/q_toast.dart';

// Helpers
bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

bool _isCompactWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 600;

int _albumGridColumns(double width) {
  if (width < 600) return 1;
  if (width < 900) return 3;
  if (width < 1200) return 4;
  return 6;
}

String _fmtDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

// Album model
class _Album {
  final String name;
  final String artist;
  final List<Track> tracks;

  const _Album({
    required this.name,
    required this.artist,
    required this.tracks,
  });

  Duration get totalDuration =>
      tracks.fold(Duration.zero, (s, t) => s + t.duration);

  String get durationLabel {
    final d = totalDuration;
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }
}

List<_Album> _groupAlbums(List<Track> tracks) {
  final map = <String, List<Track>>{};
  for (final t in tracks) {
    final key = '${t.album ?? ''}|||${t.albumArtist ?? t.artist ?? ''}';
    map.putIfAbsent(key, () => []).add(t);
  }
  return map.entries.map((e) {
      final parts = e.key.split('|||');
      final sorted = e.value
        ..sort((a, b) {
          final tn = (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
          return tn != 0 ? tn : a.displayTitle.compareTo(b.displayTitle);
        });
      return _Album(
        name: parts[0].isEmpty ? 'Unknown Album' : parts[0],
        artist: parts[1].isEmpty ? 'Unknown Artist' : parts[1],
        tracks: sorted,
      );
    }).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

// Albums screen
class AlbumsScreen extends ConsumerStatefulWidget {
  const AlbumsScreen({super.key});

  @override
  ConsumerState<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends ConsumerState<AlbumsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeNav());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _consumeNav() {
    final req = ref.read(libraryNavProvider);
    if (req == null || req.kind != LibraryNavKind.album) return;
    ref.read(libraryNavProvider.notifier).state = null;
    if (!mounted) return;
    final albums = _groupAlbums(ref.read(libraryProvider).tracks);
    final album = _findAlbum(albums, req);
    if (album == null) return;
    Navigator.of(context).push(_fadeRoute(_AlbumDetailScreen(album: album)));
  }

  _Album? _findAlbum(List<_Album> albums, LibraryNavRequest req) {
    final wantAlbum = req.album.trim().isEmpty ? 'Unknown Album' : req.album;
    final wantArtist = req.artist.trim().isEmpty
        ? 'Unknown Artist'
        : req.artist;
    final exact = albums.where(
      (a) =>
          a.name.toLowerCase() == wantAlbum.toLowerCase() &&
          a.artist.toLowerCase() == wantArtist.toLowerCase(),
    );
    if (exact.isNotEmpty) return exact.first;
    final byName = albums.where(
      (a) => a.name.toLowerCase() == wantAlbum.toLowerCase(),
    );
    return byName.isEmpty ? null : byName.first;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LibraryNavRequest?>(libraryNavProvider, (prev, next) {
      if (next?.kind == LibraryNavKind.album) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _consumeNav();
        });
      }
    });

    final library = ref.watch(libraryProvider);
    final viewMode = ref.watch(settingsProvider).albumViewMode;
    final cs = Theme.of(context).colorScheme;

    final allAlbums = _groupAlbums(library.tracks);
    final albums = _query.isEmpty
        ? allAlbums
        : allAlbums
              .where(
                (a) =>
                    a.name.toLowerCase().contains(_query.toLowerCase()) ||
                    a.artist.toLowerCase().contains(_query.toLowerCase()),
              )
              .toList();

    void openAlbum(_Album album) {
      Navigator.of(context).push(_fadeRoute(_AlbumDetailScreen(album: album)));
    }

    void onAlbumSecondary(_Album album, TapDownDetails d) {
      showAlbumContextMenu(
        context: context,
        globalPosition: d.globalPosition,
        album: album.name,
        artist: album.artist,
        tracks: album.tracks,
        ref: ref,
      );
    }

    if (context.isMaterial3Ui) {
      return M3PageScaffold(
        title: 'Albums',
        subtitle: allAlbums.isEmpty
            ? null
            : _query.isEmpty
            ? '${allAlbums.length} albums'
            : '${albums.length} of ${allAlbums.length} albums',
        toolbar: Row(
          children: [
            Expanded(
              child: M3SearchField(
                controller: _searchCtrl,
                hintText: 'Search albums',
                onChanged: (q) => setState(() => _query = q),
                onClear: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
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
              onSelectionChanged: (s) =>
                  ref.read(settingsProvider.notifier).setAlbumViewMode(s.first),
            ),
          ],
        ),
        body: library.tracks.isEmpty
            ? const _EmptyState()
            : albums.isEmpty
            ? Center(
                child: Text(
                  'No results',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : viewMode == LibraryViewMode.grid
            ? _AlbumGrid(
                albums: albums,
                onTap: openAlbum,
                onSecondaryTapDown: onAlbumSecondary,
              )
            : _AlbumList(
                albums: albums,
                onTap: openAlbum,
                onSecondaryTapDown: onAlbumSecondary,
              ),
      );
    }

    return AppShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NowPlayingHeader(),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: SearchBox(
                    controller: _searchCtrl,
                    onChanged: (q) => setState(() => _query = q),
                    onClear: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
                ),
                const SizedBox(width: 6),
                _ViewModeButton(
                  icon: Icons.view_list_rounded,
                  active: viewMode == LibraryViewMode.detail,
                  onTap: () => ref
                      .read(settingsProvider.notifier)
                      .setAlbumViewMode(LibraryViewMode.detail),
                ),
                const SizedBox(width: 2),
                _ViewModeButton(
                  icon: Icons.grid_view_rounded,
                  active: viewMode == LibraryViewMode.grid,
                  onTap: () => ref
                      .read(settingsProvider.notifier)
                      .setAlbumViewMode(LibraryViewMode.grid),
                ),
              ],
            ),
          ),

          // Stats
          if (allAlbums.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                _query.isEmpty
                    ? '${allAlbums.length} albums'
                    : '${albums.length} of ${allAlbums.length} albums',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.28),
                ),
              ),
            ),

          const SizedBox(height: 6),

          Expanded(
            child: library.tracks.isEmpty
                ? const _EmptyState()
                : albums.isEmpty
                ? Center(
                    child: Text(
                      'No results',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.24),
                      ),
                    ),
                  )
                : viewMode == LibraryViewMode.grid
                ? _AlbumGrid(
                    albums: albums,
                    onTap: openAlbum,
                    onSecondaryTapDown: onAlbumSecondary,
                  )
                : _AlbumList(
                    albums: albums,
                    onTap: openAlbum,
                    onSecondaryTapDown: onAlbumSecondary,
                  ),
          ),
        ],
      ),
    );
  }
}

// Fade page route
PageRoute<void> _fadeRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, _, _) => page,
  transitionDuration: const Duration(milliseconds: 250),
  reverseTransitionDuration: const Duration(milliseconds: 200),
  transitionsBuilder: (_, anim, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
    child: child,
  ),
);

// Album grid
class _AlbumGrid extends StatelessWidget {
  final List<_Album> albums;
  final void Function(_Album) onTap;
  final void Function(_Album, TapDownDetails) onSecondaryTapDown;

  const _AlbumGrid({
    required this.albums,
    required this.onTap,
    required this.onSecondaryTapDown,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cols = _albumGridColumns(width);
    final compact = cols == 1;
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(compact ? 14 : 12, 2, compact ? 14 : 12, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: compact ? 14 : 6,
        crossAxisSpacing: compact ? 0 : 6,
        childAspectRatio: compact ? 0.82 : 0.72,
      ),
      itemCount: albums.length,
      itemBuilder: (_, i) => _AlbumCard(
        album: albums[i],
        onTap: () => onTap(albums[i]),
        onSecondaryTapDown: (d) => onSecondaryTapDown(albums[i], d),
      ),
    );
  }
}

class _AlbumList extends StatelessWidget {
  final List<_Album> albums;
  final void Function(_Album) onTap;
  final void Function(_Album, TapDownDetails) onSecondaryTapDown;

  const _AlbumList({
    required this.albums,
    required this.onTap,
    required this.onSecondaryTapDown,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 2, 8, 24),
      itemCount: albums.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (_, i) => _AlbumListTile(
        album: albums[i],
        onTap: () => onTap(albums[i]),
        onSecondaryTapDown: (d) => onSecondaryTapDown(albums[i], d),
      ),
    );
  }
}

class _AlbumListTile extends ConsumerWidget {
  final _Album album;
  final VoidCallback onTap;
  final void Function(TapDownDetails) onSecondaryTapDown;

  const _AlbumListTile({
    required this.album,
    required this.onTap,
    required this.onSecondaryTapDown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onSecondaryTapDown: onSecondaryTapDown,
      child: UiListTile(
        leading: _AlbumThumb(path: album.tracks.first.path, size: 56),
        title: album.name,
        subtitle: album.artist,
        onTap: onTap,
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert_rounded,
            size: 20,
            color: cs.onSurface.withValues(alpha: 0.34),
          ),
          padding: EdgeInsets.zero,
          onSelected: (value) async {
            final player = ref.read(playerProvider.notifier);
            switch (value) {
              case 'play':
                await player.loadWithQueue(album.tracks.first, album.tracks);
              case 'play_next':
                await player.playAllNext(album.tracks);
                if (context.mounted) QToast.show(context, 'Playing next');
              case 'queue':
                player.addAllToQueueLast(album.tracks);
                if (context.mounted) {
                  QToast.show(
                    context,
                    'Added ${album.tracks.length} tracks to queue',
                  );
                }
              case 'show_artist':
                requestShowArtist(context, ref, artist: album.artist);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'play', child: Text('Play album')),
            PopupMenuItem(value: 'play_next', child: Text('Play next')),
            PopupMenuItem(value: 'queue', child: Text('Add to queue')),
            PopupMenuItem(value: 'show_artist', child: Text('Show artist')),
          ],
        ),
      ),
    );
  }
}

class _AlbumThumb extends StatefulWidget {
  final String path;
  final double size;

  const _AlbumThumb({required this.path, required this.size});

  @override
  State<_AlbumThumb> createState() => _AlbumThumbState();
}

class _AlbumThumbState extends State<_AlbumThumb> {
  Uint8List? _art;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_AlbumThumb old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      setState(() {
        _art = null;
        _loaded = false;
      });
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final bytes = await backend.readAlbumArtThumbnail(path: widget.path);
      if (mounted) {
        setState(() {
          _art = bytes != null ? Uint8List.fromList(bytes) : null;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(8);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: _loaded
            ? (_art != null
                  ? Image.memory(
                      _art!,
                      fit: BoxFit.cover,
                      key: ValueKey(widget.path),
                    )
                  : _PlaceholderArt(isDark: isDark))
            : ColoredBox(color: cs.onSurface.withValues(alpha: 0.05)),
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
          color: cs.onSurface.withValues(alpha: active ? 0.72 : 0.34),
        ),
      ),
    );
  }
}

// Album card
class _AlbumCard extends StatefulWidget {
  final _Album album;
  final VoidCallback onTap;
  final void Function(TapDownDetails) onSecondaryTapDown;

  const _AlbumCard({
    required this.album,
    required this.onTap,
    required this.onSecondaryTapDown,
  });

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard>
    with SingleTickerProviderStateMixin {
  Uint8List? _art;
  bool _artLoaded = false;
  bool _pressed = false;

  // Controls hover overlay visibility
  late final AnimationController _hoverCtrl;
  late final Animation<double> _hoverAnim;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _hoverAnim = CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeOut);
    _loadArt();
  }

  @override
  void didUpdateWidget(_AlbumCard old) {
    super.didUpdateWidget(old);
    if (old.album.tracks.first.path != widget.album.tracks.first.path) {
      setState(() {
        _art = null;
        _artLoaded = false;
      });
      _loadArt();
    }
  }

  Future<void> _loadArt() async {
    try {
      final bytes = await backend.readAlbumArtThumbnail(
        path: widget.album.tracks.first.path,
      );
      if (mounted) {
        setState(() {
          _art = bytes != null ? Uint8List.fromList(bytes) : null;
          _artLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _artLoaded = true);
    }
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hoverCtrl.forward(),
      onExit: (_) => _hoverCtrl.reverse(),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        child: AnimatedScale(
          scale: _pressed ? 0.955 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Art square
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _artLoaded
                            ? (_art != null
                                  ? Image.memory(
                                      _art!,
                                      fit: BoxFit.cover,
                                      key: ValueKey(
                                        widget.album.tracks.first.path,
                                      ),
                                    )
                                  : _PlaceholderArt(
                                      key: const ValueKey('ph'),
                                      isDark: isDark,
                                    ))
                            : Container(
                                key: const ValueKey('loading'),
                                color: cs.onSurface.withValues(alpha: 0.05),
                              ),
                      ),
                    ),

                    // Hover
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: FadeTransition(
                        opacity: _hoverAnim,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.62),
                              ],
                              stops: const [0.38, 1.0],
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 18,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Info
              const SizedBox(height: 7),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.album.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                        color: cs.onSurface.withValues(alpha: 0.88),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${widget.album.artist} · ${widget.album.tracks.length} tracks",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: 0.36),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

// Placeholder art
class _PlaceholderArt extends StatelessWidget {
  final bool isDark;

  const _PlaceholderArt({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
      child: Center(
        child: Icon(
          Icons.album_rounded,
          size: 28,
          color: cs.onSurface.withValues(alpha: 0.10),
        ),
      ),
    );
  }
}

// Empty state
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.album_outlined,
            size: 36,
            color: cs.onSurface.withValues(alpha: 0.10),
          ),
          const SizedBox(height: 14),
          Text(
            'No albums yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w300,
              color: cs.onSurface.withValues(alpha: 0.36),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Add music from the Library tab',
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

// Album detail screen
class _AlbumDetailScreen extends ConsumerStatefulWidget {
  final _Album album;

  const _AlbumDetailScreen({required this.album});

  @override
  ConsumerState<_AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends ConsumerState<_AlbumDetailScreen>
    with SingleTickerProviderStateMixin {
  Uint8List? _art;
  bool _artLoaded = false;
  final _scrollCtrl = ScrollController();

  late final AnimationController _enterCtrl;
  late final Animation<double> _enterAnim;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    )..forward();
    _enterAnim = CurvedAnimation(
      parent: _enterCtrl,
      curve: Curves.easeOutCubic,
    );
    _loadArt();
  }

  Future<void> _loadArt() async {
    try {
      final bytes = await backend.readAlbumArt(
        path: widget.album.tracks.first.path,
      );
      if (mounted) {
        setState(() {
          _art = bytes != null ? Uint8List.fromList(bytes) : null;
          _artLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _artLoaded = true);
    }
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final player = ref.watch(playerProvider);
    final playerNotifier = ref.read(playerProvider.notifier);
    final album = widget.album;
    final compact = _isCompactWidth(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = compact ? 14.0 : (_isDesktop ? 24.0 : 14.0);
    final artSize = compact
        ? (screenWidth - hPad * 2).clamp(200.0, 320.0)
        : (_isDesktop ? 148.0 : 110.0);

    return UiPage(
      body: FadeTransition(
        opacity: _enterAnim,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  _isDesktop ? 20 : 12,
                  hPad,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BackButton(
                      onTap: () => Navigator.of(context).pop(),
                      label: 'Albums',
                    ),
                    SizedBox(height: compact ? 10 : (_isDesktop ? 16 : 12)),

                    // Art + metadata
                    if (compact)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _DetailArt(
                            art: _art,
                            artLoaded: _artLoaded,
                            size: artSize,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            album.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.5,
                              color: cs.onSurface,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _ArtistNameLink(
                            artist: album.artist,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface.withValues(alpha: 0.46),
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${album.tracks.length} tracks · ${album.durationLabel}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.26),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _ActionButton(
                                icon: Icons.play_arrow_rounded,
                                label: 'Play',
                                filled: true,
                                onTap: () => playerNotifier.loadWithQueue(
                                  album.tracks.first,
                                  album.tracks,
                                ),
                              ),
                              const SizedBox(width: 7),
                              _ActionButton(
                                icon: Icons.shuffle_rounded,
                                label: 'Shuffle',
                                filled: false,
                                onTap: () {
                                  final shuffled = List<Track>.from(
                                    album.tracks,
                                  )..shuffle();
                                  playerNotifier.loadWithQueue(
                                    shuffled.first,
                                    shuffled,
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _DetailArt(
                            art: _art,
                            artLoaded: _artLoaded,
                            size: artSize,
                          ),
                          SizedBox(width: _isDesktop ? 20 : 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  album.name,
                                  style: TextStyle(
                                    fontSize: _isDesktop ? 22 : 17,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.5,
                                    color: cs.onSurface,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                _ArtistNameLink(
                                  artist: album.artist,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withValues(alpha: 0.46),
                                    letterSpacing: -0.1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${album.tracks.length} tracks · ${album.durationLabel}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: cs.onSurface.withValues(alpha: 0.26),
                                  ),
                                ),
                                SizedBox(height: _isDesktop ? 14 : 10),
                                Row(
                                  children: [
                                    _ActionButton(
                                      icon: Icons.play_arrow_rounded,
                                      label: 'Play',
                                      filled: true,
                                      onTap: () => playerNotifier.loadWithQueue(
                                        album.tracks.first,
                                        album.tracks,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    _ActionButton(
                                      icon: Icons.shuffle_rounded,
                                      label: 'Shuffle',
                                      filled: false,
                                      onTap: () {
                                        final shuffled = List<Track>.from(
                                          album.tracks,
                                        )..shuffle();
                                        playerNotifier.loadWithQueue(
                                          shuffled.first,
                                          shuffled,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                    SizedBox(height: _isDesktop ? 22 : 16),
                    const UiDivider(),
                  ],
                ),
              ),
            ),

            // Column headers
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        '#',
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurface.withValues(alpha: 0.22),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'TITLE',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                    Text(
                      'TIME',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.22),
                      ),
                    ),
                    SizedBox(width: hPad),
                  ],
                ),
              ),
            ),

            // Track list
            SliverList(
              delegate: SliverChildBuilderDelegate((_, i) {
                final track = album.tracks[i];
                final isActive =
                    player.status == PlayerStatus.playing &&
                    player.currentTrack?.path == track.path;
                return _DetailTrackRow(
                  track: track,
                  index: i,
                  isActive: isActive,
                  hPad: hPad,
                  onTap: () =>
                      playerNotifier.loadWithQueue(track, album.tracks),
                  onSecondaryTapDown: (d) => showTrackContextMenu(
                    context: context,
                    globalPosition: d.globalPosition,
                    track: track,
                    ref: ref,
                  ),
                );
              }, childCount: album.tracks.length),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }
}

// Back button
class _BackButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;

  const _BackButton({required this.onTap, required this.label});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
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
          duration: const Duration(milliseconds: 110),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered
                ? cs.onSurface.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chevron_left_rounded,
                size: 16,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 3),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Detail art
class _DetailArt extends StatelessWidget {
  final Uint8List? art;
  final bool artLoaded;
  final double size;

  const _DetailArt({
    required this.art,
    required this.artLoaded,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: artLoaded
              ? (art != null
                    ? Image.memory(
                        art!,
                        fit: BoxFit.cover,
                        key: ValueKey(art.hashCode),
                      )
                    : Container(
                        key: const ValueKey('ph'),
                        color: cs.onSurface.withValues(alpha: 0.06),
                        child: Icon(
                          Icons.album_rounded,
                          size: size * 0.36,
                          color: cs.onSurface.withValues(alpha: 0.12),
                        ),
                      ))
              : Container(
                  key: const ValueKey('loading'),
                  color: cs.onSurface.withValues(alpha: 0.04),
                ),
        ),
      ),
    );
  }
}

// Action button
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgAlpha = widget.filled
        ? (_hovered ? 0.14 : 0.09)
        : (_hovered ? 0.06 : 0.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: bgAlpha),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: cs.onSurface.withValues(
                  alpha: widget.filled ? 0.14 : 0.10,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.68),
                ),
                const SizedBox(width: 5),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.68),
                    letterSpacing: -0.1,
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

// Detail track row
class _DetailTrackRow extends StatefulWidget {
  final Track track;
  final int index;
  final bool isActive;
  final double hPad;
  final VoidCallback onTap;
  final void Function(TapDownDetails) onSecondaryTapDown;

  const _DetailTrackRow({
    required this.track,
    required this.index,
    required this.isActive,
    required this.hPad,
    required this.onTap,
    required this.onSecondaryTapDown,
  });

  @override
  State<_DetailTrackRow> createState() => _DetailTrackRowState();
}

class _DetailTrackRowState extends State<_DetailTrackRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isActive = widget.isActive;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          color: _hovered
              ? cs.onSurface.withValues(alpha: 0.035)
              : Colors.transparent,
          padding: EdgeInsets.symmetric(horizontal: widget.hPad, vertical: 9),
          child: Row(
            children: [
              // Track number or playing indicator
              SizedBox(
                width: 32,
                child: isActive
                    ? const _PlayingBars()
                    : Text(
                        '${widget.index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(
                            alpha: _hovered ? 0.0 : 0.22,
                          ),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
              ),

              // Title + guest artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.track.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isActive
                            ? FontWeight.w500
                            : FontWeight.w400,
                        letterSpacing: -0.1,
                        color: isActive
                            ? cs.onSurface
                            : cs.onSurface.withValues(alpha: 0.82),
                      ),
                    ),
                    if (widget.track.artist != null &&
                        widget.track.artist != widget.track.albumArtist) ...[
                      const SizedBox(height: 1),
                      Text(
                        widget.track.displayArtist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: cs.onSurface.withValues(alpha: 0.32),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Duration
              Text(
                _fmtDuration(widget.track.duration),
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.26),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              // Love button
              Consumer(
                builder: (context, ref, _) {
                  final isLoved = ref
                      .watch(historyProvider)
                      .isLoved(widget.track);
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: _hovered || isLoved ? 1.0 : 0.0,
                    child: _AlbumLoveBtn(track: widget.track, isLoved: isLoved),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Animated playing bars
class _PlayingBars extends StatefulWidget {
  const _PlayingBars();

  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  static const List<double> _baseH = [0.50, 0.80, 0.60];
  static const List<int> _delaysMs = [0, 160, 80];

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 420 + i * 80),
      );
      Future.delayed(Duration(milliseconds: _delaysMs[i]), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
    _anims = List.generate(
      3,
      (i) => Tween<double>(
        begin: _baseH[i] * 0.25,
        end: _baseH[i],
      ).animate(CurvedAnimation(parent: _ctrls[i], curve: Curves.easeInOut)),
    );
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: Listenable.merge(_ctrls),
        builder: (_, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(3, (i) {
            return Container(
              width: 2.5,
              height: 14 * _anims[i].value,
              margin: const EdgeInsets.symmetric(horizontal: 0.8),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.70),
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// Love button
class _AlbumLoveBtn extends ConsumerStatefulWidget {
  final Track track;
  final bool isLoved;
  const _AlbumLoveBtn({required this.track, required this.isLoved});

  @override
  ConsumerState<_AlbumLoveBtn> createState() => _AlbumLoveBtnState();
}

class _AlbumLoveBtnState extends ConsumerState<_AlbumLoveBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.45,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    _busy = true;
    await _anim.forward();
    await _anim.reverse();
    await ref.read(historyProvider.notifier).toggleLove(widget.track);
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: Icon(
              widget.isLoved
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 13,
              color: widget.isLoved
                  ? const Color(0xFFFF6B8A)
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.28),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtistNameLink extends StatelessWidget {
  final String artist;
  final TextStyle style;
  final TextAlign? textAlign;

  const _ArtistNameLink({
    required this.artist,
    required this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => requestShowArtist(context, ref, artist: artist),
            child: Text(
              artist,
              textAlign: textAlign,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        );
      },
    );
  }
}
