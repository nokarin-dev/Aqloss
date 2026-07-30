import 'dart:io';

import 'package:aqloss_installer/services/registry_service.dart';
import 'package:aqloss_installer/services/shortcut_service.dart';
import 'package:aqloss_installer/widgets/installer_button.dart';
import 'package:aqloss_installer/widgets/title_bar.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class UninstallService {
  UninstallService._();

  static Future<int> runSilent() async {
    try {
      await _uninstall();
      return 0;
    } catch (_) {
      return 1;
    }
  }

  static Future<void> _uninstall() async {
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
      await UninstallService._uninstall();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
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
                    _done ? 'Aqloss has been removed' : 'Uninstall Aqloss?',
                    style: const TextStyle(
                      color: Color(0xFFEAEAEA),
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _done
                        ? 'You can close this window.'
                        : (_installPath == null
                            ? 'No Aqloss installation was found in the registry.'
                            : 'This will remove Aqloss from:\n$_installPath'),
                    style: const TextStyle(
                      color: Color(0xFF7A7A8A),
                      fontSize: 13.5,
                      height: 1.55,
                    ),
                  ),
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
