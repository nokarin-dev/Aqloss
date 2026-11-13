class WindowControlSet {
  final bool minimize;
  final bool maximize;
  final bool close;

  const WindowControlSet({
    this.minimize = false,
    this.maximize = false,
    this.close = false,
  });
}

const _tiling = {
  'hyprland',
  'sway',
  'i3',
  'river',
  'niri',
  'bspwm',
  'dwm',
  'qtile',
  'herbstluftwm',
  'leftwm',
};

// Tiling sessions have no minimize or maximize.
bool tilingSession(Map<String, String> env) {
  if ((env['HYPRLAND_INSTANCE_SIGNATURE'] ?? '').isNotEmpty) return true;
  if ((env['SWAYSOCK'] ?? '').isNotEmpty) return true;
  if ((env['I3SOCK'] ?? '').isNotEmpty) return true;
  final blob =
      '${env['XDG_CURRENT_DESKTOP'] ?? ''} ${env['XDG_SESSION_DESKTOP'] ?? ''} ${env['DESKTOP_SESSION'] ?? ''}'
          .toLowerCase();
  for (final name in _tiling) {
    if (blob.contains(name)) return true;
  }
  return false;
}

WindowControlSet windowControlSet({
  required bool desktop,
  required String platform,
  required Map<String, String> env,
}) {
  if (!desktop) return const WindowControlSet();
  switch (platform) {
    case 'macos':
      return const WindowControlSet();
    case 'windows':
      return const WindowControlSet(
        minimize: true,
        maximize: true,
        close: true,
      );
    case 'linux':
      if (tilingSession(env)) return const WindowControlSet(close: true);
      return const WindowControlSet(
        minimize: true,
        maximize: true,
        close: true,
      );
    default:
      return const WindowControlSet();
  }
}
