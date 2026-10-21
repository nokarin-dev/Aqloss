import 'package:aqloss/l10n/l10n.dart';

enum SleepTimerMode {
  off,
  minutes15,
  minutes30,
  minutes45,
  minutes60,
  endOfTrack,
}

Duration? sleepTimerDuration(SleepTimerMode mode) => switch (mode) {
  SleepTimerMode.off || SleepTimerMode.endOfTrack => null,
  SleepTimerMode.minutes15 => const Duration(minutes: 15),
  SleepTimerMode.minutes30 => const Duration(minutes: 30),
  SleepTimerMode.minutes45 => const Duration(minutes: 45),
  SleepTimerMode.minutes60 => const Duration(minutes: 60),
};

String sleepTimerLabel(SleepTimerMode mode) => switch (mode) {
  SleepTimerMode.off => tr('playback.off'),
  SleepTimerMode.minutes15 => tr('sleep.15'),
  SleepTimerMode.minutes30 => tr('sleep.30'),
  SleepTimerMode.minutes45 => tr('sleep.45'),
  SleepTimerMode.minutes60 => tr('sleep.hour'),
  SleepTimerMode.endOfTrack => tr('sleep.end'),
};

String formatSleepLeft(Duration d) {
  if (d.isNegative || d == Duration.zero) return '0s';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return m > 0 ? '${h}h ${m}m' : '${h}h';
  if (m > 0) return '${m}m';
  return '${s}s';
}

String sleepTimerTooltip({
  required SleepTimerMode mode,
  DateTime? until,
  DateTime? now,
}) {
  switch (mode) {
    case SleepTimerMode.off:
      return tr('sleep.title');
    case SleepTimerMode.endOfTrack:
      return tr('sleep.end_label');
    default:
      final left = until?.difference(now ?? DateTime.now());
      if (left == null || left.isNegative) return tr('sleep.title');
      return trFill('sleep.time', {'time': formatSleepLeft(left)});
  }
}
