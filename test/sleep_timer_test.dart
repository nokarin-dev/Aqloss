import 'package:aqloss/util/sleep_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatSleepLeft uses hours and minutes', () {
    expect(formatSleepLeft(Duration.zero), '0s');
    expect(formatSleepLeft(const Duration(seconds: 9)), '9s');
    expect(formatSleepLeft(const Duration(minutes: 12)), '12m');
    expect(formatSleepLeft(const Duration(hours: 1)), '1h');
    expect(formatSleepLeft(const Duration(hours: 1, minutes: 12)), '1h 12m');
  });

  test('sleepTimerTooltip names the remaining time', () {
    final until = DateTime(2026, 8, 31, 16, 0);
    final now = DateTime(2026, 8, 31, 15, 48);
    expect(
      sleepTimerTooltip(mode: SleepTimerMode.minutes15, until: until, now: now),
      'Sleep · 12m',
    );
    expect(
      sleepTimerTooltip(mode: SleepTimerMode.endOfTrack),
      'Sleep · end of track',
    );
    expect(sleepTimerTooltip(mode: SleepTimerMode.off), 'Sleep timer');
  });
}
