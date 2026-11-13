import 'package:aqloss/l10n/l10n.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/ui/shell/tokens.dart';
import 'package:aqloss/ui/shell/track_menu.dart';
import 'package:aqloss/ui/shell/album_art.dart';
import 'package:aqloss/ui/shell/love_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AlbumsPage extends ConsumerStatefulWidget {
  final String query;
  final LibraryLayout layout;

  const AlbumsPage({
    super.key,
    this.query = '',
    this.layout = LibraryLayout.details,
  });

  @override
  ConsumerState<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends ConsumerState<AlbumsPage> {
  String? _openKey;

  @override
  Widget build(BuildContext context) {
    final tracks = ref.watch(libraryProvider.select((state) => state.tracks));
    final all = _albumIndex(tracks);
    final albums = _matchingAlbums(all, widget.query);
    final open = _openKey == null
        ? null
        : all.where((album) => album.key == _openKey).firstOrNull;
    final typed = widget.query.trim().isNotEmpty;

    return Crossfade(
      child: KeyedSubtree(
        key: ValueKey(open?.key ?? 'albums'),
        child: open == null
            ? _AlbumList(
                albums: albums,
                typed: typed,
                layout: widget.layout,
                onOpen: (album) => setState(() => _openKey = album.key),
              )
            : _AlbumTracks(
                album: open,
                onBack: () => setState(() => _openKey = null),
              ),
      ),
    );
  }
}

class _AlbumList extends StatelessWidget {
  final List<_Album> albums;
  final bool typed;
  final LibraryLayout layout;
  final ValueChanged<_Album> onOpen;

  const _AlbumList({
    required this.albums,
    required this.typed,
    required this.layout,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('albums'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          trFill('albums.count', {'count': '${albums.length}'}),
          style: const TextStyle(color: textMuted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Crossfade(
            child: KeyedSubtree(
              key: ValueKey(layout),
              child: albums.isEmpty
                  ? Center(
                      child: Text(
                        tr(typed ? 'queue.no_matches' : 'albums.empty'),
                        style: const TextStyle(color: textMuted, fontSize: 15),
                      ),
                    )
                  : layout == LibraryLayout.grid
                  ? GridView.builder(
                      padding: const EdgeInsets.only(bottom: playerClearance),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.62,
                          ),
                      itemCount: albums.length,
                      itemBuilder: (context, index) {
                        final album = albums[index];
                        return _AlbumTile(
                          album: album,
                          onTap: () => onOpen(album),
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: playerClearance),
                      itemExtent: 56,
                      itemCount: albums.length,
                      itemBuilder: (context, index) {
                        final album = albums[index];
                        return _AlbumRow(
                          album: album,
                          onTap: () => onOpen(album),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlbumTracks extends ConsumerWidget {
  final _Album album;
  final VoidCallback onBack;

  const _AlbumTracks({required this.album, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(
      playerProvider.select((player) => player.currentTrack?.path),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: onBack,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.chevron_left,
                  size: 16,
                  color: textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  tr('albums'),
                  style: const TextStyle(color: textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            MiniAlbumArt(path: album.tracks.first.path, size: 84, radius: 10),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    album.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trFill('albums.tracks_duration', {
                      'count': '${album.tracks.length}',
                      'duration': album.durationLabel,
                    }),
                    style: const TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: playerClearance),
            itemExtent: 52,
            itemCount: album.tracks.length,
            itemBuilder: (context, index) {
              final track = album.tracks[index];
              return _TrackRow(
                track: track,
                number: track.trackNumber ?? index + 1,
                active: track.path == current,
                onTap: () {
                  ref
                      .read(playerProvider.notifier)
                      .loadWithQueue(track, album.tracks);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Album {
  final String name;
  final String artist;
  final List<Track> tracks;

  const _Album({
    required this.name,
    required this.artist,
    required this.tracks,
  });

  String get key => '$name\n$artist';

  String get durationLabel {
    final total = tracks.fold(
      Duration.zero,
      (sum, track) => sum + track.duration,
    );
    if (total.inHours > 0) {
      return '${total.inHours}h ${total.inMinutes.remainder(60)}m';
    }
    return '${total.inMinutes}m';
  }
}

List<Track>? _albumSource;
String? _albumStamp;
List<_Album>? _albumCache;

List<_Album> _albumIndex(List<Track> tracks) {
  final stamp =
      '${tr('library.unknown_album')}\n${tr('library.unknown_artist')}';
  if (identical(tracks, _albumSource) &&
      stamp == _albumStamp &&
      _albumCache != null) {
    return _albumCache!;
  }
  final map = <String, List<Track>>{};
  for (final track in tracks) {
    final name = track.album?.trim();
    final artist = (track.albumArtist ?? track.artist)?.trim();
    final key = '${name ?? ''}\n${artist ?? ''}';
    map.putIfAbsent(key, () => []).add(track);
  }
  final albums = <_Album>[];
  for (final entry in map.entries) {
    final parts = entry.key.split('\n');
    final name = parts[0].isEmpty ? tr('library.unknown_album') : parts[0];
    final artist = parts[1].isEmpty ? tr('library.unknown_artist') : parts[1];
    final sorted = [...entry.value]
      ..sort((a, b) {
        final byNumber = (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
        if (byNumber != 0) return byNumber;
        return a.displayTitle.compareTo(b.displayTitle);
      });
    albums.add(_Album(name: name, artist: artist, tracks: sorted));
  }
  albums.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  _albumSource = tracks;
  _albumStamp = stamp;
  _albumCache = albums;
  return albums;
}

List<_Album> _matchingAlbums(List<_Album> albums, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return albums;
  return [
    for (final album in albums)
      if (album.name.toLowerCase().contains(q) ||
          album.artist.toLowerCase().contains(q))
        album,
  ];
}

class _AlbumTile extends StatelessWidget {
  final _Album album;
  final VoidCallback onTap;

  const _AlbumTile({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return MiniAlbumArt(
                  path: album.tracks.first.path,
                  size: constraints.maxWidth,
                  radius: 10,
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              album.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumRow extends StatelessWidget {
  final _Album album;
  final VoidCallback onTap;

  const _AlbumRow({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 8),
              MiniAlbumArt(path: album.tracks.first.path, size: 40, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      trFill('albums.artist_tracks', {
                        'artist': album.artist,
                        'count': '${album.tracks.length}',
                      }),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  final Track track;
  final int number;
  final bool active;
  final VoidCallback onTap;

  const _TrackRow({
    required this.track,
    required this.number,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TrackMenu(
      track: track,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: motionOf(context),
          curve: motionCurve,
          decoration: BoxDecoration(
            color: active ? const Color(0x14FFFFFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: InkWell(
            mouseCursor: SystemMouseCursors.click,
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$number',
                      style: const TextStyle(color: textMuted, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      track.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  LoveButton(track: track),
                  Text(
                    track.durationLabel,
                    style: const TextStyle(color: textMuted, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
