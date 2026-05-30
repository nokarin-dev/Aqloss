import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/history_provider.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/widgets/shared/now_playing_header.dart';
import 'package:aqloss/widgets/shared/search_box.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

// Artist model
class ArtistInfo {
  final String name;
  final List<Track> tracks;
  final List<String> albums;

  ArtistInfo({required this.name, required this.tracks})
    : albums = tracks.map((t) => t.album).whereType<String>().toSet().toList();

  Duration get totalDuration =>
      tracks.fold(Duration.zero, (s, t) => s + t.duration);

  String get durationLabel {
    final d = totalDuration;
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }
}

List<ArtistInfo> _groupArtists(List<Track> tracks) {
  final map = <String, List<Track>>{};
  for (final t in tracks) {
    final artist = t.albumArtist ?? t.artist ?? 'Unknown Artist';
    map.putIfAbsent(artist, () => []).add(t);
  }
  return map.entries
      .map((e) => ArtistInfo(name: e.key, tracks: e.value))
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

// Route helper
PageRoute<void> _artistDetailRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, _, _) => page,
  transitionDuration: const Duration(milliseconds: 240),
  reverseTransitionDuration: const Duration(milliseconds: 200),
  transitionsBuilder: (_, anim, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
    child: child,
  ),
);

// Screen
class ArtistsScreen extends ConsumerStatefulWidget {
  const ArtistsScreen({super.key});

  @override
  ConsumerState<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends ConsumerState<ArtistsScreen> {
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

    final all = _groupArtists(library.tracks);
    final artists = _query.isEmpty
        ? all
        : all
              .where((a) => a.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NowPlayingHeader(),
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
        if (all.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              _query.isEmpty
                  ? '${all.length} artists'
                  : '${artists.length} of ${all.length} artists',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.28),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Expanded(
          child: library.tracks.isEmpty
              ? _EmptyState()
              : artists.isEmpty
              ? Center(
                  child: Text(
                    'No results',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.24),
                    ),
                  ),
                )
              : _isDesktop
              ? _ArtistGrid(
                  artists: artists,
                  onTap: (a) => Navigator.of(
                    context,
                  ).push(_artistDetailRoute(_ArtistDetailScreen(artist: a))),
                )
              : _ArtistList(
                  artists: artists,
                  onTap: (a) => Navigator.of(
                    context,
                  ).push(_artistDetailRoute(_ArtistDetailScreen(artist: a))),
                ),
        ),
      ],
    );
  }
}

// Grid (desktop)
class _ArtistGrid extends StatelessWidget {
  final List<ArtistInfo> artists;
  final void Function(ArtistInfo) onTap;

  const _ArtistGrid({required this.artists, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: artists.length,
      itemBuilder: (_, i) =>
          _ArtistCard(artist: artists[i], onTap: () => onTap(artists[i])),
    );
  }
}

// List (mobile)
class _ArtistList extends StatelessWidget {
  final List<ArtistInfo> artists;
  final void Function(ArtistInfo) onTap;

  const _ArtistList({required this.artists, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: artists.length,
      itemBuilder: (_, i) =>
          _ArtistRow(artist: artists[i], onTap: () => onTap(artists[i])),
    );
  }
}

// Grid card
class _ArtistCard extends StatefulWidget {
  final ArtistInfo artist;
  final VoidCallback onTap;

  const _ArtistCard({required this.artist, required this.onTap});

