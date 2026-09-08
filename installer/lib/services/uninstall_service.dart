import 'dart:io';

import 'package:aqloss_installer/services/install_paths.dart';
import 'package:aqloss_installer/services/registry_service.dart';
import 'package:aqloss_installer/services/shortcut_service.dart';
import 'package:aqloss_installer/widgets/check_option.dart';
import 'package:aqloss_installer/widgets/installer_button.dart';
import 'package:aqloss_installer/widgets/title_bar.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class UninstallService {
  UninstallService._();

  static Future<int> runSilent() async {
    try {
      await uninstall(removeUserData: false);
      return 0;
    } catch (_) {
      return 1;
    }
  }

  static Future<void> uninstall({bool removeUserData = false}) async {
    final installPath = await RegistryService.readInstallLocation();
    await ShortcutService.removeDesktop(name: 'Aqloss');
    await ShortcutService.removeStartMenu();
    await RegistryService.removeUninstallEntry();

    if (installPath != null && Directory(installPath).existsSync()) {
      try {
        Directory(installPath).deleteSync(recursive: true);
      } catch (_) {
        if (Platform.isWindows) {
          await Process.run('cmd', [
            '/c',
            'rmdir',
            '/s',
            '/q',
            installPath,
          ], runInShell: false);
        }
      }
    }

    if (removeUserData) {
      _deleteUserData(installPath);
    }
  }

  static void _deleteUserData(String? installPath) {
    final skip = installPath?.toLowerCase();
    for (final path in userDataDirs()) {
      if (skip != null && path.toLowerCase() == skip) continue;
      final dir = Directory(path);
      if (!dir.existsSync()) continue;
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}

class UninstallShell extends StatefulWidget {
  const UninstallShell({super.key});

  @override
  State<UninstallShell> createState() => _UninstallShellState();
}

class _UninstallShellState extends State<UninstallShell> {
  bool _busy = false;
  bool _done = false;
  bool _removeUserData = false;
  bool _removedUserData = false;
  String? _error;
  String? _installPath;

  @override
  void initState() {
    super.initState();
    RegistryService.readInstallLocation().then((path) {
      if (mounted) setState(() => _installPath = path);
    });
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await UninstallService.uninstall(removeUserData: _removeUserData);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
        _removedUserData = _removeUserData;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  String get _heading => _done ? 'Aqloss has been removed' : 'Uninstall Aqloss?';

  String get _body {
    if (_done) {
      return _removedUserData
          ? 'Settings, playlists, and library data were deleted too. You can close this window.'
          : 'Settings and playlists are still on this PC. You can close this window.';
    }
    if (_installPath == null) {
      return 'No Aqloss installation was found in the registry.';
    }
    return 'This will remove Aqloss from:\n$_installPath';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0F),
      body: Column(
        children: [
          InstallerTitleBar(
            title: 'Uninstall Aqloss',
            onClose: () async => windowManager.close(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(36, 28, 36, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _heading,
                    style: const TextStyle(
                      color: Color(0xFFEAEAEA),
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _body,
                    style: const TextStyle(
                      color: Color(0xFF7A7A8A),
                      fontSize: 13.5,
                      height: 1.55,
                    ),
                  ),
                  if (!_done && _installPath != null) ...[
                    const SizedBox(height: 20),
                    IgnorePointer(
                      ignoring: _busy,
                      child: CheckOption(
                        label:
                            'Also remove settings, playlists, and library data',
                        value: _removeUserData,
                        onChanged: (v) =>
                            setState(() => _removeUserData = v),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFE05050),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!_done)
                        InstallerButton(
                          label: 'Cancel',
                          primary: false,
                          onTap: _busy
                              ? null
                              : () async => windowManager.close(),
                        ),
                      if (!_done) const SizedBox(width: 10),
                      InstallerButton(
                        label: _done
                            ? 'Close'
                            : (_busy ? 'Removing…' : 'Uninstall'),
                        primary: true,
                        onTap: _done
                            ? () async => windowManager.close()
                            : (_busy || _installPath == null ? null : _confirm),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
