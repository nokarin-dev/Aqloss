import 'dart:io';

import 'package:aqloss_installer/services/install_paths.dart';
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
      try {
        await ShortcutService.createDesktop(
          targetPath: exePath,
          name: 'Aqloss',
        );
      } catch (e) {
        onProgress('Desktop shortcut skipped: $e', 0.86);
      }
    }

    if (createStartMenuShortcut) {
      onProgress('Creating Start Menu shortcut...', 0.90);
      try {
        await ShortcutService.createStartMenu(
          targetPath: exePath,
          name: 'Aqloss',
        );
      } catch (e) {
        onProgress('Start Menu shortcut skipped: $e', 0.92);
      }
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
    final dataLines = userDataDirs()
        .map((d) => "  '${d.replaceAll("'", "''")}'")
        .join('\n');

    final script = r'''
param([switch]$Silent)
$ErrorActionPreference = 'SilentlyContinue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$regKey = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Aqloss'
$userDataDirs = @(
__USER_DATA_DIRS__
)

function Show-UninstallPrompt {
  $old = $ErrorActionPreference
  $ErrorActionPreference = 'Stop'
  try {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    Add-Type -AssemblyName System.Drawing | Out-Null
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Uninstall Aqloss'
    $form.Size = New-Object System.Drawing.Size(460, 230)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "This will remove Aqloss from:`r`n$root"
    $label.Location = New-Object System.Drawing.Point(16, 16)
    $label.Size = New-Object System.Drawing.Size(410, 52)
    $form.Controls.Add($label)
    $check = New-Object System.Windows.Forms.CheckBox
    $check.Text = 'Also remove settings, playlists, and library data'
    $check.Location = New-Object System.Drawing.Point(16, 78)
    $check.Size = New-Object System.Drawing.Size(410, 28)
    $form.Controls.Add($check)
    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Uninstall'
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $ok.Location = New-Object System.Drawing.Point(236, 140)
    $ok.Size = New-Object System.Drawing.Size(90, 28)
    $form.AcceptButton = $ok
    $form.Controls.Add($ok)
    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $cancel.Location = New-Object System.Drawing.Point(336, 140)
    $cancel.Size = New-Object System.Drawing.Size(90, 28)
    $form.CancelButton = $cancel
    $form.Controls.Add($cancel)
    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) { exit 0 }
    return [bool]$check.Checked
  } catch {
    return $false
  } finally {
    $ErrorActionPreference = $old
  }
}

$removeUserData = $false
if (-not $Silent) {
  $removeUserData = Show-UninstallPrompt
}

$desktop = [Environment]::GetFolderPath('Desktop')
if (-not $desktop) {
  $desktop = Join-Path $env:USERPROFILE 'Desktop'
}
$desktopLnk = Join-Path $desktop 'Aqloss.lnk'
if (Test-Path -LiteralPath $desktopLnk) { Remove-Item -Force -LiteralPath $desktopLnk }

$programs = [Environment]::GetFolderPath('Programs')
if (-not $programs -and $env:APPDATA) {
  $programs = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
}
if ($programs) {
  $startMenu = Join-Path $programs 'Aqloss'
  if (Test-Path -LiteralPath $startMenu) { Remove-Item -Recurse -Force -LiteralPath $startMenu }
}

reg delete "$regKey" /f | Out-Null

if ($removeUserData) {
  foreach ($d in $userDataDirs) {
    if (-not $d) { continue }
    $a = $d.TrimEnd('\')
    $b = $root.TrimEnd('\')
    if ($a -and $b -and ($a -ieq $b)) { continue }
    if (Test-Path -LiteralPath $d) { Remove-Item -Recurse -Force -LiteralPath $d }
  }
}

$cmd = 'cmd.exe'
$arg = '/c ping 127.0.0.1 -n 2 > nul & rmdir /s /q "' + $root + '"'
Start-Process -FilePath $cmd -ArgumentList $arg -WindowStyle Hidden
'''
        .replaceAll('__USER_DATA_DIRS__', dataLines)
        .replaceAll('\n', '\r\n');

    await File(scriptPath).writeAsString(script);
  }
}
