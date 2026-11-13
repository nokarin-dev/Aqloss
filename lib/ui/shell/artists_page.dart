import 'package:aqloss/l10n/l10n.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/history_provider.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/ui/shell/album_art.dart';
import 'package:aqloss/ui/shell/love_button.dart';
import 'package:aqloss/ui/shell/tokens.dart';
import 'package:aqloss/ui/shell/track_menu.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ArtistsPage extends ConsumerStatefulWidget {
  final VoidCallback onOpenSettings;

  const ArtistsPage({super.key, required this.onOpenSettings});

  @override
  ConsumerState<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends ConsumerState<ArtistsPage> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  String? _artist;
  String? _album;

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracks = ref.watch(libraryProvider.select((state) => state.tracks));
    final all = _artistIndex(tracks);
    final artists = _matchingArtists(all, _query.text);
    final open = _artist == null
        ? null
        : all.where((item) => item.name == _artist).firstOrNull;
    final album = open == null || _album == null
        ? null
        : open.albums.where((item) => item.name == _album).firstOrNull;
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final view = album != null
        ? 'album'
        : open != null
        ? 'artist'
        : 'list';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        wide ? 50 : 20,
        wide ? 50 : 24,
        wide ? 50 : 20,
        24,
      ),
      child: Crossfade(
        child: KeyedSubtree(
          key: ValueKey(
            view == 'list' ? 'artists' : '$view|${open?.name}|${album?.name}',
          ),
          child: album != null && open != null
              ? _AlbumTracks(
                  album: album,
                  onBack: () => setState(() => _album = null),
                )
              : open == null
              ? _ArtistList(
                  artists: artists,
                  wide: wide,
                  typed: _query.text.trim().isNotEmpty,
                  query: _query,
                  focus: _focus,
                  onQuery: () => setState(() {}),
                  onOpen: (name) => setState(() {
                    _artist = name;
                    _album = null;
                  }),
                  onOpenSettings: widget.onOpenSettings,
                )
              : _ArtistDetail(
                  artist: open,
                  onBack: () => setState(() {
                    _artist = null;
                    _album = null;
                  }),
                  onAlbum: (name) => setState(() => _album = name),
                ),
        ),
      ),
    );
  }
}

class _ArtistList extends StatelessWidget {
  final List<_Artist> artists;
  final bool wide;
  final bool typed;
  final TextEditingController query;
  final FocusNode focus;
  final VoidCallback onQuery;
  final ValueChanged<String> onOpen;
  final VoidCallback onOpenSettings;

