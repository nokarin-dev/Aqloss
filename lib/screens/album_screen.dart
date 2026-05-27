import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/history_provider.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/widgets/shared/now_playing_header.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/widgets/shared/search_box.dart';

// Helpers
bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

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
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NowPlayingHeader(),

        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: SearchBox(
            controller: _searchCtrl,
            onChanged: (q) => setState(() => _query = q),
            onClear: () {
              _searchCtrl.clear();
              setState(() => _query = '');
            },
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
              : _AlbumGrid(
                  albums: albums,
                  onTap: (album) => Navigator.of(
                    context,
                  ).push(_fadeRoute(_AlbumDetailScreen(album: album))),
                ),
        ),
      ],
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

  const _AlbumGrid({required this.albums, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cols = _isDesktop ? 6 : 3;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.72,
      ),
      itemCount: albums.length,
      itemBuilder: (_, i) =>
          _AlbumCard(album: albums[i], onTap: () => onTap(albums[i])),
    );
  }
}

// Album card
class _AlbumCard extends StatefulWidget {
  final _Album album;
  final VoidCallback onTap;

  const _AlbumCard({required this.album, required this.onTap});

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

// ── Album detail screen ───────────────────────────────────────────────────────

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
    final hPad = _isDesktop ? 24.0 : 14.0;
    final artSize = _isDesktop ? 148.0 : 110.0;

    return Scaffold(
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
                    SizedBox(height: _isDesktop ? 16 : 12),

                    // Art + metadata
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
                              Text(
                                album.artist,
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
                    Container(
                      height: 1,
                      color: cs.onSurface.withValues(alpha: 0.06),
                    ),
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

  const _DetailTrackRow({
    required this.track,
    required this.index,
    required this.isActive,
    required this.hPad,
    required this.onTap,
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

  // Base heights and stagger delays per bar
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
