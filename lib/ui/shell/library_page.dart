import 'package:aqloss/l10n/l10n.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/ui/shell/tokens.dart';
import 'package:aqloss/ui/shell/track_menu.dart';
import 'package:aqloss/ui/shell/album_art.dart';
import 'package:aqloss/ui/shell/love_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LibraryPage extends ConsumerWidget {
  final String query;
  final LibraryLayout layout;
  final VoidCallback? onPicked;

  const LibraryPage({
    super.key,
    this.query = '',
    this.layout = LibraryLayout.details,
    this.onPicked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final current = ref.watch(
      playerProvider.select((player) => player.currentTrack?.path),
    );
    final typed = query.trim().isNotEmpty;
    final tracks = typed
        ? [
            for (final track in library.filteredTracks)
              if (track.matchesQuery(query)) track,
          ]
        : library.filteredTracks;
    final scanning = library.status == LibraryStatus.scanning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('library'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          scanning
              ? tr('library.scanning')
              : trFill('library.tracks', {
                  'count': '${typed ? tracks.length : library.totalTracks}',
                }),
          style: const TextStyle(color: textMuted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Crossfade(
            child: KeyedSubtree(
              key: ValueKey(layout),
              child: tracks.isEmpty
                  ? Center(
                      child: Text(
                        tr(typed ? 'queue.no_matches' : 'library.empty'),
                        style: const TextStyle(color: textMuted, fontSize: 15),
                      ),
                    )
                  : layout == LibraryLayout.grid
                  ? _Grid(
                      tracks: tracks,
                      current: current,
                      onTap: (track) {
                        ref
                            .read(playerProvider.notifier)
                            .loadWithQueue(track, tracks);
                        onPicked?.call();
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: playerClearance),
                      itemExtent: 56,
                      itemCount: tracks.length,
                      itemBuilder: (context, index) {
                        final track = tracks[index];
                        return _Row(
                          track: track,
                          active: track.path == current,
                          onTap: () {
                            ref
                                .read(playerProvider.notifier)
                                .loadWithQueue(track, tracks);
                            onPicked?.call();
                          },
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

class _Grid extends StatelessWidget {
  final List<Track> tracks;
  final String? current;
  final ValueChanged<Track> onTap;

  const _Grid({
    required this.tracks,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: playerClearance),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.62,
      ),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return _Tile(
          track: track,
          active: track.path == current,
          onTap: () => onTap(track),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final Track track;
  final bool active;
  final VoidCallback onTap;

  const _Tile({required this.track, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TrackMenu(
      track: track,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: motionOf(context),
            curve: motionCurve,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: active ? const Color(0x14FFFFFF) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return MiniAlbumArt(
                      path: track.path,
                      size: constraints.maxWidth,
                      radius: 10,
                    );
                  },
                ),
                const SizedBox(height: 8),
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
                  style: const TextStyle(color: textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final Track track;
  final bool active;
  final VoidCallback onTap;

  const _Row({required this.track, required this.active, required this.onTap});

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
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  MiniAlbumArt(path: track.path, size: 40, radius: 8),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
