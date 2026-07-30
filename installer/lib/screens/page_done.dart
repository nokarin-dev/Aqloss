import 'dart:io';

import 'package:aqloss_installer/services/install_detector.dart';
import 'package:aqloss_installer/widgets/installer_button.dart';
import 'package:aqloss_installer/widgets/side_accent.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

class DonePage extends StatelessWidget {
  const DonePage({
    super.key,
    required this.installPath,
    required this.detected,
  });

  final String installPath;
  final DetectedInstall detected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SideAccent(highlight: true),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48, 48, 48, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _DoneIcon(),
                const SizedBox(height: 24),
                Text(
                  detected.doneTitle,
                  style: const TextStyle(
                    color: Color(0xFFEAEAEA),
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detected.doneSubtitle,
                  style: const TextStyle(
                    color: Color(0xFF7A7A8A),
                    fontSize: 13.5,
                    height: 1.6,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InstallerButton(
                      label: 'Close',
                      primary: false,
                      onTap: () async => await windowManager.close(),
                    ),
                    const SizedBox(width: 10),
                    if (Platform.isWindows)
                      InstallerButton(
                        label: 'Launch Aqloss',
                        primary: true,
                        onTap: () {
                          final exe = p.join(installPath, 'aqloss.exe');
                          Process.start(exe, [], runInShell: false);
                          windowManager.close();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DoneIcon extends StatelessWidget {
  const _DoneIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A1A),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF2A4A2A)),
      ),
      child: const Icon(Icons.check, color: Color(0xFF4ADB7A), size: 22),
    );
  }
}