  @override
  State<_ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<_ArtistCard> {
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
          decoration: BoxDecoration(
            color: _hovered
                ? cs.onSurface.withValues(alpha: 0.05)
                : cs.onSurface.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: cs.onSurface.withValues(alpha: _hovered ? 0.09 : 0.05),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Center(child: _ArtistAvatar(artist: widget.artist, size: 64)),
              const SizedBox(height: 10),
              Text(
                widget.artist.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withValues(alpha: 0.82),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.artist.tracks.length} tracks'
                '${widget.artist.albums.isNotEmpty ? ' · ${widget.artist.albums.length} albums' : ''}',
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurface.withValues(alpha: 0.32),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// List row (mobile)
class _ArtistRow extends StatefulWidget {
  final ArtistInfo artist;
  final VoidCallback onTap;

  const _ArtistRow({required this.artist, required this.onTap});

  @override
  State<_ArtistRow> createState() => _ArtistRowState();
}

class _ArtistRowState extends State<_ArtistRow> {
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
          duration: const Duration(milliseconds: 100),
          color: _hovered
              ? cs.onSurface.withValues(alpha: 0.03)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              _ArtistAvatar(artist: widget.artist, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.artist.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.82),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.artist.tracks.length} tracks'
                      '${widget.artist.albums.isNotEmpty ? ' · ${widget.artist.albums.length} albums' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.32),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: cs.onSurface.withValues(alpha: 0.18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Artist avatar
class _ArtistAvatar extends StatefulWidget {
  final ArtistInfo artist;
  final double size;

  const _ArtistAvatar({required this.artist, required this.size});

  @override
  State<_ArtistAvatar> createState() => _ArtistAvatarState();
}

class _ArtistAvatarState extends State<_ArtistAvatar> {
  final List<Uint8List?> _arts = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seen = <String>{};
    final paths = <String>[];
    for (final t in widget.artist.tracks) {
      final key = t.album ?? t.path;
      if (!seen.contains(key)) {
        seen.add(key);
        paths.add(t.path);
        if (paths.length >= 4) break;
      }
    }

    final arts = <Uint8List?>[];
    for (final path in paths) {
      try {
        arts.add(await backend.readAlbumArtThumbnail(path: path));
      } catch (_) {
        arts.add(null);
      }
    }

    if (mounted) {
      setState(() {
        _arts.addAll(arts);
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = widget.size;
    final radius = BorderRadius.circular(s * 0.14);

    if (!_loaded || _arts.isEmpty || _arts.every((a) => a == null)) {
      return Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.07),
          borderRadius: radius,
        ),
        child: Icon(
          Icons.person_rounded,
          size: s * 0.44,
          color: cs.onSurface.withValues(alpha: 0.22),
        ),
      );
    }

    final validArts = _arts.whereType<Uint8List>().toList();

    if (validArts.length == 1) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.memory(
          validArts[0],
          width: s,
          height: s,
          fit: BoxFit.cover,
        ),
      );
    }

    // 2×2 mosaic
    final tiles = List.generate(4, (i) {
      final bytes = i < validArts.length ? validArts[i] : null;
      return bytes != null
          ? Image.memory(bytes, fit: BoxFit.cover)
          : Container(color: cs.onSurface.withValues(alpha: 0.07));
    });

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: s,
        height: s,
        child: GridView.count(
          crossAxisCount: 2,
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: tiles,
        ),
      ),
    );
  }
}

// Detail screen
class _ArtistDetailScreen extends ConsumerWidget {
  final ArtistInfo artist;

  const _ArtistDetailScreen({required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final history = ref.watch(historyProvider);

    final albumMap = <String, List<Track>>{};
    for (final t in artist.tracks) {
      albumMap.putIfAbsent(t.album ?? 'Singles', () => []).add(t);
    }
    final albums = albumMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final artistPlayCount = artist.tracks.fold<int>(
      0,
      (sum, t) => sum + history.playCount(t.path),
    );

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          // Back nav
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(children: [_BackBtn()]),
            ),
          ),

          Expanded(
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: _ArtistHeader(
                    artist: artist,
                    playCount: artistPlayCount,
                    onPlayAll: () {
                      final sorted = List<Track>.from(artist.tracks);
                      ref
                          .read(playerProvider.notifier)
                          .loadWithQueue(sorted.first, sorted);
                    },
                  ),
                ),

                // Stats row
                if (history.loaded && artistPlayCount > 0)
                  SliverToBoxAdapter(
                    child: _ArtistStatsRow(artist: artist, history: history),
                  ),

