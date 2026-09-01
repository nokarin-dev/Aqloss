const kAbLoopMinGapSecs = 1.0;

enum AbLoopPhase { off, aSet, active }

AbLoopPhase abLoopPhase(double? aSecs, double? bSecs) {
  if (aSecs == null) return AbLoopPhase.off;
  if (bSecs == null) return AbLoopPhase.aSet;
  return AbLoopPhase.active;
}

({double? a, double? b}) abLoopTap(double positionSecs, double? a, double? b) {
  if (a == null) return (a: positionSecs, b: null);
  if (b == null) {
    if (positionSecs - a < kAbLoopMinGapSecs) return (a: a, b: null);
    return (a: a, b: positionSecs);
  }
  return (a: null, b: null);
}

bool abLoopShouldWrap({
  required double positionSecs,
  required double? aSecs,
  required double? bSecs,
}) {
  if (aSecs == null || bSecs == null) return false;
  if (bSecs - aSecs < kAbLoopMinGapSecs) return false;
  return positionSecs >= bSecs;
}

String abLoopTooltip(AbLoopPhase phase) => switch (phase) {
  AbLoopPhase.off => 'A-B loop',
  AbLoopPhase.aSet => 'A-B loop · A set',
  AbLoopPhase.active => 'A-B loop · on',
};

String abLoopButtonLabel(AbLoopPhase phase) =>
    phase == AbLoopPhase.aSet ? 'A' : 'A-B';
