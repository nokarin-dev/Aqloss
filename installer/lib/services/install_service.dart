import 'dart:io';

import 'package:aqloss_installer/services/registry_service.dart';
import 'package:aqloss_installer/services/shortcut_service.dart';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class InstallService {
  InstallService._();

  static Future<void> install({
    required String installPath,
    required bool createDesktopShortcut,
    required bool createStartMenuShortcut,
    required String version,
    required void Function(String message, double progress) onProgress,
  }) async {
    final dir = Directory(installPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    onProgress('Extracting files...', 0.10);
    await _extractBundle(installPath, onProgress);

    final exePath = p.join(installPath, 'aqloss.exe');
    if (!File(exePath).existsSync()) {
      throw Exception('aqloss.exe was not found in the install package.');
    }

    onProgress('Writing uninstaller...', 0.78);
    final uninstallerPath = RegistryService.uninstallScriptPath(installPath);
    await _writeUninstallerScript(installPath);

    if (createDesktopShortcut) {
      onProgress('Creating desktop shortcut...', 0.84);
      await ShortcutService.createDesktop(targetPath: exePath, name: 'Aqloss');
    }

    if (createStartMenuShortcut) {
      onProgress('Creating Start Menu shortcut...', 0.90);
      await ShortcutService.createStartMenu(
        targetPath: exePath,
        name: 'Aqloss',
      );
    }

    onProgress('Registering application...', 0.95);
    await RegistryService.writeUninstallEntry(
      installPath: installPath,
      exePath: exePath,
      uninstallerPath: uninstallerPath,
      version: version,
      estimatedSizeKb: RegistryService.directorySizeKb(installPath),
    );

    onProgress('Done.', 1.0);
  }

  static Future<void> _extractBundle(
    String installPath,
    void Function(String message, double progress) onProgress,
  ) async {
    final bytes = await rootBundle.load('assets/aqloss_bundle.zip');
    final archive = ZipDecoder().decodeBytes(bytes.buffer.asUint8List());
    final files = archive.files.where((f) => f.isFile).toList();
    if (files.isEmpty) {
      throw Exception(
        'Install package is empty. Rebuild the installer with a valid bundle.',
      );
    }

    final root = p.normalize(installPath);
    var done = 0;
    for (final file in files) {
      final relative = file.name.replaceAll('\\', '/');
      if (relative.isEmpty ||
          relative.startsWith('/') ||
          relative.contains('..')) {
        continue;
      }
      final destPath = p.normalize(p.join(root, relative));
      if (!p.isWithin(root, destPath) && destPath != root) {
        continue;
      }

      final out = File(destPath);
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(file.content as List<int>);

      done++;
      final pct = 0.10 + (done / files.length) * 0.65;
      onProgress('Extracting: ${p.basename(relative)}', pct);
    }
  }

  static Future<void> _writeUninstallerScript(String installPath) async {
    final scriptPath = p.join(installPath, 'uninstall.ps1');
    final desktop = Platform.environment['USERPROFILE'] != null
        ? p.join(Platform.environment['USERPROFILE']!, 'Desktop', 'Aqloss.lnk')
        : '';
    final startMenu = Platform.environment['APPDATA'] != null
        ? p.join(
            Platform.environment['APPDATA']!,
            'Microsoft',
            'Windows',
            'Start Menu',
            'Programs',
            'Aqloss',
          )
        : '';

    final script = '''
\$ErrorActionPreference = 'SilentlyContinue'
\$root = Split-Path -Parent \$MyInvocation.MyCommand.Path
\$desktop = '${desktop.replaceAll("'", "''")}'
\$startMenu = '${startMenu.replaceAll("'", "''")}'
\$regKey = '${RegistryService.key}'

if (\$desktop -and (Test-Path \$desktop)) { Remove-Item -Force \$desktop }
if (\$startMenu -and (Test-Path \$startMenu)) { Remove-Item -Recurse -Force \$startMenu }
reg delete "\$regKey" /f | Out-Null

\$cmd = "cmd.exe"
\$arg = '/c ping 127.0.0.1 -n 2 > nul & rmdir /s /q "' + \$root + '"'
Start-Process -FilePath \$cmd -ArgumentList \$arg -WindowStyle Hidden
'''
        .replaceAll('\n', '\r\n');

    await File(scriptPath).writeAsString(script);
  }
}
