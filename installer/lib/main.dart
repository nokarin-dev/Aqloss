import 'dart:io';

import 'package:aqloss_installer/screens/installer_shell.dart';
import 'package:aqloss_installer/services/uninstall_service.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final uninstall = args.contains('--uninstall');
  final silent = args.contains('--silent');

  if (uninstall && silent && Platform.isWindows) {
    final code = await UninstallService.runSilent();
    exit(code);
  }

  await windowManager.ensureInitialized();

  final size = uninstall ? const Size(480, 320) : const Size(720, 480);
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      size: size,
      minimumSize: size,
      maximumSize: size,
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      title: uninstall ? 'Uninstall Aqloss' : 'Aqloss Installer',
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(InstallerApp(uninstallMode: uninstall));
}

class InstallerApp extends StatelessWidget {
  const InstallerApp({super.key, this.uninstallMode = false});

  final bool uninstallMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Segoe UI'),
      home: uninstallMode
          ? const UninstallShell()
          : const InstallerShell(),
    );
  }
}
