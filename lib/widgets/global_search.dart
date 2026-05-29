import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aqloss/util/search_focus_tracker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Search result types
sealed class SearchResult {}

class TrackResult extends SearchResult {
  final Track track;
  TrackResult(this.track);
}

class AlbumResult extends SearchResult {
  final String album;
  final String artist;
  final String? coverPath;
  final List<Track> tracks;
  AlbumResult({
    required this.album,
    required this.artist,
    this.coverPath,
    required this.tracks,
  });
}

class ArtistResult extends SearchResult {
  final String artist;
  final int trackCount;
  final List<Track> tracks;
  ArtistResult({
    required this.artist,
    required this.trackCount,
    required this.tracks,
  });
}

class PlaylistResult extends SearchResult {
  final String id;
  final String name;
  final int trackCount;
  PlaylistResult({
    required this.id,
    required this.name,
    required this.trackCount,
  });
}

// Overlay wrapper
final globalSearchKey = GlobalKey<GlobalSearchOverlayState>();

class GlobalSearchOverlay extends StatefulWidget {
  final Widget child;
  const GlobalSearchOverlay({super.key, required this.child});

  @override
  State<GlobalSearchOverlay> createState() => GlobalSearchOverlayState();
}

class GlobalSearchOverlayState extends State<GlobalSearchOverlay> {
  bool _open = false;

  void show() => setState(() => _open = true);
  void hide() => setState(() => _open = false);
  bool get isOpen => _open;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_open) _SearchModal(onClose: hide),
      ],
    );
  }
}

// Modal
class _SearchModal extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  const _SearchModal({required this.onClose});

  @override
  ConsumerState<_SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends ConsumerState<_SearchModal> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    SearchFocusTracker.instance.register(_focus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    SearchFocusTracker.instance.unregister(_focus);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<SearchResult> _buildResults() {
    if (_query.trim().isEmpty) return [];

    final q = _query.toLowerCase().trim();
    final library = ref.read(libraryProvider);
    final playlists = ref.read(playlistProvider);
    final tracks = library.tracks;
    final results = <SearchResult>[];

    // Tracks
    final matchTracks = tracks
        .where(
          (t) =>
              t.displayTitle.toLowerCase().contains(q) ||
              t.displayArtist.toLowerCase().contains(q),
        )
        .take(6)
        .toList();
    for (final t in matchTracks) {
      results.add(TrackResult(t));
    }

    // Albums
    final albumMap = <String, List<Track>>{};
    for (final t in tracks) {
      if (t.album == null) continue;
      albumMap.putIfAbsent(t.album!, () => []).add(t);
    }
    final matchAlbums = albumMap.entries
        .where(
          (e) =>
              e.key.toLowerCase().contains(q) ||
              (e.value.first.albumArtist ?? e.value.first.displayArtist)
                  .toLowerCase()
                  .contains(q),
        )
        .take(4);
    for (final e in matchAlbums) {
      results.add(
        AlbumResult(
          album: e.key,
          artist: e.value.first.albumArtist ?? e.value.first.displayArtist,
          coverPath: e.value.first.path,
          tracks: e.value,
        ),
      );
    }

    // Artists
    final artistMap = <String, List<Track>>{};
    for (final t in tracks) {
      artistMap.putIfAbsent(t.displayArtist, () => []).add(t);
    }
    final matchArtists = artistMap.entries
        .where((e) => e.key.toLowerCase().contains(q))
        .take(3);
    for (final e in matchArtists) {
      results.add(
        ArtistResult(
          artist: e.key,
          trackCount: e.value.length,
          tracks: e.value,
        ),
      );
    }

    // Playlists
    final matchPlaylists = playlists
        .where((p) => p.name.toLowerCase().contains(q))
        .take(3);
    for (final p in matchPlaylists) {
      results.add(
        PlaylistResult(id: p.id, name: p.name, trackCount: p.tracks.length),
      );
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final results = _buildResults();

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: false,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onClose();
        }
      },
      child: GestureDetector(
        onTap: widget.onClose,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 560,
                constraints: const BoxConstraints(maxHeight: 520),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: cs.onSurface.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 40,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Input
                      _SearchInput(
                        ctrl: _ctrl,
                        focusNode: _focus,
                        onChanged: (v) => setState(() => _query = v),
                        onClose: widget.onClose,
                      ),

                      // Results
                      if (results.isNotEmpty)
                        Flexible(
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 8),
                            shrinkWrap: true,
                            itemCount: results.length,
                            itemBuilder: (context, i) {
                              final r = results[i];
                              final prevType = i > 0
                                  ? results[i - 1].runtimeType
                                  : null;
                              final header = r.runtimeType != prevType
                                  ? _SectionHeader(_typeLabel(r))
                                  : null;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ?header,
                                  _ResultTile(
                                    result: r,
                                    onClose: widget.onClose,
                                  ),
                                ],
                              );
                            },
                          ),
                        )
                      else if (_query.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 14,
                                color: cs.onSurface.withValues(alpha: 0.22),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'No results for "$_query"',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: cs.onSurface.withValues(alpha: 0.32),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _typeLabel(SearchResult r) => switch (r) {
    TrackResult() => 'TRACKS',
    AlbumResult() => 'ALBUMS',
    ArtistResult() => 'ARTISTS',
    PlaylistResult() => 'PLAYLISTS',
  };
}

