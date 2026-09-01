import 'package:aqloss/util/ab_loop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first tap sets A', () {
    final next = abLoopTap(12, null, null);
    expect(next.a, 12);
    expect(next.b, isNull);
    expect(abLoopPhase(next.a, next.b), AbLoopPhase.aSet);
  });

  test('second tap sets B when far enough past A', () {
    final next = abLoopTap(20, 12, null);
    expect(next.a, 12);
    expect(next.b, 20);
    expect(abLoopPhase(next.a, next.b), AbLoopPhase.active);
  });

  test('second tap waits if still too close to A', () {
    final next = abLoopTap(12.4, 12, null);
    expect(next.a, 12);
    expect(next.b, isNull);
  });

  test('third tap clears the loop', () {
    final next = abLoopTap(25, 12, 20);
    expect(next.a, isNull);
    expect(next.b, isNull);
    expect(abLoopPhase(next.a, next.b), AbLoopPhase.off);
  });

  test('wraps once playback reaches B', () {
    expect(abLoopShouldWrap(positionSecs: 20, aSecs: 12, bSecs: 20), isTrue);
    expect(abLoopShouldWrap(positionSecs: 19.9, aSecs: 12, bSecs: 20), isFalse);
    expect(abLoopShouldWrap(positionSecs: 20, aSecs: 12, bSecs: null), isFalse);
  });

  test('tooltip names the phase', () {
    expect(abLoopTooltip(AbLoopPhase.off), 'A-B loop');
    expect(abLoopTooltip(AbLoopPhase.aSet), 'A-B loop · A set');
    expect(abLoopTooltip(AbLoopPhase.active), 'A-B loop · on');
    expect(abLoopButtonLabel(AbLoopPhase.aSet), 'A');
    expect(abLoopButtonLabel(AbLoopPhase.active), 'A-B');
  });
}
