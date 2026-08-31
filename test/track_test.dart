import 'package:aqloss/models/track.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ReplayGain survives json cache', () {
    const t = Track(
      path: '/a.flac',
      durationSecs: 1,
      sampleRate: 44100,
      channels: 2,
      format: 'FLAC',
      fileSizeBytes: 1,
      replayGainTrack: -6.2,
      replayGainAlbum: -8.1,
    );
    final round = Track.fromJson(t.toJson());
    expect(round.replayGainTrack, -6.2);
    expect(round.replayGainAlbum, -8.1);
    expect(round.hasReplayGain, isTrue);
  });
}
