import 'package:aqloss/util/track_positions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('skips near the start', () {
    expect(resumePositionSecs(4.9, 180), isNull);
    expect(resumePositionSecs(5.0, 180), 5.0);
  });

  test('skips near the end', () {
    expect(resumePositionSecs(176, 180), isNull);
    expect(resumePositionSecs(170, 180), 170);
  });

  test('unknown duration still resumes past the minimum', () {
    expect(resumePositionSecs(30, 0), 30);
    expect(resumePositionSecs(4, 0), isNull);
  });

  test('skip and play start at zero; reopen can resume', () {
    expect(
      playbackStartSecs(resumeOnOpen: false, duration: 180, storedSecs: 20),
      0,
    );
    expect(
      playbackStartSecs(resumeOnOpen: true, duration: 180, reopenSecs: 20),
      20,
    );
    expect(
      playbackStartSecs(resumeOnOpen: true, duration: 180, reopenSecs: 3),
      0,
    );
    expect(
      playbackStartSecs(
        resumeOnOpen: true,
        duration: 180,
        reopenSecs: 20,
        storedSecs: 90,
      ),
      20,
    );
  });

  test('upsert drops the oldest when over cap', () {
    var map = <String, double>{};
    for (var i = 0; i < 201; i++) {
      map = upsertPosition(map, 'p$i', 10, max: 200);
    }
    expect(map.length, 200);
    expect(map.containsKey('p0'), isFalse);
    expect(map['p200'], 10);
  });

  test('session window keeps the current index in range', () {
    final all = sessionQueueWindow(length: 10, index: 3);
    expect(all, (start: 0, end: 10, index: 3));

    final mid = sessionQueueWindow(length: 1000, index: 500, max: 400);
    expect(mid.start, 300);
    expect(mid.end, 700);
    expect(mid.index, 200);

    final head = sessionQueueWindow(length: 1000, index: 10, max: 400);
    expect(head.start, 0);
    expect(head.index, 10);

    final tail = sessionQueueWindow(length: 1000, index: 990, max: 400);
    expect(tail.start, 600);
    expect(tail.end, 1000);
    expect(tail.index, 390);
  });
}
