import 'dart:io';

import 'package:path/path.dart' as p;

class RegistryService {
  RegistryService._();

  static const key =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Aqloss';

  static Future<void> writeUninstallEntry({
    required String installPath,
    required String exePath,
    required String uninstallerPath,
    required String version,
    int? estimatedSizeKb,
  }) async {
    final uninstallCmd =
        'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$uninstallerPath"';

    final entries = <String, ({String type, String value})>{
      'DisplayName': (type: 'REG_SZ', value: 'Aqloss'),
      'DisplayVersion': (type: 'REG_SZ', value: version),
      'Publisher': (type: 'REG_SZ', value: 'nokarin-dev'),
      'InstallLocation': (type: 'REG_SZ', value: installPath),
      'UninstallString': (type: 'REG_SZ', value: uninstallCmd),
      'QuietUninstallString': (type: 'REG_SZ', value: uninstallCmd),
      'DisplayIcon': (type: 'REG_SZ', value: exePath),
      'NoModify': (type: 'REG_DWORD', value: '1'),
      'NoRepair': (type: 'REG_DWORD', value: '1'),
    };
    if (estimatedSizeKb != null && estimatedSizeKb > 0) {
      entries['EstimatedSize'] = (
        type: 'REG_DWORD',
        value: '$estimatedSizeKb',
      );
    }

    for (final e in entries.entries) {
      await _regAdd(e.key, e.value.value, type: e.value.type);
    }
  }

  static Future<String?> readInstallLocation() async {
    return _readRegSz('InstallLocation');
  }

  static Future<String?> readDisplayVersion() async {
    return _readRegSz('DisplayVersion');
  }

  static Future<String?> _readRegSz(String valueName) async {
    final result = await Process.run('reg', [
      'query',
      key,
      '/v',
      valueName,
    ], runInShell: false);
    if (result.exitCode != 0) return null;
    final out = result.stdout.toString();
    final match = RegExp(
      '$valueName\\s+REG_SZ\\s+(.+)\$',
      multiLine: true,
    ).firstMatch(out);
    final path = match?.group(1)?.trim();
    if (path == null || path.isEmpty) return null;
    return path;
  }

  static Future<void> removeUninstallEntry() async {
    await Process.run('reg', ['delete', key, '/f'], runInShell: false);
  }

  static Future<void> _regAdd(
    String name,
    String value, {
    required String type,
  }) async {
    final result = await Process.run('reg', [
      'add',
      key,
      '/v',
      name,
      '/t',
      type,
      '/d',
      value,
      '/f',
    ], runInShell: false);
    if (result.exitCode != 0) {
      throw Exception(
        'Failed to write registry value $name: ${result.stderr}'.trim(),
      );
    }
  }

  static int directorySizeKb(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) return 0;
    var bytes = 0;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          bytes += entity.lengthSync();
        } catch (_) {}
      }
    }
    return (bytes / 1024).ceil();
  }

  static String uninstallScriptPath(String installPath) =>
      p.join(installPath, 'uninstall.ps1');
}
