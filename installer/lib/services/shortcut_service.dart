import 'dart:io';

import 'package:path/path.dart' as p;

class ShortcutService {
  ShortcutService._();

  static Future<void> createDesktop({
    required String targetPath,
    required String name,
  }) async {
    final desktop = await resolveDesktopPath();
    if (desktop == null) {
      throw Exception('Could not resolve the Desktop folder.');
    }
    final dir = Directory(desktop);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
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
    final programs = await resolveStartMenuProgramsPath();
    if (programs == null) {
      throw Exception('Could not resolve the Start Menu Programs folder.');
    }
    final dir = Directory(p.join(programs, 'Aqloss'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    await _createShortcut(
      lnkPath: p.join(dir.path, '$name.lnk'),
      targetPath: targetPath,
      description: 'Aqloss music player',
    );
  }

  static Future<void> removeDesktop({required String name}) async {
    final desktop = await resolveDesktopPath();
    if (desktop == null) return;
    final file = File(p.join(desktop, '$name.lnk'));
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
  }

  static Future<void> removeStartMenu() async {
    final programs = await resolveStartMenuProgramsPath();
    if (programs == null) return;
    final dir = Directory(p.join(programs, 'Aqloss'));
    if (dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  // Desktop folder (OneDrive / renamed)
  static Future<String?> resolveDesktopPath() async {
    if (!Platform.isWindows) return null;

    final fromShell = await _knownFolder('Desktop');
    if (fromShell != null) return fromShell;

    final fromReg = await _userShellFolder('Desktop');
    if (fromReg != null) return fromReg;

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null) return null;

    for (final candidate in [
      p.join(userProfile, 'OneDrive', 'Desktop'),
      p.join(userProfile, 'Desktop'),
    ]) {
      if (Directory(candidate).existsSync()) return candidate;
    }

    final oneDrive = Platform.environment['OneDrive'];
    if (oneDrive != null) {
      final odDesktop = p.join(oneDrive, 'Desktop');
      if (Directory(odDesktop).existsSync()) return odDesktop;
    }

    return p.join(userProfile, 'Desktop');
  }

  static Future<String?> resolveStartMenuProgramsPath() async {
    if (!Platform.isWindows) return null;

    final fromShell = await _knownFolder('Programs');
    if (fromShell != null) return fromShell;

    final appData = Platform.environment['APPDATA'];
    if (appData == null) return null;
    return p.join(appData, 'Microsoft', 'Windows', 'Start Menu', 'Programs');
  }

  static Future<void> _createShortcut({
    required String lnkPath,
    required String targetPath,
    required String description,
  }) async {
    final parent = Directory(p.dirname(lnkPath));
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }

    final workDir = File(targetPath).parent.path.replaceAll("'", "''");
    final target = targetPath.replaceAll("'", "''");
    final link = lnkPath.replaceAll("'", "''");
    final desc = description.replaceAll("'", "''");
    final icon = targetPath.replaceAll("'", "''");

    final script = '''
\$ErrorActionPreference = 'Stop'
\$dir = Split-Path -Parent '$link'
if (-not (Test-Path -LiteralPath \$dir)) {
  New-Item -ItemType Directory -Force -Path \$dir | Out-Null
}
\$ws = New-Object -ComObject WScript.Shell
\$s = \$ws.CreateShortcut('$link')
\$s.TargetPath = '$target'
\$s.WorkingDirectory = '$workDir'
\$s.Description = '$desc'
\$s.IconLocation = '$icon,0'
\$s.Save()
''';

    final result = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      script,
    ], runInShell: false);

    if (result.exitCode != 0) {
      final err = '${result.stderr}\n${result.stdout}'.trim();
      throw Exception('Failed to create shortcut: $err');
    }
  }

  static Future<String?> _knownFolder(String name) async {
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      "[Environment]::GetFolderPath('$name')",
    ], runInShell: false);
    if (result.exitCode != 0) return null;
    final path = result.stdout.toString().trim();
    if (path.isEmpty) return null;
    return path;
  }

  static Future<String?> _userShellFolder(String valueName) async {
    final result = await Process.run('reg', [
      'query',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders',
      '/v',
      valueName,
    ], runInShell: false);
    if (result.exitCode != 0) return null;
    final match = RegExp(
      '$valueName\\s+REG_(?:EXPAND_)?SZ\\s+(.+)\$',
      multiLine: true,
    ).firstMatch(result.stdout.toString());
    var path = match?.group(1)?.trim();
    if (path == null || path.isEmpty) return null;
    path = _expandEnv(path);
    return path;
  }

  static String _expandEnv(String input) {
    return input.replaceAllMapped(RegExp(r'%([^%]+)%'), (m) {
      return Platform.environment[m.group(1)!] ?? m.group(0)!;
    });
  }
}
