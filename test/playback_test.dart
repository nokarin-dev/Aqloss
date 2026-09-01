import 'package:aqloss/util/playback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no successor or exclusive uses 0.1s', () {
    expect(
      trackEndLeadSecs(
        crossfadeSecs: 8,
        exclusive: false,
        hasSuccessor: false,
      ),
      0.1,
    );
    expect(
      trackEndLeadSecs(
        crossfadeSecs: 4,
        exclusive: true,
        hasSuccessor: true,
      ),
      0.1,
    );
    expect(
      trackEndLeadSecs(
        crossfadeSecs: 0,
        exclusive: false,
        hasSuccessor: true,
      ),
      0.1,
    );
    expect(
      trackEndLeadSecs(
        crossfadeSecs: 8,
        exclusive: false,
        hasSuccessor: true,
        stopAfter: true,
      ),
      0.1,
    );
  });

  test('shared crossfade uses the fade length', () {
    expect(
      trackEndLeadSecs(
        crossfadeSecs: 2,
        exclusive: false,
        hasSuccessor: true,
      ),
      2,
    );
    expect(
      trackEndLeadSecs(
        crossfadeSecs: 8,
        exclusive: false,
        hasSuccessor: true,
      ),
      8,
    );
  });
}
