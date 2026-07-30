import 'package:aqloss_installer/screens/installer_shell.dart';
import 'package:aqloss_installer/services/install_detector.dart';
import 'package:aqloss_installer/widgets/installer_button.dart';
import 'package:aqloss_installer/widgets/side_accent.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DirectoryPage extends StatefulWidget {
  const DirectoryPage({
    super.key,
    required this.detected,
    required this.onBack,
    required this.onInstall,
  });

  final DetectedInstall detected;
  final VoidCallback onBack;
  final void Function(InstallOptions options) onInstall;

  @override
  State<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage> {
  late TextEditingController _ctrl;
  bool _createDesktopShortcut = true;
  bool _createStartMenuShortcut = true;
  bool _loading = true;

  bool get _lockPath => widget.detected.mode != InstallMode.install;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _resolveDefault();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _resolveDefault() async {
    final existing = widget.detected.installPath;
    if (existing != null && existing.isNotEmpty) {
      setState(() {
        _ctrl.text = existing;
        _loading = false;
      });
      return;
    }

    final local = await getApplicationSupportDirectory();
    final base = p.dirname(local.path);
    if (!mounted) return;
    setState(() {
      _ctrl.text = p.join(base, 'Aqloss');
      _loading = false;
    });
  }

  Future<void> _browse() async {
    if (_lockPath) return;
    final picked = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select install folder',
    );
    if (picked == null || !mounted) return;
    setState(() => _ctrl.text = p.join(picked, 'Aqloss'));
  }

  bool get _pathValid => _ctrl.text.trim().isNotEmpty;

  String get _heading => switch (widget.detected.mode) {
    InstallMode.install => 'Install location',
    InstallMode.update => 'Update location',
    InstallMode.repair => 'Repair location',
  };

  String get _subheading => switch (widget.detected.mode) {
    InstallMode.install => 'Choose where Aqloss will be installed.',
    InstallMode.update =>
      'Aqloss will be updated in the existing install folder.',
    InstallMode.repair =>
      'Aqloss will be repaired in the existing install folder.',
  };

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
                Text(
                  _heading,
                  style: const TextStyle(
                    color: Color(0xFFEAEAEA),
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _subheading,
                  style: const TextStyle(
                    color: Color(0xFF7A7A8A),
                    fontSize: 13.5,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 36),
                const Text(
                  'DESTINATION FOLDER',
                  style: TextStyle(
                    color: Color(0xFF4A4A5A),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const SizedBox(height: 44)
                else
                  Row(
                    children: [
                      Expanded(
                        child: _PathField(
                          controller: _ctrl,
                          readOnly: _lockPath,
                        ),
                      ),
                      if (!_lockPath) ...[
                        const SizedBox(width: 10),
                        InstallerButton(
                          label: 'Browse',
                          primary: false,
                          onTap: _browse,
                        ),
                      ],
                    ],
                  ),
                const SizedBox(height: 20),
                _CheckOption(
                  label: 'Create desktop shortcut',
                  value: _createDesktopShortcut,
                  onChanged: (v) => setState(() => _createDesktopShortcut = v),
                ),
                const SizedBox(height: 10),
                _CheckOption(
                  label: 'Create Start Menu shortcut',
                  value: _createStartMenuShortcut,
                  onChanged: (v) =>
                      setState(() => _createStartMenuShortcut = v),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InstallerButton(
                      label: 'Back',
                      primary: false,
                      onTap: widget.onBack,
                    ),
                    const SizedBox(width: 10),
                    InstallerButton(
                      label: widget.detected.primaryAction,
                      primary: true,
                      onTap: _pathValid
                          ? () => widget.onInstall(
                                InstallOptions(
                                  path: _ctrl.text.trim(),
                                  createDesktopShortcut:
                                      _createDesktopShortcut,
                                  createStartMenuShortcut:
                                      _createStartMenuShortcut,
                                ),
                              )
                          : null,
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

class _PathField extends StatelessWidget {
  const _PathField({required this.controller, this.readOnly = false});

  final TextEditingController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A35)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Center(
        child: TextField(
          controller: controller,
          readOnly: readOnly,
          style: TextStyle(
            color: readOnly
                ? const Color(0xFF8A8A98)
                : const Color(0xFFCCCCD8),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
          ),
        ),
      ),
    );
  }
}

class _CheckOption extends StatelessWidget {
  const _CheckOption({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: value ? const Color(0xFF4F8EF7) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: value
                    ? const Color(0xFF4F8EF7)
                    : const Color(0xFF3A3A48),
                width: 1.5,
              ),
            ),
            child: value
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF9A9AAA), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