                // Albums + tracks
                for (final entry in albums) ...[
                  SliverToBoxAdapter(
                    child: _AlbumSection(
                      albumName: entry.key,
                      tracks: entry.value,
                      history: history,
                      artistTracks: artist.tracks,
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Artist header
class _ArtistHeader extends StatelessWidget {
  final ArtistInfo artist;
  final int playCount;
  final VoidCallback onPlayAll;

  const _ArtistHeader({
    required this.artist,
    required this.playCount,
    required this.onPlayAll,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _ArtistAvatar(artist: artist, size: 80),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artist.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.4,
                    color: cs.onSurface.withValues(alpha: 0.90),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    '${artist.tracks.length} tracks',
                    if (artist.albums.isNotEmpty)
                      '${artist.albums.length} albums',
                    artist.durationLabel,
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: cs.onSurface.withValues(alpha: 0.34),
                  ),
                ),
                const SizedBox(height: 12),
                _PlayAllBtn(onTap: onPlayAll),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Stats row
class _ArtistStatsRow extends StatelessWidget {
  final ArtistInfo artist;
  final HistoryState history;

  const _ArtistStatsRow({required this.artist, required this.history});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final topEntry = artist.tracks
        .map((t) => MapEntry(t, history.playCount(t.path)))
        .where((e) => e.value > 0)
        .fold<MapEntry<Track, int>?>(
          null,
          (best, e) => best == null || e.value > best.value ? e : best,
        );

    final totalPlays = artist.tracks.fold<int>(
      0,
      (s, t) => s + history.playCount(t.path),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            _StatItem(label: 'total plays', value: '$totalPlays'),
            _StatDivider(),
            _StatItem(
              label: 'most played',
              value: topEntry?.key.displayTitle ?? '—',
              sub: topEntry != null ? '${topEntry.value}×' : null,
              flex: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final int flex;

  const _StatItem({
    required this.label,
    required this.value,
    this.sub,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.78),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (sub != null) ...[
                const SizedBox(width: 5),
                Text(
                  sub!,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: cs.onSurface.withValues(alpha: 0.34),
                  ),
                ),
              ],
            ],
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: cs.onSurface.withValues(alpha: 0.28),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 14),
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07),
  );
}

// Album section
class _AlbumSection extends ConsumerWidget {
  final String albumName;
  final List<Track> tracks;
  final HistoryState history;
  final List<Track> artistTracks;

  const _AlbumSection({
    required this.albumName,
    required this.tracks,
    required this.history,
    required this.artistTracks,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final sorted = List<Track>.from(tracks)
      ..sort((a, b) {
        final tn = (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
        return tn != 0 ? tn : a.displayTitle.compareTo(b.displayTitle);
      });

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                albumName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withValues(alpha: 0.65),
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${tracks.length} tracks',
                style: TextStyle(
                  fontSize: 10.5,
                  color: cs.onSurface.withValues(alpha: 0.26),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final track in sorted)
            _ArtistTrackRow(
              track: track,
              playCount: history.playCount(track.path),
              isPlaying:
                  ref.watch(playerProvider).currentTrack?.path == track.path,
              onTap: () => ref
                  .read(playerProvider.notifier)
                  .loadWithQueue(track, artistTracks),
            ),
        ],
      ),
    );
  }
}

// Track row
class _ArtistTrackRow extends StatefulWidget {
  final Track track;
  final int playCount;
  final bool isPlaying;
  final VoidCallback onTap;

  const _ArtistTrackRow({
    required this.track,
    required this.playCount,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<_ArtistTrackRow> createState() => _ArtistTrackRowState();
}

class _ArtistTrackRowState extends State<_ArtistTrackRow> {
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
          duration: const Duration(milliseconds: 90),
          decoration: BoxDecoration(
            color: widget.isPlaying
                ? cs.onSurface.withValues(alpha: 0.05)
                : _hovered
                ? cs.onSurface.withValues(alpha: 0.03)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            children: [
              // Track number / playing indicator
              SizedBox(
                width: 24,
                child: widget.isPlaying
                    ? Icon(
                        Icons.equalizer_rounded,
                        size: 13,
                        color: cs.onSurface.withValues(alpha: 0.60),
                      )
                    : Text(
                        widget.track.trackNumber != null
                            ? '${widget.track.trackNumber}'
                            : '·',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.28),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.track.displayTitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: widget.isPlaying
                        ? FontWeight.w500
                        : FontWeight.w400,
                    color: widget.isPlaying
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.78),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Play count badge
              if (widget.playCount > 0)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 140),
                  opacity: _hovered || widget.playCount > 0 ? 1.0 : 0.0,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${widget.playCount}×',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: 0.40),
                      ),
                    ),
                  ),
                ),
              Text(
                widget.track.durationLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.26),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Shared widgets
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered
                ? cs.onSurface.withValues(alpha: 0.10)
                : cs.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_arrow_rounded,
                size: 15,
                color: cs.onSurface.withValues(alpha: 0.70),
              ),
              const SizedBox(width: 6),
              Text(
                'Play all',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackBtn extends StatefulWidget {
  @override
  State<_BackBtn> createState() => _BackBtnState();
}

class _BackBtnState extends State<_BackBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                Icons.arrow_back_ios_new_rounded,
                size: 12,
                color: cs.onSurface.withValues(alpha: 0.44),
              ),
              const SizedBox(width: 5),
              Text(
                'Artists',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.44),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_outline_rounded,
            size: 28,
            color: cs.onSurface.withValues(alpha: 0.10),
          ),
          const SizedBox(height: 10),
          Text(
            'No artists yet',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.28),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add music folders in Settings to get started.',
            style: TextStyle(
              fontSize: 11.5,
              color: cs.onSurface.withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}
