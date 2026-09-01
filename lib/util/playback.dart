double trackEndLeadSecs({
  required double crossfadeSecs,
  required bool exclusive,
  required bool hasSuccessor,
  bool stopAfter = false,
}) {
  if (stopAfter || !hasSuccessor || exclusive || crossfadeSecs <= 0) {
    return 0.1;
  }
  return crossfadeSecs;
}
