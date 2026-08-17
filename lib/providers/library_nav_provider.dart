import 'package:aqloss/models/track.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

enum LibraryNavKind { album, artist }

class LibraryNavRequest {
  final LibraryNavKind kind;
  final String artist;
  final String album;

  LibraryNavRequest.album({required this.album, required this.artist})
    : kind = LibraryNavKind.album;

  LibraryNavRequest.artist({required this.artist})
    : kind = LibraryNavKind.artist,
      album = '';

  int get route => kind == LibraryNavKind.album ? 2 : 5;
}

final libraryNavProvider = StateProvider<LibraryNavRequest?>((ref) => null);

String libraryArtistOf(Track track) {
  final a = (track.albumArtist ?? track.artist)?.trim();
  if (a == null || a.isEmpty) return 'Unknown Artist';
  return a;
}

String libraryAlbumOf(Track track) {
  final a = track.album?.trim();
  if (a == null || a.isEmpty) return 'Unknown Album';
  return a;
}

void requestShowAlbum(
  BuildContext context,
  WidgetRef ref, {
  required String album,
  required String artist,
}) {
  _popOverlayRoutes(context);
  ref.read(libraryNavProvider.notifier).state = LibraryNavRequest.album(
    album: album,
    artist: artist,
  );
}

void requestShowArtist(
  BuildContext context,
  WidgetRef ref, {
  required String artist,
}) {
  _popOverlayRoutes(context);
  ref.read(libraryNavProvider.notifier).state = LibraryNavRequest.artist(
    artist: artist,
  );
}

void _popOverlayRoutes(BuildContext context) {
  final nav = Navigator.maybeOf(context);
  if (nav != null && nav.canPop()) {
    nav.popUntil((route) => route.isFirst);
  }
}
