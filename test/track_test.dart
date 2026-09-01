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

  test('info labels cover channels, rate, and ReplayGain', () {
    const t = Track(
      path: '/a.flac',
      durationSecs: 1,
      sampleRate: 96000,
      bitDepth: 24,
      channels: 2,
      format: 'FLAC',
      fileSizeBytes: 1,
      replayGainTrack: -6.2,
    );
    expect(t.channelsLabel, 'Stereo');
    expect(t.sampleRateLabel, '96000 Hz');
    expect(t.bitDepthLabel, '24-bit');
    expect(t.replayGainTrackLabel, '-6.20 dB');
    expect(t.replayGainAlbumLabel, '\u2014');
    expect(formatReplayGainDb(1.5), '+1.50 dB');
    expect(
      const Track(
        path: '/m.flac',
        durationSecs: 1,
        sampleRate: 0,
        channels: 1,
        format: 'FLAC',
        fileSizeBytes: 1,
      ).channelsLabel,
      'Mono',
    );
  });
}
