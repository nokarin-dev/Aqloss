import 'package:aqloss/models/track.dart';
import 'package:aqloss/util/library_sort.dart';
import 'package:flutter_test/flutter_test.dart';

Track _t({
  required String path,
  String? title,
  String? artist,
  String? album,
  String? albumArtist,
  int? trackNumber,
  double durationSecs = 1,
  String format = 'FLAC',
}) => Track(
  path: path,
  title: title,
  artist: artist,
  album: album,
  albumArtist: albumArtist,
  trackNumber: trackNumber,
  durationSecs: durationSecs,
  sampleRate: 44100,
  channels: 2,
  format: format,
  fileSizeBytes: 1,
);

List<Track> _sorted(
  List<Track> tracks,
  SortField field, [
  SortOrder order = SortOrder.ascending,
]) {
  final next = [...tracks];
  next.sort((a, b) => compareLibraryTracks(a, b, field, order));
  return next;
}

void main() {
  test('album sort keeps same-named albums with their artist', () {
    final a1 = _t(
      path: '/a1',
      album: 'Greatest Hits',
      artist: 'A',
      trackNumber: 2,
    );
    final a2 = _t(
      path: '/a2',
      album: 'Greatest Hits',
      artist: 'A',
      trackNumber: 1,
    );
    final b1 = _t(
      path: '/b1',
      album: 'Greatest Hits',
      artist: 'B',
      trackNumber: 1,
    );
    final ordered = _sorted([b1, a1, a2], SortField.album);
    expect(ordered.map((t) => t.path), ['/a2', '/a1', '/b1']);
  });

  test('artist sort is artist, then album, then track number', () {
    final late = _t(
      path: '/late',
      artist: 'Fleet Foxes',
      album: 'Helplessness Blues',
      trackNumber: 2,
    );
    final first = _t(
      path: '/first',
      artist: 'Fleet Foxes',
      album: 'Helplessness Blues',
      trackNumber: 1,
    );
    final other = _t(
      path: '/other',
      artist: 'Fleet Foxes',
      album: 'Shore',
      trackNumber: 1,
    );
    final ordered = _sorted([late, other, first], SortField.artist);
    expect(ordered.map((t) => t.path), ['/first', '/late', '/other']);
  });

  test('descending flips only the first column', () {
    final a = _t(path: '/a', artist: 'A', album: 'Zed', trackNumber: 1);
    final b = _t(path: '/b', artist: 'B', album: 'Ace', trackNumber: 2);
    final a2 = _t(path: '/a2', artist: 'A', album: 'Zed', trackNumber: 2);
    final ordered = _sorted([a, b, a2], SortField.artist, SortOrder.descending);
    expect(ordered.map((t) => t.path), ['/b', '/a', '/a2']);
  });

  test('title sort is case-insensitive and breaks ties by artist', () {
    final a = _t(path: '/a', title: 'Helplessness Blues', artist: 'A');
    final b = _t(path: '/b', title: 'helplessness blues', artist: 'B');
    final ordered = _sorted([b, a], SortField.title);
    expect(ordered.map((t) => t.path), ['/a', '/b']);
  });

  test('format sort then groups by artist and album', () {
    final mp3 = _t(
      path: '/mp3',
      format: 'MP3',
      artist: 'A',
      album: 'One',
      trackNumber: 1,
    );
    final flac2 = _t(
      path: '/flac2',
      format: 'FLAC',
      artist: 'A',
      album: 'One',
      trackNumber: 2,
    );
    final flac1 = _t(
      path: '/flac1',
      format: 'FLAC',
      artist: 'A',
      album: 'One',
      trackNumber: 1,
    );
    final ordered = _sorted([mp3, flac2, flac1], SortField.format);
    expect(ordered.map((t) => t.path), ['/flac1', '/flac2', '/mp3']);
  });
}
