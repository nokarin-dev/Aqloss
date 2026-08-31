const kResumeMinSecs = 5.0;
const kResumeEndMarginSecs = 5.0;
const kMaxSavedPositions = 200;
const kMaxSessionQueue = 400;

double? resumePositionSecs(double saved, double duration) {
  if (saved < kResumeMinSecs) return null;
  if (duration >= kResumeMinSecs && duration - saved < kResumeEndMarginSecs) {
    return null;
  }
  if (duration > 0 && saved >= duration) return null;
  return saved;
}

bool shouldSavePosition(double secs, double duration) =>
    resumePositionSecs(secs, duration) != null;

Map<String, double> upsertPosition(
  Map<String, double> current,
  String path,
  double secs, {
  int max = kMaxSavedPositions,
}) {
  final next = Map<String, double>.from(current);
  next.remove(path);
  next[path] = secs;
  while (next.length > max) {
    next.remove(next.keys.first);
  }
  return next;
}

({int start, int end, int index}) sessionQueueWindow({
  required int length,
  required int index,
  int max = kMaxSessionQueue,
}) {
  if (length <= 0) return (start: 0, end: 0, index: 0);
  final idx = index.clamp(0, length - 1);
  if (length <= max) {
    return (start: 0, end: length, index: idx);
  }
  var start = idx - max ~/ 2;
  if (start < 0) start = 0;
  if (start + max > length) start = length - max;
  return (start: start, end: start + max, index: idx - start);
}
