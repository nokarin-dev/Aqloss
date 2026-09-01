import 'package:aqloss/models/audio_format.dart';
import 'package:aqloss/models/track.dart';

enum LibraryFilter { all, lossless, hiRes }

enum BitDepthFilter { any, sixteen, twentyFourPlus }

bool trackMatchesQuality(Track track, LibraryFilter quality) {
  switch (quality) {
    case LibraryFilter.all:
      return true;
    case LibraryFilter.lossless:
      return AudioFormat.fromExtension(track.format).isLossless;
    case LibraryFilter.hiRes:
      return track.sampleRate >= 88200 ||
          (track.bitDepth != null && track.bitDepth! >= 24);
  }
}

bool trackMatchesBitDepth(Track track, BitDepthFilter bitDepth) {
  switch (bitDepth) {
    case BitDepthFilter.any:
      return true;
    case BitDepthFilter.sixteen:
      return track.bitDepth == 16;
    case BitDepthFilter.twentyFourPlus:
      return track.bitDepth != null && track.bitDepth! >= 24;
  }
}

bool trackMatchesLibraryFilters({
  required Track track,
  required LibraryFilter quality,
  String? format,
  required BitDepthFilter bitDepth,
}) {
  if (!trackMatchesQuality(track, quality)) return false;
  if (format != null && track.format.toUpperCase() != format.toUpperCase()) {
    return false;
  }
  return trackMatchesBitDepth(track, bitDepth);
}

List<String> distinctLibraryFormats(Iterable<Track> tracks) {
  final set = <String>{
    for (final t in tracks)
      if (t.format.trim().isNotEmpty) t.format.toUpperCase(),
  };
  final list = set.toList()..sort();
  return list;
}

bool libraryHasCdBitDepth(Iterable<Track> tracks) =>
    tracks.any((t) => t.bitDepth == 16);

bool libraryHasHiBitDepth(Iterable<Track> tracks) =>
    tracks.any((t) => t.bitDepth != null && t.bitDepth! >= 24);
