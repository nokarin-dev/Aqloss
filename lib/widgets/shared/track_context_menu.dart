import 'dart:io';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/library_nav_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:aqloss/widgets/q_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

Future<void> showTrackContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required Track track,
  required WidgetRef ref,
}) async {
  if (!_isDesktop) return;

  final playlists = ref.read(playlistProvider);
  final selected = await _showMenu(
    context: context,
    globalPosition: globalPosition,
    items: [
      _item(context, 'play_next', Icons.playlist_play_rounded, 'Play next'),
      _item(context, 'queue', Icons.playlist_add_rounded, 'Add to queue'),
      const PopupMenuDivider(height: 8),
      _item(context, 'show_album', Icons.album_outlined, 'Show album'),
      _item(
        context,
        'show_artist',
        Icons.person_outline_rounded,
        'Show artist',
      ),
      if (playlists.isNotEmpty) ...[
        const PopupMenuDivider(height: 8),
        const PopupMenuItem<String>(
          enabled: false,
          height: 28,
          child: Text(
            'Add to playlist',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        ...playlists.map(
          (pl) =>
              _item(context, 'pl:${pl.id}', Icons.queue_music_rounded, pl.name),
        ),
      ],
    ],
  );

  if (selected == null || !context.mounted) return;
  await _onTrackAction(context, ref, track, selected);
}

Future<void> showAlbumContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required String album,
  required String artist,
  required List<Track> tracks,
  required WidgetRef ref,
}) async {
  if (!_isDesktop || tracks.isEmpty) return;

  final selected = await _showMenu(
    context: context,
    globalPosition: globalPosition,
    items: [
      _item(context, 'play', Icons.play_arrow_rounded, 'Play'),
      _item(context, 'play_next', Icons.playlist_play_rounded, 'Play next'),
      _item(context, 'queue', Icons.playlist_add_rounded, 'Add to queue'),
      const PopupMenuDivider(height: 8),
      _item(
        context,
        'show_artist',
        Icons.person_outline_rounded,
        'Show artist',
      ),
    ],
  );

  if (selected == null || !context.mounted) return;
  final player = ref.read(playerProvider.notifier);
  switch (selected) {
    case 'play':
      await player.loadWithQueue(tracks.first, tracks);
    case 'play_next':
      await player.playAllNext(tracks);
      if (context.mounted) QToast.show(context, 'Playing next');
    case 'queue':
      player.addAllToQueueLast(tracks);
      if (context.mounted) {
        QToast.show(
          context,
          tracks.length == 1
              ? 'Added to queue'
              : 'Added ${tracks.length} tracks to queue',
        );
      }
    case 'show_artist':
      requestShowArtist(context, ref, artist: artist);
  }
}

Future<void> showArtistContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required String artist,
  required List<Track> tracks,
  required WidgetRef ref,
}) async {
  if (!_isDesktop || tracks.isEmpty) return;

  final selected = await _showMenu(
    context: context,
    globalPosition: globalPosition,
    items: [
      _item(context, 'play', Icons.play_arrow_rounded, 'Play'),
      _item(context, 'play_next', Icons.playlist_play_rounded, 'Play next'),
      _item(context, 'queue', Icons.playlist_add_rounded, 'Add to queue'),
    ],
  );

  if (selected == null || !context.mounted) return;
  final player = ref.read(playerProvider.notifier);
  switch (selected) {
    case 'play':
      await player.loadWithQueue(tracks.first, tracks);
    case 'play_next':
      await player.playAllNext(tracks);
      if (context.mounted) QToast.show(context, 'Playing next');
    case 'queue':
      player.addAllToQueueLast(tracks);
      if (context.mounted) {
        QToast.show(
          context,
          tracks.length == 1
              ? 'Added to queue'
              : 'Added ${tracks.length} tracks to queue',
        );
      }
  }
}

Future<void> _onTrackAction(
  BuildContext context,
  WidgetRef ref,
  Track track,
  String selected,
) async {
  final player = ref.read(playerProvider.notifier);
  if (selected == 'play_next') {
    await player.playNext(track);
    if (context.mounted) QToast.show(context, 'Playing next');
    return;
  }
  if (selected == 'queue') {
    player.addToQueueLast(track);
    if (context.mounted) QToast.show(context, 'Added to queue');
    return;
  }
  if (selected == 'show_album') {
    requestShowAlbum(
      context,
      ref,
      album: libraryAlbumOf(track),
      artist: libraryArtistOf(track),
    );
    return;
  }
  if (selected == 'show_artist') {
    requestShowArtist(context, ref, artist: libraryArtistOf(track));
    return;
  }
  if (selected.startsWith('pl:')) {
    final id = selected.substring(3);
    final playlists = ref.read(playlistProvider);
    ref.read(playlistProvider.notifier).addTrack(id, track);
    if (!context.mounted) return;
    final pl = playlists.where((p) => p.id == id);
    if (pl.isNotEmpty) QToast.show(context, 'Added to "${pl.first.name}"');
  }
}

Future<String?> _showMenu({
  required BuildContext context,
  required Offset globalPosition,
  required List<PopupMenuEntry<String>> items,
}) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final size = overlay.size;
  final left = globalPosition.dx.clamp(8.0, size.width - 220);
  final top = globalPosition.dy.clamp(
    8.0,
    (size.height - 320).clamp(8.0, size.height),
  );

  return showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(left, top, left + 1, top + 1),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    elevation: 8,
    items: items,
  );
}

PopupMenuItem<String> _item(
  BuildContext context,
  String value,
  IconData icon,
  String label,
) {
  return PopupMenuItem<String>(
    value: value,
    height: 36,
    child: Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );
}
