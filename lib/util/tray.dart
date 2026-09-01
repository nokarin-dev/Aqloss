String trayTooltip({String? title, String? artist}) {
  final t = title?.trim() ?? '';
  if (t.isEmpty) return 'Aqloss';
  final a = artist?.trim() ?? '';
  if (a.isEmpty) return t;
  return '$t — $a';
}

String trayPlayPauseLabel(bool playing) => playing ? 'Pause' : 'Play';
