import 'dart:io';

import 'package:path/path.dart' as p;

final _win = p.Context(style: p.Style.windows);

String defaultInstallPath([Map<String, String>? env]) {
  final e = env ?? Platform.environment;
  final base = e['LOCALAPPDATA'] ?? e['APPDATA'] ?? '';
  if (base.isEmpty) return 'Aqloss';
  return _win.join(base, 'Aqloss');
}

List<String> userDataDirs([Map<String, String>? env]) {
  final e = env ?? Platform.environment;
  final appdata = e['APPDATA'] ?? '';
  if (appdata.isEmpty) return const [];
  return [
    _win.join(appdata, 'aqloss'),
    _win.join(appdata, 'xyz.nokarin', 'aqloss'),
  ];
}

