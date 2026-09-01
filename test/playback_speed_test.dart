import 'package:aqloss/util/playback_speed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('snaps to the nearest preset', () {
    expect(clampPlaybackSpeed(1.0), 1.0);
    expect(clampPlaybackSpeed(1.1), 1.0);
    expect(clampPlaybackSpeed(1.2), 1.25);
    expect(clampPlaybackSpeed(0.4), 0.5);
    expect(clampPlaybackSpeed(3), 2.0);
  });

  test('labels follow the snapped preset', () {
    expect(playbackSpeedLabel(1.0), '1×');
    expect(playbackSpeedLabel(1.25), '1.25×');
    expect(playbackSpeedIndex(0.75), 1);
  });
}
