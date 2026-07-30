import 'dart:io';

import 'package:path/path.dart' as p;

class ShortcutService {
  ShortcutService._();

  static Future<void> createDesktop({
    required String targetPath,
    required String name,
  }) async {
    final desktop = _desktopPath();
    if (desktop == null) return;
    await _createShortcut(
      lnkPath: p.join(desktop, '$name.lnk'),
      targetPath: targetPath,
      description: 'Aqloss music player',
    );
  }

  static Future<void> createStartMenu({
    required String targetPath,
    required String name,
  }) async {
    final programs = _startMenuProgramsPath();
    if (programs == null) return;
    final dir = Directory(p.join(programs, 'Aqloss'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    await _createShortcut(
      lnkPath: p.join(dir.path, '$name.lnk'),
      targetPath: targetPath,
      description: 'Aqloss music player',
    );
  }

  static Future<void> removeDesktop({required String name}) async {
    final desktop = _desktopPath();
    if (desktop == null) return;
    final file = File(p.join(desktop, '$name.lnk'));
    if (file.existsSync()) file.deleteSync();
  }

  static Future<void> removeStartMenu() async {
    final programs = _startMenuProgramsPath();
    if (programs == null) return;
    final dir = Directory(p.join(programs, 'Aqloss'));
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  static Future<void> _createShortcut({
    required String lnkPath,
    required String targetPath,
    required String description,
  }) async {
    final workDir = File(targetPath).parent.path.replaceAll("'", "''");
    final target = targetPath.replaceAll("'", "''");
    final link = lnkPath.replaceAll("'", "''");
    final desc = description.replaceAll("'", "''");

    final script = '''
\$ws = New-Object -ComObject WScript.Shell
\$s = \$ws.CreateShortcut('$link')
\$s.TargetPath = '$target'
\$s.WorkingDirectory = '$workDir'
\$s.Description = '$desc'
\$s.Save()
''';

    final result = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      script,
    ], runInShell: false);

    if (result.exitCode != 0) {
      throw Exception(
        'Failed to create shortcut: ${result.stderr}'.trim(),
      );
    }
  }

  static String? _desktopPath() {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null) return null;
    return p.join(userProfile, 'Desktop');
  }

  static String? _startMenuProgramsPath() {
    final appData = Platform.environment['APPDATA'];
    if (appData == null) return null;
    return p.join(appData, 'Microsoft', 'Windows', 'Start Menu', 'Programs');
  }
}