  const _ArtistList({
    required this.artists,
    required this.wide,
    required this.typed,
    required this.query,
    required this.focus,
    required this.onQuery,
    required this.onOpen,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wide)
          Row(
            children: [
              Expanded(child: Text(tr('artists'), style: _title)),
              _Search(controller: query, focus: focus, onChanged: onQuery),
            ],
          )
        else ...[
          Text(tr('artists'), style: _title),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              return _Search(
                controller: query,
                focus: focus,
                onChanged: onQuery,
                width: constraints.maxWidth,
              );
            },
          ),
        ],
        const SizedBox(height: 18),
        Expanded(
          child: artists.isEmpty
              ? typed
                    ? Center(
                        child: Text(
                          tr('queue.no_matches'),
                          style: const TextStyle(
                            color: textMuted,
                            fontSize: 15,
                          ),
                        ),
                      )
                    : _EmptyArtists(onOpenSettings: onOpenSettings)
              : GridView.builder(
                  padding: const EdgeInsets.only(bottom: playerClearance),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 18,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: artists.length,
                  itemBuilder: (context, index) {
                    final artist = artists[index];
                    return _CoverCard(
                      path: artist.cover.path,
                      title: artist.coverLabel,
                      subtitle: artist.name,
                      onTap: () => onOpen(artist.name),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ArtistDetail extends ConsumerWidget {
  final _Artist artist;
  final VoidCallback onBack;
  final ValueChanged<String> onAlbum;

  const _ArtistDetail({
    required this.artist,
    required this.onBack,
    required this.onAlbum,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final played = _mostPlayed(artist.tracks, history);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BackTitle(label: artist.name, onBack: onBack),
        const SizedBox(height: 22),
        Text(tr('playlists.most_played'), style: _section),
        const SizedBox(height: 10),
        _PlayedRow(
          track: played,
          onTap: () {
            ref
                .read(playerProvider.notifier)
                .loadWithQueue(played, artist.tracks);
          },
        ),
        const SizedBox(height: 22),
        Text(tr('sidebar.albums'), style: _section),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: playerClearance),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              mainAxisSpacing: 18,
              crossAxisSpacing: 18,
              childAspectRatio: 0.72,
            ),
            itemCount: artist.albums.length,
            itemBuilder: (context, index) {
              final album = artist.albums[index];
              return _CoverCard(
                path: album.tracks.first.path,
                title: album.name,
                subtitle: artist.name,
                onTap: () => onAlbum(album.name),
              );
            },
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
        _BackTitle(label: album.name, onBack: onBack),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: playerClearance),
            itemCount: album.tracks.length,
            itemBuilder: (context, index) {
              final track = album.tracks[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PlayedRow(
                  track: track,
                  active: track.path == current,
                  onTap: () {
                    ref
                        .read(playerProvider.notifier)
                        .loadWithQueue(track, album.tracks);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlayedRow extends StatelessWidget {
  final Track track;
  final bool active;
  final VoidCallback onTap;

  const _PlayedRow({
    required this.track,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return TrackMenu(
      track: track,
      child: Material(
        color: active ? const Color(0x14FFFFFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2D2D2D)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Row(
                children: [
                  MiniAlbumArt(path: track.path, size: 40, radius: 6),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          track.uiArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  LoveButton(track: track),
                  const SizedBox(width: 8),
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

class _CoverCard extends StatelessWidget {
  final String path;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CoverCard({
    required this.path,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return MiniAlbumArt(
                  path: path,
                  size: constraints.maxWidth,
                  radius: 8,
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
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

class _EmptyArtists extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _EmptyArtists({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onOpenSettings,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2D2D2D)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.search, size: 18, color: textMuted),
                  const SizedBox(height: 10),
                  Text(
                    tr('artists.empty'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('artists.empty_hint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Search extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onChanged;
  final double width;

  const _Search({
    required this.controller,
    required this.focus,
    required this.onChanged,
    this.width = 220,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 34,
      child: CupertinoTextField(
        controller: controller,
        focusNode: focus,
        onChanged: (_) => onChanged(),
        placeholder: tr('artists.search'),
        placeholderStyle: const TextStyle(color: textMuted, fontSize: 13),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        prefix: const Padding(
          padding: EdgeInsets.only(left: 10),
          child: Icon(CupertinoIcons.search, size: 14, color: textMuted),
        ),
        cursorColor: Colors.white,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2D2D2D)),
        ),
      ),
    );
  }
}

class _BackTitle extends StatelessWidget {
  final String label;
  final VoidCallback onBack;

  const _BackTitle({required this.label, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onBack,
        child: Row(
          children: [
            const Icon(CupertinoIcons.chevron_left, size: 18, color: textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Artist {
  final String name;
  final List<Track> tracks;
  List<_Album>? _albums;

  _Artist({required this.name, required this.tracks});

  List<_Album> get albums => _albums ??= _albumsOf(tracks);

  Track get cover => tracks.first;

  String get coverLabel {
    final album = cover.album?.trim();
    if (album != null && album.isNotEmpty) return album;
    return cover.displayTitle;
  }
}

class _Album {
  final String name;
  final List<Track> tracks;

  const _Album({required this.name, required this.tracks});
}

List<Track>? _artistSource;
String? _artistStamp;
List<_Artist>? _artistCache;

List<_Artist> _artistIndex(List<Track> tracks) {
  final stamp = tr('library.unknown_album');
  if (identical(tracks, _artistSource) &&
      stamp == _artistStamp &&
      _artistCache != null) {
    return _artistCache!;
  }
  final byName = <String, List<Track>>{};
  for (final track in tracks) {
    byName.putIfAbsent(track.displayArtist, () => []).add(track);
  }
  final artists = [
    for (final entry in byName.entries)
      _Artist(name: entry.key, tracks: entry.value),
  ];
  artists.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  _artistSource = tracks;
  _artistStamp = stamp;
  _artistCache = artists;
  return artists;
}

List<_Artist> _matchingArtists(List<_Artist> artists, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return artists;
  return [
    for (final artist in artists)
      if (artist.name.toLowerCase().contains(needle)) artist,
  ];
}

List<_Album> _albumsOf(List<Track> tracks) {
  final byName = <String, List<Track>>{};
  for (final track in tracks) {
    final name = track.album?.trim();
    final label = name == null || name.isEmpty
        ? tr('library.unknown_album')
        : name;
    byName.putIfAbsent(label, () => []).add(track);
  }
  final albums = [
    for (final entry in byName.entries)
      _Album(name: entry.key, tracks: entry.value),
  ];
  albums.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return albums;
}

Track _mostPlayed(List<Track> tracks, HistoryState history) {
  var best = tracks.first;
  var count = history.playCount(best.path);
  for (final track in tracks.skip(1)) {
    final next = history.playCount(track.path);
    if (next > count) {
      best = track;
      count = next;
    }
  }
  return best;
}

const _title = TextStyle(
  color: Colors.white,
  fontSize: 28,
  height: 36 / 28,
  fontWeight: FontWeight.w600,
);

const _section = TextStyle(
  color: Colors.white,
  fontSize: 16,
  fontWeight: FontWeight.w600,
);
