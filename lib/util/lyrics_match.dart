class LyricsSearchHit {
  final String artist;
  final String title;
  final int? duration;

  const LyricsSearchHit({
    required this.artist,
    required this.title,
    this.duration,
  });
}

String lyricsCompact(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .replaceAll(RegExp(r'\s+'), '')
      .trim();
}

bool lyricsTitleMatch(String got, String want) {
  final left = lyricsCompact(got);
  final right = lyricsCompact(want);
  return left.isNotEmpty && left == right;
}

bool lyricsArtistMatch(String got, String want) {
  final left = lyricsCompact(got);
  final right = lyricsCompact(want);
  if (left.isEmpty || right.isEmpty) return false;
  if (left == right) return true;
  final short = left.length < right.length ? left : right;
  final long = left.length < right.length ? right : left;
  return short.length >= 5 && long.contains(short);
}

int? pickLyricsHit(
  List<LyricsSearchHit> hits, {
  required String artist,
  required String title,
  int? duration,
}) {
  final matches = <int>[];
  for (var i = 0; i < hits.length; i++) {
    final hit = hits[i];
    if (!lyricsTitleMatch(hit.title, title)) continue;
    if (artist.isNotEmpty && !lyricsArtistMatch(hit.artist, artist)) continue;
    matches.add(i);
  }
  if (matches.isEmpty) return null;
  matches.sort((a, b) {
    int gap(int index) {
      final seconds = hits[index].duration;
      if (duration == null || seconds == null) return 1 << 20;
      return (seconds - duration).abs();
    }

    return gap(a).compareTo(gap(b));
  });
  return matches.first;
}
