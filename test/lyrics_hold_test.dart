import 'package:aqloss/providers/lyrics_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final doc = LrcDocument([
    for (var i = 0; i < 8; i++)
      LrcLine(Duration(seconds: 10 + i * 5), 'line $i'),
  ]);
  final loaded = LyricsState(document: doc, trackPath: '/song.flac');

  test('a loop keeps the lyrics already on screen', () {
    const wiped = LyricsState(trackPath: '/song.flac');
    final shown = pickShownLyrics(loaded, wiped, '/song.flac');
    expect(shown.document, doc);
  });

  test('reloading the same song does not blank the panel', () {
    const loading = LyricsState(isLoading: true, trackPath: '/song.flac');
    final shown = pickShownLyrics(loaded, loading, '/song.flac');
    expect(shown.hasLyrics, isTrue);
  });

  test('a different song does not keep the previous lyrics', () {
    const loading = LyricsState(isLoading: true, trackPath: '/other.flac');
    final shown = pickShownLyrics(loaded, loading, '/other.flac');
    expect(shown.trackPath, '/other.flac');
    expect(shown.hasLyrics, isFalse);
  });

  test('the window at the restart is the opening lines', () {
    final atEnd = lyricLineWindow(
      doc.currentIndex(const Duration(seconds: 50)),
      doc.lines.length,
    );
    final atStart = lyricLineWindow(
      doc.currentIndex(Duration.zero),
      doc.lines.length,
    );
    expect(atEnd.end, greaterThan(atEnd.start));
    expect(atStart.start, 0);
    expect(atStart.end, greaterThan(0));
    expect(doc.lines[atStart.start].text, 'line 0');
  });
}
