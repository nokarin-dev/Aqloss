import 'dart:io';

import 'package:aqloss_installer/app_version.dart';
import 'package:aqloss_installer/screens/installer_shell.dart';
import 'package:aqloss_installer/services/install_detector.dart';
import 'package:aqloss_installer/services/install_service.dart';
import 'package:aqloss_installer/widgets/side_accent.dart';
import 'package:flutter/material.dart';

class InstallingPage extends StatefulWidget {
  const InstallingPage({
    super.key,
    required this.options,
    required this.detected,
    required this.onDone,
  });

  final InstallOptions options;
  final DetectedInstall detected;
  final VoidCallback onDone;

  @override
  State<InstallingPage> createState() => _InstallingPageState();
}

class _InstallingPageState extends State<InstallingPage> {
  double _progress = 0;
  String _status = 'Preparing...';
  final List<String> _log = [];
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _runInstall();
  }

  void _emit(String msg, double progress) {
    if (!mounted) return;
    setState(() {
      _status = msg;
      _progress = progress;
      _log.add(msg);
    });
  }

  Future<void> _runInstall() async {
    try {
      if (!Platform.isWindows) {
        _emit('Creating install directory...', 0.05);
        await Future.delayed(const Duration(milliseconds: 200));
        for (var i = 1; i <= 6; i++) {
          await Future.delayed(const Duration(milliseconds: 160));
          _emit('[preview] Extracting: file_$i.dll', 0.15 + (i / 6) * 0.55);
        }
        _emit('[preview] Skipping shortcuts/registry (non-Windows)', 0.9);
        await Future.delayed(const Duration(milliseconds: 300));
        _emit('Done.', 1.0);
      } else {
        await InstallService.install(
          installPath: widget.options.path,
          createDesktopShortcut: widget.options.createDesktopShortcut,
          createStartMenuShortcut: widget.options.createStartMenuShortcut,
          version: kAppVersion,
          onProgress: _emit,
        );
      }

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) widget.onDone();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _status = '${widget.detected.primaryAction} failed: $e';
        _log.add('ERROR: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _failed
        ? '${widget.detected.primaryAction} failed'
        : widget.detected.progressTitle;
    final subtitle = _failed
        ? 'An error occurred. Please try again.'
        : widget.detected.progressSubtitle;

    return Row(
      children: [
        const SideAccent(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48, 48, 48, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _failed
                        ? const Color(0xFFE05050)
                        : const Color(0xFFEAEAEA),
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF7A7A8A),
                    fontSize: 13.5,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 36),
                _ProgressBar(value: _progress, failed: _failed),
                const SizedBox(height: 12),
                Text(
                  _status,
                  style: const TextStyle(
                    color: Color(0xFF5A5A6A),
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(child: _LogView(lines: _log)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.failed});

  final double value;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 4,
          width: constraints.maxWidth,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E28),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: constraints.maxWidth * value.clamp(0.0, 1.0),
              height: 4,
              decoration: BoxDecoration(
                color: failed
                    ? const Color(0xFFE05050)
                    : const Color(0xFF4F8EF7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LogView extends StatefulWidget {
  const _LogView({required this.lines});

  final List<String> lines;

  @override
  State<_LogView> createState() => _LogViewState();
}

class _LogViewState extends State<_LogView> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(_LogView old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E1E28)),
      ),
      child: ListView.builder(
        controller: _scroll,
        itemCount: widget.lines.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Text(
            widget.lines[i],
            style: const TextStyle(
              color: Color(0xFF4A4A5A),
              fontSize: 11,
              fontFamily: 'Consolas',
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
