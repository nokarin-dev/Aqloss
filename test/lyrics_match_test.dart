import 'package:aqloss/util/lyrics_match.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const wrong = LyricsSearchHit(
    artist: 'Other Artist',
    title: 'Re, Bloom*',
    duration: 200,
  );
  const right = LyricsSearchHit(
    artist: 'Yuuki Sakuna',
    title: 'Re, Bloom*',
    duration: 214,
  );

  test('same title from another artist is rejected', () {
    final index = pickLyricsHit(
      [wrong, right],
      artist: 'YuukiSakuna',
      title: 'Re, Bloom*',
      duration: 216,
    );
    expect(index, 1);
  });

  test('title-only search does not take the first row', () {
    final index = pickLyricsHit(
      [wrong],
      artist: 'YuukiSakuna',
      title: 'Re, Bloom*',
    );
    expect(index, isNull);
  });

  test('closer duration wins when the artist matches', () {
    const far = LyricsSearchHit(
      artist: 'YuukiSakuna',
      title: 'Re, Bloom*',
      duration: 90,
    );
    final index = pickLyricsHit(
      [far, right],
      artist: 'YuukiSakuna',
      title: 'Re, bloom*',
      duration: 216,
    );
    expect(index, 1);
  });
}
