import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/widgets/now_playing_header.dart';
import 'package:aqloss/widgets/track_tile.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

// Grouped album model
class _Album {
  final String name;
  final String artist;
  final List<Track> tracks;
  const _Album({
    required this.name,
    required this.artist,
    required this.tracks,
  });
}

List<_Album> _groupAlbums(List<Track> tracks) {
  final map = <String, List<Track>>{};
  for (final t in tracks) {
    final key = '${t.album ?? ''}|||${t.albumArtist ?? t.artist ?? ''}';
    map.putIfAbsent(key, () => []).add(t);
  }
  final albums = map.entries.map((e) {
    final parts = e.key.split('|||');
    return _Album(
      name: parts[0].isEmpty ? 'Unknown Album' : parts[0],
      artist: parts[1].isEmpty ? 'Unknown Artist' : parts[1],
      tracks: e.value
        ..sort((a, b) {
          final tn = (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
          return tn != 0 ? tn : a.displayTitle.compareTo(b.displayTitle);
        }),
    );
  }).toList();
  albums.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return albums;
}

class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final tracks = library.tracks;
    final cs = Theme.of(context).colorScheme;
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    if (library.tracks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NowPlayingHeader(),
          Expanded(
            child: Center(
              child: Text(
                'No albums yet',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.28),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final albums = _groupAlbums(tracks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NowPlayingHeader(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(
            '${albums.length} albums',
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.28),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 6 : 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.78,
            ),
            itemCount: albums.length,
            itemBuilder: (ctx, i) => _AlbumCard(
              album: albums[i],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _AlbumDetailScreen(album: albums[i]),
                ),
              ),
            ),
          ),
        ),
      ],
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

class _AlbumCardState extends State<_AlbumCard> {
  Uint8List? _art;
  bool _hovered = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadArt();
  }

  Future<void> _loadArt() async {
    try {
      final bytes = await backend.readAlbumArtThumbnail(
        path: widget.album.tracks.first.path,
      );
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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hovered
                ? cs.onSurface.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Art
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _loaded
                        ? (_art != null
                              ? Image.memory(
                                  _art!,
                                  fit: BoxFit.cover,
                                  key: const ValueKey('art'),
                                )
                              : _PlaceholderArt(
                                  key: const ValueKey('placeholder'),
                                ))
                        : Container(
                            key: const ValueKey('loading'),
                            color: cs.onSurface.withValues(alpha: 0.04),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.album.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.album.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: 0.36),
                      ),
                    ),
                    Text(
                      '${widget.album.tracks.length} tracks',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 9,
                        color: cs.onSurface.withValues(alpha: 0.22),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderArt extends StatelessWidget {
  const _PlaceholderArt({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.onSurface.withValues(alpha: 0.04),
      child: Icon(
        Icons.album_rounded,
        size: 32,
        color: cs.onSurface.withValues(alpha: 0.10),
      ),
    );
  }
}

// Album detail screen (pushed via Navigator)
class _AlbumDetailScreen extends ConsumerStatefulWidget {
  final _Album album;
  const _AlbumDetailScreen({required this.album});

  @override
  ConsumerState<_AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends ConsumerState<_AlbumDetailScreen> {
  Uint8List? _art;

  @override
  void initState() {
    super.initState();
    _loadArt();
  }

  Future<void> _loadArt() async {
    try {
      final bytes = await backend.readAlbumArt(
        path: widget.album.tracks.first.path,
      );
      if (mounted) {
        setState(() => _art = bytes != null ? Uint8List.fromList(bytes) : null);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final album = widget.album;
    final playerNotifier = ref.read(playerProvider.notifier);
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    final totalDuration = album.tracks.fold(
      Duration.zero,
      (sum, t) => sum + t.duration,
    );
    final dur = totalDuration.inHours > 0
        ? '${totalDuration.inHours}h ${totalDuration.inMinutes.remainder(60)}m'
        : '${totalDuration.inMinutes}m';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 28 : 16,
                isDesktop ? 24 : 12,
                isDesktop ? 28 : 16,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back + art row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2, right: 16),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
                            color: cs.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      // Album art
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: isDesktop ? 120 : 88,
                          height: isDesktop ? 120 : 88,
                          child: _art != null
                              ? Image.memory(_art!, fit: BoxFit.cover)
                              : Container(
                                  color: cs.onSurface.withValues(alpha: 0.06),
                                  child: Icon(
                                    Icons.album_rounded,
                                    size: isDesktop ? 44 : 32,
                                    color: cs.onSurface.withValues(alpha: 0.12),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              album.name,
                              style: TextStyle(
                                fontSize: isDesktop ? 20 : 16,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              album.artist,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.45),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${album.tracks.length} tracks · $dur',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.28),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Play all button
                            GestureDetector(
                              onTap: () {
                                playerNotifier.loadWithQueue(
                                  album.tracks.first,
                                  album.tracks,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 110),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.onSurface.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: cs.onSurface.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.play_arrow_rounded,
                                      size: 14,
                                      color: cs.onSurface.withValues(
                                        alpha: 0.70,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Play all',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurface.withValues(
                                          alpha: 0.70,
                                        ),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 1,
                    color: cs.onSurface.withValues(alpha: 0.06),
                  ),
                ],
              ),
            ),
          ),

          // Track list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => TrackTile(
                key: ValueKey(album.tracks[i].path),
                track: album.tracks[i],
                index: i,
                onTap: () =>
                    playerNotifier.loadWithQueue(album.tracks[i], album.tracks),
              ),
              childCount: album.tracks.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
