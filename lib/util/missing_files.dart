import 'dart:io';

import 'package:aqloss/models/track.dart';

List<Track> keepExistingTracks(
  List<Track> tracks,
  bool Function(String path) exists,
) {
  return [
    for (final t in tracks)
      if (exists(t.path)) t,
  ];
}

Set<String> missingTrackPaths(
  List<Track> tracks,
  bool Function(String path) exists,
) {
  return {
    for (final t in tracks)
      if (!exists(t.path)) t.path,
  };
}

({Track track, List<Track> queue, int index})? playableQueue({
  required Track preferred,
  required List<Track> queue,
  required bool Function(String path) exists,
  int? atIndex,
}) {
  final playable = keepExistingTracks(queue, exists);
  if (playable.isEmpty) return null;

  final preferredPath =
      (atIndex != null && atIndex >= 0 && atIndex < queue.length)
      ? queue[atIndex].path
      : preferred.path;

  var idx = playable.indexWhere((t) => t.path == preferredPath);
  if (idx < 0) {
    var origin = atIndex ?? queue.indexWhere((t) => t.path == preferred.path);
    if (origin < 0) origin = 0;
    Track? next;
    for (var i = origin; i < queue.length; i++) {
      if (exists(queue[i].path)) {
        next = queue[i];
        break;
      }
    }
    final chosen = next ?? playable.first;
    idx = playable.indexWhere((t) => t.path == chosen.path);
  }
  return (track: playable[idx], queue: playable, index: idx);
}

List<String> existingPathsOnDisk(List<String> paths) {
  return [
    for (final p in paths)
      if (File(p).existsSync()) p,
  ];
}
