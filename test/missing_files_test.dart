import 'dart:io';

import 'package:aqloss/models/track.dart';
import 'package:aqloss/util/missing_files.dart';
import 'package:flutter_test/flutter_test.dart';

Track _t(String path) => Track(
  path: path,
  durationSecs: 1,
  sampleRate: 44100,
  channels: 2,
  format: 'FLAC',
  fileSizeBytes: 1,
);

void main() {
  test('keepExistingTracks drops paths that are gone', () {
    final kept = keepExistingTracks([
      _t('/a.flac'),
      _t('/gone.flac'),
      _t('/b.flac'),
    ], (p) => p != '/gone.flac');
    expect(kept.map((t) => t.path), ['/a.flac', '/b.flac']);
  });

  test('missingTrackPaths lists only the gaps', () {
    expect(
      missingTrackPaths([
        _t('/a.flac'),
        _t('/gone.flac'),
      ], (p) => p != '/gone.flac'),
      {'/gone.flac'},
    );
  });

  test('playableQueue keeps the preferred track when it exists', () {
    final a = _t('/a.flac');
    final b = _t('/b.flac');
    final pick = playableQueue(
      preferred: b,
      queue: [a, b],
      exists: (_) => true,
    );
    expect(pick!.track.path, '/b.flac');
    expect(pick.index, 1);
    expect(pick.queue.length, 2);
  });

  test('playableQueue skips a missing preferred track', () {
    final a = _t('/a.flac');
    final gone = _t('/gone.flac');
    final b = _t('/b.flac');
    final pick = playableQueue(
      preferred: gone,
      queue: [a, gone, b],
      exists: (p) => p != '/gone.flac',
    );
    expect(pick!.track.path, '/b.flac');
    expect(pick.queue.map((t) => t.path), ['/a.flac', '/b.flac']);
    expect(pick.index, 1);
  });

  test('playableQueue wraps to the first live file', () {
    final a = _t('/a.flac');
    final gone = _t('/gone.flac');
    final pick = playableQueue(
      preferred: gone,
      queue: [a, gone],
      exists: (p) => p != '/gone.flac',
    );
    expect(pick!.track.path, '/a.flac');
    expect(pick.index, 0);
  });

  test('playableQueue is null when every file is gone', () {
    expect(
      playableQueue(
        preferred: _t('/gone.flac'),
        queue: [_t('/gone.flac')],
        exists: (_) => false,
      ),
      isNull,
    );
  });

  test('existingPathsOnDisk keeps files that exist', () {
    final dir = Directory.systemTemp.createTempSync('aqloss_missing');
    addTearDown(() => dir.deleteSync(recursive: true));
    final live = File('${dir.path}/a.flac')..writeAsStringSync('x');
    final gone = '${dir.path}/gone.flac';
    expect(existingPathsOnDisk([live.path, gone]), [live.path]);
  });
}
