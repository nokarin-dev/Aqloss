import 'package:aqloss_installer/screens/page_directory.dart';
import 'package:aqloss_installer/screens/page_done.dart';
import 'package:aqloss_installer/screens/page_installing.dart';
import 'package:aqloss_installer/screens/page_welcome.dart';
import 'package:aqloss_installer/services/install_detector.dart';
import 'package:aqloss_installer/widgets/title_bar.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

enum InstallerPage { welcome, directory, installing, done }

class InstallOptions {
  const InstallOptions({
    required this.path,
    required this.createDesktopShortcut,
    required this.createStartMenuShortcut,
  });

  final String path;
  final bool createDesktopShortcut;
  final bool createStartMenuShortcut;
}

class InstallerShell extends StatefulWidget {
  const InstallerShell({super.key});

  @override
  State<InstallerShell> createState() => _InstallerShellState();
}

class _InstallerShellState extends State<InstallerShell> {
  InstallerPage _page = InstallerPage.welcome;
  InstallOptions? _options;
  DetectedInstall? _detected;
  bool _detecting = true;

  @override
  void initState() {
    super.initState();
    _detect();
  }

  Future<void> _detect() async {
    final detected = await InstallDetector.detect();
    if (!mounted) return;
    setState(() {
      _detected = detected;
      _detecting = false;
    });
  }

  void _goTo(InstallerPage page) => setState(() => _page = page);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0F),
      body: Column(
        children: [
          InstallerTitleBar(onClose: () async => windowManager.close()),
          Expanded(
            child: _detecting || _detected == null
                ? const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF4F8EF7),
                      ),
                    ),
                  )
                : _buildPage(_detected!),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(DetectedInstall detected) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: switch (_page) {
        InstallerPage.welcome => WelcomePage(
          key: const ValueKey('welcome'),
          detected: detected,
          onNext: () => _goTo(InstallerPage.directory),
        ),
        InstallerPage.directory => DirectoryPage(
          key: const ValueKey('directory'),
          detected: detected,
          onBack: () => _goTo(InstallerPage.welcome),
          onInstall: (options) {
            setState(() => _options = options);
            _goTo(InstallerPage.installing);
          },
        ),
        InstallerPage.installing => InstallingPage(
          key: const ValueKey('installing'),
          options: _options!,
          detected: detected,
          onDone: () => _goTo(InstallerPage.done),
        ),
        InstallerPage.done => DonePage(
          key: const ValueKey('done'),
          installPath: _options!.path,
          detected: detected,
        ),
      },
    );
  }
}
