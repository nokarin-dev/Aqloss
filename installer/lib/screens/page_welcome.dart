import 'package:aqloss_installer/app_version.dart';
import 'package:aqloss_installer/services/install_detector.dart';
import 'package:aqloss_installer/widgets/app_brand_icon.dart';
import 'package:aqloss_installer/widgets/installer_button.dart';
import 'package:aqloss_installer/widgets/side_accent.dart';
import 'package:flutter/widgets.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({
    super.key,
    required this.detected,
    required this.onNext,
  });

  final DetectedInstall detected;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SideAccent(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48, 48, 48, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppBrandIcon(size: 56),
                const SizedBox(height: 28),
                Text(
                  detected.title,
                  style: const TextStyle(
                    color: Color(0xFFEAEAEA),
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detected.subtitle,
                  style: const TextStyle(
                    color: Color(0xFF7A7A8A),
                    fontSize: 13.5,
                    height: 1.6,
                  ),
                ),
                const Spacer(),
                _VersionTag(detected: detected),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InstallerButton(
                      label: 'Next',
                      primary: true,
                      onTap: onNext,
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

class _VersionTag extends StatelessWidget {
  const _VersionTag({required this.detected});

  final DetectedInstall detected;

  @override
  Widget build(BuildContext context) {
    final label = switch (detected.mode) {
      InstallMode.install => 'Version $kAppVersion',
      InstallMode.update =>
        'Installed ${detected.installedVersion} → $kAppVersion',
      InstallMode.repair => 'Installed $kAppVersion · Repair',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1F),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2A2A35)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF5A5A6A),
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
