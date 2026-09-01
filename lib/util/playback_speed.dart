const kPlaybackSpeeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

const kPlaybackSpeedLabels = <String>[
  '0.5×',
  '0.75×',
  '1×',
  '1.25×',
  '1.5×',
  '2×',
];

double clampPlaybackSpeed(double speed) {
  var best = kPlaybackSpeeds[2];
  var bestDist = (speed - best).abs();
  for (final v in kPlaybackSpeeds) {
    final d = (speed - v).abs();
    if (d < bestDist) {
      best = v;
      bestDist = d;
    }
  }
  return best;
}

int playbackSpeedIndex(double speed) {
  final v = clampPlaybackSpeed(speed);
  return kPlaybackSpeeds.indexOf(v);
}

String playbackSpeedLabel(double speed) =>
    kPlaybackSpeedLabels[playbackSpeedIndex(speed)];