// Search input bar
class _SearchInput extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _SearchInput({
    required this.ctrl,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.onSurface.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 18,
            color: cs.onSurface.withValues(alpha: 0.36),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: EditableText(
              controller: ctrl,
              focusNode: focusNode,
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 15,
                color: cs.onSurface,
                fontWeight: FontWeight.w300,
              ),
              cursorColor: cs.onSurface.withValues(alpha: 0.70),
              backgroundCursorColor: Colors.transparent,
              cursorWidth: 1.4,
              cursorRadius: const Radius.circular(1),
              selectionColor: cs.onSurface.withValues(alpha: 0.14),
            ),
          ),
          const SizedBox(width: 8),
          _kbdHint('Esc', cs),
        ],
      ),
    );
  }
}

Widget _kbdHint(String label, ColorScheme cs) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  decoration: BoxDecoration(
    color: cs.onSurface.withValues(alpha: 0.05),
    borderRadius: BorderRadius.circular(4),
    border: Border.all(color: cs.onSurface.withValues(alpha: 0.09)),
  ),
  child: Text(
    label,
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: cs.onSurface.withValues(alpha: 0.36),
    ),
  ),
);

// Section label
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: cs.onSurface.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}

// Result tiles
class _ResultTile extends ConsumerWidget {
  final SearchResult result;
  final VoidCallback onClose;
  const _ResultTile({required this.result, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (result) {
      TrackResult(track: final t) => _TrackTile(track: t, onClose: onClose),
      AlbumResult() => _AlbumTile(
        result: result as AlbumResult,
        onClose: onClose,
      ),
      ArtistResult() => _ArtistTile(
        result: result as ArtistResult,
        onClose: onClose,
      ),
      PlaylistResult() => _PlaylistTile(
        result: result as PlaylistResult,
        onClose: onClose,
      ),
    };
  }
}

class _TrackTile extends ConsumerWidget {
  final Track track;
  final VoidCallback onClose;
  const _TrackTile({required this.track, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return _HoverRow(
      onTap: () {
        final library = ref.read(libraryProvider);
        ref.read(playerProvider.notifier).loadWithQueue(track, library.tracks);
        onClose();
      },
      child: Row(
        children: [
          _SmallArt(path: track.path),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.displayTitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: cs.onSurface.withValues(alpha: 0.82),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  track.displayArtist,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.36),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (track.album != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                track.album!,
                style: TextStyle(
                  fontSize: 10.5,
                  color: cs.onSurface.withValues(alpha: 0.22),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _AlbumTile extends ConsumerWidget {
  final AlbumResult result;
  final VoidCallback onClose;
  const _AlbumTile({required this.result, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return _HoverRow(
      onTap: () {
        ref
            .read(playerProvider.notifier)
            .loadWithQueue(result.tracks.first, result.tracks);
        onClose();
      },
      child: Row(
        children: [
          _SmallArt(path: result.coverPath),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.album,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: cs.onSurface.withValues(alpha: 0.82),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  result.artist,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.36),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${result.tracks.length} tracks',
            style: TextStyle(
              fontSize: 10.5,
              color: cs.onSurface.withValues(alpha: 0.22),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _ArtistTile extends ConsumerWidget {
  final ArtistResult result;
  final VoidCallback onClose;
  const _ArtistTile({required this.result, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return _HoverRow(
      onTap: () {
        ref
            .read(playerProvider.notifier)
            .loadWithQueue(result.tracks.first, result.tracks);
        onClose();
      },
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_rounded,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.28),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.artist,
              style: TextStyle(
                fontSize: 12.5,
                color: cs.onSurface.withValues(alpha: 0.82),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${result.trackCount} tracks',
            style: TextStyle(
              fontSize: 10.5,
              color: cs.onSurface.withValues(alpha: 0.22),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _PlaylistTile extends ConsumerWidget {
  final PlaylistResult result;
  final VoidCallback onClose;
  const _PlaylistTile({required this.result, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return _HoverRow(
      onTap: () {
        final playlists = ref.read(playlistProvider);
        final pl = playlists.where((p) => p.id == result.id).firstOrNull;
        if (pl != null && pl.tracks.isNotEmpty) {
          ref
              .read(playerProvider.notifier)
              .loadWithQueue(pl.tracks.first, pl.tracks);
        }
        onClose();
      },
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.queue_music_rounded,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.28),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.name,
              style: TextStyle(
                fontSize: 12.5,
                color: cs.onSurface.withValues(alpha: 0.82),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${result.trackCount} tracks',
            style: TextStyle(
              fontSize: 10.5,
              color: cs.onSurface.withValues(alpha: 0.22),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// Hover row wrapper
class _HoverRow extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _HoverRow({required this.child, required this.onTap});

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
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
          color: _hovered
              ? cs.onSurface.withValues(alpha: 0.04)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: widget.child,
        ),
      ),
    );
  }
}

// Small art thumbnail
class _SmallArt extends StatefulWidget {
  final String? path;
  const _SmallArt({this.path});

  @override
  State<_SmallArt> createState() => _SmallArtState();
}

class _SmallArtState extends State<_SmallArt> {
  Uint8List? _art;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_tried || widget.path == null) return;
    _tried = true;
    try {
      final bytes = await backend.readAlbumArtThumbnail(path: widget.path!);
      if (mounted && bytes != null) setState(() => _art = bytes);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(4);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: radius,
      ),
      child: _art != null
          ? ClipRRect(
              borderRadius: radius,
              child: Image.memory(_art!, fit: BoxFit.cover),
            )
          : Icon(
              Icons.music_note_rounded,
              size: 14,
              color: cs.onSurface.withValues(alpha: 0.18),
            ),
    );
  }
}
