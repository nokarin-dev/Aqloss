import 'package:aqloss/models/playlist.dart';
import 'package:aqloss/models/track.dart';
import 'package:flutter_test/flutter_test.dart';

Track _track(String path) => Track(
  path: path,
  title: path,
  durationSecs: 1,
  sampleRate: 44100,
  channels: 2,
  format: 'FLAC',
  fileSizeBytes: 1,
);

void main() {
  test('reorder moves a track to the new index', () {
    final playlist = Playlist(
      id: '1',
      name: 'Mix',
      createdAt: DateTime.utc(2026),
      tracks: [_track('a'), _track('b'), _track('c')],
    );

    expect(playlist.reorder(0, 1).tracks.map((track) => track.path), [
      'b',
      'a',
      'c',
    ]);
    expect(playlist.reorder(0, 2).tracks.map((track) => track.path), [
      'b',
      'c',
      'a',
    ]);
    expect(playlist.reorder(2, 0).tracks.map((track) => track.path), [
      'c',
      'a',
      'b',
    ]);
  });
}
