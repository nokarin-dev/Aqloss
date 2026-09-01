import 'package:aqloss/models/track.dart';
import 'package:aqloss/util/library_filter.dart';
import 'package:flutter_test/flutter_test.dart';

Track _t({
  required String path,
  String format = 'FLAC',
  int sampleRate = 44100,
  int? bitDepth = 16,
}) => Track(
  path: path,
  durationSecs: 1,
  sampleRate: sampleRate,
  bitDepth: bitDepth,
  channels: 2,
  format: format,
  fileSizeBytes: 1,
);

void main() {
  test('quality filters lossless and hi-res', () {
    final flac = _t(path: '/a.flac');
    final mp3 = _t(path: '/b.mp3', format: 'MP3', bitDepth: null);
    final hi = _t(path: '/c.flac', sampleRate: 96000, bitDepth: 24);

    expect(trackMatchesQuality(flac, LibraryFilter.lossless), isTrue);
    expect(trackMatchesQuality(mp3, LibraryFilter.lossless), isFalse);
    expect(trackMatchesQuality(hi, LibraryFilter.hiRes), isTrue);
    expect(trackMatchesQuality(flac, LibraryFilter.hiRes), isFalse);
  });

  test('format and bit depth combine with quality', () {
    final a = _t(path: '/a.flac', bitDepth: 16);
    final b = _t(path: '/b.flac', bitDepth: 24);
    final c = _t(path: '/c.mp3', format: 'MP3', bitDepth: null);

    expect(
      trackMatchesLibraryFilters(
        track: a,
        quality: LibraryFilter.lossless,
        format: 'FLAC',
        bitDepth: BitDepthFilter.sixteen,
      ),
      isTrue,
    );
    expect(
      trackMatchesLibraryFilters(
        track: b,
        quality: LibraryFilter.lossless,
        format: 'FLAC',
        bitDepth: BitDepthFilter.sixteen,
      ),
      isFalse,
    );
    expect(
      trackMatchesLibraryFilters(
        track: c,
        quality: LibraryFilter.all,
        format: 'FLAC',
        bitDepth: BitDepthFilter.any,
      ),
      isFalse,
    );
    expect(
      trackMatchesLibraryFilters(
        track: b,
        quality: LibraryFilter.all,
        format: null,
        bitDepth: BitDepthFilter.twentyFourPlus,
      ),
      isTrue,
    );
  });

  test('distinct formats are uppercased and sorted', () {
    expect(
      distinctLibraryFormats([
        _t(path: '/a', format: 'mp3'),
        _t(path: '/b', format: 'FLAC'),
        _t(path: '/c', format: 'flac'),
      ]),
      ['FLAC', 'MP3'],
    );
  });
}
