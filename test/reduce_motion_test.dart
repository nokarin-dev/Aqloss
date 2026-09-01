import 'package:aqloss/util/reduce_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reduce motion is on if the setting or the system asks', () {
    expect(combineReduceMotion(setting: false, system: false), isFalse);
    expect(combineReduceMotion(setting: true, system: false), isTrue);
    expect(combineReduceMotion(setting: false, system: true), isTrue);
    expect(combineReduceMotion(setting: true, system: true), isTrue);
  });
}
