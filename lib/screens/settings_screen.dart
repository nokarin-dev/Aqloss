import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/providers/audio_device_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioDeviceProvider.notifier).scan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isNarrow ? 20 : 32,
                isNarrow ? 24 : 32,
                isNarrow ? 20 : 32,
                0,
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: isNarrow ? 20 : 24,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Aqloss preferences',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.30),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 20 : 32,
              vertical: isNarrow ? 20 : 28,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Audio Output
                _SectionHeader(
                  icon: Icons.speaker_rounded,
                  title: 'Audio Output',
                ),
                const SizedBox(height: 10),
                const _AudioDeviceSection(),

                _sectionGap(isNarrow),

                // Playback
                _SectionHeader(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'Playback',
                ),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _ToggleRow(
                      icon: Icons.skip_next_rounded,
                      title: 'Gapless playback',
                      subtitle: 'No silence between tracks',
                      value: s.gaplessPlayback,
                      onChanged: (_) => n.toggleGapless(),
                    ),
                    _Divider(),
                    _ToggleRow(
                      icon: Icons.graphic_eq_rounded,
                      title: 'ReplayGain',
                      subtitle: 'Normalize loudness across tracks',
                      value: s.replayGainEnabled,
                      onChanged: (_) => n.toggleReplayGain(),
                    ),
                    _Divider(),
                    _ToggleRow(
                      icon: Icons.equalizer_rounded,
                      title: 'Equalizer',
                      subtitle: 'Enable 10-band EQ',
                      value: s.eqEnabled,
                      onChanged: (_) => n.toggleEq(),
                    ),
                  ],
                ),

                _sectionGap(isNarrow),

                // Display
                _SectionHeader(icon: Icons.palette_outlined, title: 'Display'),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _PickerRow(
                      icon: Icons.dark_mode_outlined,
                      title: 'Theme',
                      options: const ['Dark', 'Light', 'System'],
                      selected: s.themeMode.index,
                      onChanged: (i) => n.setTheme(ThemeMode.values[i]),
                    ),
                    _Divider(),
                    _ToggleRow(
                      icon: Icons.info_outline_rounded,
                      title: 'Format details',
                      subtitle: 'Show bit depth & sample rate in track list',
                      value: s.showBitDepthInLibrary,
                      onChanged: (_) => n.toggleBitDepthDisplay(),
                    ),
                  ],
                ),

                _sectionGap(isNarrow),

                // Last.fm
                _SectionHeader(icon: Icons.podcasts_rounded, title: 'Last.fm'),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _ToggleRow(
                      icon: Icons.radio_button_checked_rounded,
                      title: 'Scrobble',
                      subtitle: 'Track your listening history on Last.fm',
                      value: s.scrobbleLastFm,
                      onChanged: (_) => n.toggleScrobble(),
                    ),
                    if (s.scrobbleLastFm) ...[
                      _Divider(),
                      _TapRow(
                        icon: Icons.person_outline_rounded,
                        title: 'Username',
                        value: s.lastFmUsername ?? 'Not set',
                        onTap: () => _showUsernameDialog(context, n, s),
                      ),
                    ],
                  ],
                ),

                _sectionGap(isNarrow),

                // Keyboard shortcuts
                _SectionHeader(
                  icon: Icons.keyboard_outlined,
                  title: 'Keyboard Shortcuts',
                ),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _ShortcutRow(label: 'Play / Pause', shortcut: 'Space'),
                    _Divider(),
                    _ShortcutRow(label: 'Previous track', shortcut: 'Ctrl ←'),
                    _Divider(),
                    _ShortcutRow(label: 'Next track', shortcut: 'Ctrl →'),
                    _Divider(),
                    _ShortcutRow(label: 'Volume up', shortcut: 'Ctrl ↑'),
                    _Divider(),
                    _ShortcutRow(label: 'Volume down', shortcut: 'Ctrl ↓'),
                    _Divider(),
                    _ShortcutRow(label: 'Toggle sidebar', shortcut: 'Ctrl B'),
                    _Divider(),
                    _ShortcutRow(label: 'Now Playing', shortcut: 'Ctrl 1'),
                    _Divider(),
                    _ShortcutRow(label: 'Library', shortcut: 'Ctrl 2'),
                    _Divider(),
                    _ShortcutRow(label: 'Settings', shortcut: 'Ctrl 3'),
                    _Divider(),
                    _ShortcutRow(label: 'New playlist', shortcut: 'Ctrl N'),
                  ],
                ),

                _sectionGap(isNarrow),

                // About
                _SectionHeader(
                  icon: Icons.info_outline_rounded,
                  title: 'About',
                ),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _InfoRow(
                      icon: Icons.music_note_rounded,
                      title: 'Aqloss',
                      value: 'Version 0.1.0',
                    ),
                    _Divider(),
                    _InfoRow(
                      icon: Icons.memory_rounded,
                      title: 'Audio engine',
                      value: 'Rust · Symphonia',
                    ),
                    _Divider(),
                    _InfoRow(
                      icon: Icons.headphones_rounded,
                      title: 'Output backends',
                      value: 'CPAL · WASAPI',
                    ),
                  ],
                ),

                const SizedBox(height: 48),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionGap(bool isNarrow) => SizedBox(height: isNarrow ? 28 : 36);

  void _showUsernameDialog(
    BuildContext context,
    SettingsNotifier notifier,
    SettingsState settings,
  ) {
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(
      text: settings.lastFmUsername ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Last.fm Username',
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w400,
            fontSize: 16,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: cs.onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter your Last.fm username',
            hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.28)),
            filled: true,
            fillColor: cs.onSurface.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
          onSubmitted: (v) {
            notifier.setLastFmUsername(v.trim());
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.38),
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              notifier.setLastFmUsername(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: Text(
              'Save',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.80),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Audio device section
class _AudioDeviceSection extends ConsumerWidget {
  const _AudioDeviceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final devAsync = ref.watch(audioDeviceProvider);

    return devAsync.when(
      loading: () => _scanningCard(cs),
      error: (e, _) => _errorCard(cs, e.toString()),
      data: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.devices.isEmpty)
            _scanningCard(cs)
          else
            _SettingsCard(
              children: [
                for (int i = 0; i < state.devices.length; i++) ...[
                  if (i > 0) _Divider(),
                  _DeviceRow(
                    device: state.devices[i],
                    isSelected: state.devices[i].id == state.selectedId,
                    currentMode: state.outputMode,
                    isSwitching: state.isSwitching,
                    onSelect: (mode) => ref
                        .read(audioDeviceProvider.notifier)
                        .selectDevice(state.devices[i].id, mode),
                  ),
                ],
              ],
            ),

          const SizedBox(height: 8),

          // Scan button
          _ScanButton(
            isScanning: state.isSwitching,
            onTap: state.isSwitching
                ? null
                : () => ref.read(audioDeviceProvider.notifier).scan(),
          ),
        ],
      ),
    );
  }

  Widget _scanningCard(ColorScheme cs) => _SettingsCard(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: cs.onSurface.withValues(alpha: 0.38),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Scanning audio devices…',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.38),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _errorCard(ColorScheme cs, String msg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(
      color: cs.error.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: cs.error.withValues(alpha: 0.15)),
    ),
    child: Row(
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 16,
          color: cs.error.withValues(alpha: 0.60),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Could not scan: $msg',
            style: TextStyle(
              fontSize: 12,
              color: cs.error.withValues(alpha: 0.70),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ScanButton extends StatefulWidget {
  final bool isScanning;
  final VoidCallback? onTap;
  const _ScanButton({required this.isScanning, this.onTap});

  @override
  State<_ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<_ScanButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _hovered && !widget.isScanning
                ? cs.onSurface.withValues(alpha: 0.06)
                : cs.onSurface.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.07)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isScanning)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: cs.onSurface.withValues(alpha: 0.38),
                  ),
                )
              else
                Icon(
                  Icons.refresh_rounded,
                  size: 13,
                  color: cs.onSurface.withValues(alpha: 0.38),
                ),
              const SizedBox(width: 7),
              Text(
                widget.isScanning ? 'Switching…' : 'Rescan devices',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Single device row
class _DeviceRow extends StatelessWidget {
  final AudioDeviceEntry device;
  final bool isSelected;
  final AudioOutputMode currentMode;
  final bool isSwitching;
  final void Function(AudioOutputMode) onSelect;

  const _DeviceRow({
    required this.device,
    required this.isSelected,
    required this.currentMode,
    required this.isSwitching,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canExclusive = device.supportsExclusive;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Active dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? (canExclusive &&
                                    currentMode == AudioOutputMode.exclusive
                                ? const Color(0xFF50FA7B)
                                : cs.onSurface)
                            .withValues(alpha: 0.90)
                      : cs.onSurface.withValues(alpha: 0.12),
                ),
              ),

              // Name & badges
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        device.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? cs.onSurface
                              : cs.onSurface.withValues(alpha: 0.54),
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (device.isDefault) ...[
                      const SizedBox(width: 7),
                      _Badge(
                        label: 'Default',
                        color: cs.onSurface.withValues(alpha: 0.06),
                        textColor: cs.onSurface.withValues(alpha: 0.36),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Select button
              if (!isSelected)
                _SelectBtn(
                  onTap: isSwitching
                      ? null
                      : () => onSelect(
                          canExclusive
                              ? AudioOutputMode.exclusive
                              : AudioOutputMode.system,
                        ),
                  cs: cs,
                )
              else if (canExclusive)
                _ModeToggle(
                  exclusive: currentMode == AudioOutputMode.exclusive,
                  onChanged: (excl) => isSwitching
                      ? null
                      : onSelect(
                          excl
                              ? AudioOutputMode.exclusive
                              : AudioOutputMode.system,
                        ),
                  cs: cs,
                ),
            ],
          ),

          // Capability row
          Padding(
            padding: const EdgeInsets.only(left: 17, top: 5),
            child: Wrap(
              spacing: 6,
              children: [
                _Badge(
                  label: canExclusive ? 'EXCLUSIVE' : 'SHARED ONLY',
                  color: canExclusive
                      ? cs.onSurface.withValues(alpha: 0.08)
                      : cs.onSurface.withValues(alpha: 0.04),
                  textColor: canExclusive
                      ? cs.onSurface.withValues(alpha: 0.64)
                      : cs.onSurface.withValues(alpha: 0.30),
                  bold: true,
                ),
                if (isSelected)
                  _Badge(
                    label:
                        canExclusive && currentMode == AudioOutputMode.exclusive
                        ? 'bit-perfect'
                        : 'system mixer',
                    color: Colors.transparent,
                    textColor: cs.onSurface.withValues(alpha: 0.28),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectBtn extends StatefulWidget {
  final VoidCallback? onTap;
  final ColorScheme cs;
  const _SelectBtn({this.onTap, required this.cs});

  @override
  State<_SelectBtn> createState() => _SelectBtnState();
}

class _SelectBtnState extends State<_SelectBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.cs.onSurface.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.cs.onSurface.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            'Select',
            style: TextStyle(
              fontSize: 11,
              color: widget.cs.onSurface.withValues(alpha: 0.44),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final bool exclusive;
  final void Function(bool)? onChanged;
  final ColorScheme cs;

  const _ModeToggle({
    required this.exclusive,
    required this.onChanged,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill('Shared', !exclusive, () => onChanged?.call(false)),
          _pill('Exclusive', exclusive, () => onChanged?.call(true)),
        ],
      ),
    );
  }

  Widget _pill(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? cs.onSurface.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active
                  ? cs.onSurface
                  : cs.onSurface.withValues(alpha: 0.34),
            ),
          ),
        ),
      );
}

// Card container
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.055)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
      indent: 16,
      endIndent: 16,
    );
  }
}

// Section header
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 13, color: cs.onSurface.withValues(alpha: 0.28)),
        const SizedBox(width: 7),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: cs.onSurface.withValues(alpha: 0.28),
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }
}

// Row widgets
class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 17, color: cs.onSurface.withValues(alpha: 0.36)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.80),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.30),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _MiniSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  const _PickerRow({
    required this.icon,
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isNarrow = MediaQuery.of(context).size.width < 480;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 17,
                      color: cs.onSurface.withValues(alpha: 0.36),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.80),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 31),
                  child: _SegmentedPicker(
                    options: options,
                    selected: selected,
                    onChanged: onChanged,
                    cs: cs,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: cs.onSurface.withValues(alpha: 0.36),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.80),
                    ),
                  ),
                ),
                _SegmentedPicker(
                  options: options,
                  selected: selected,
                  onChanged: onChanged,
                  cs: cs,
                ),
              ],
            ),
    );
  }
}

class _SegmentedPicker extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;
  final ColorScheme cs;

  const _SegmentedPicker({
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.asMap().entries.map((e) {
          final isSel = e.key == selected;
          return GestureDetector(
            onTap: () => onChanged(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: isSel
                    ? cs.onSurface.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                e.value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                  color: isSel
                      ? cs.onSurface
                      : cs.onSurface.withValues(alpha: 0.36),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _TapRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 17, color: cs.onSurface.withValues(alpha: 0.36)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.80),
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.36),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 15,
              color: cs.onSurface.withValues(alpha: 0.22),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String label;
  final String shortcut;
  const _ShortcutRow({required this.label, required this.shortcut});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.64),
              ),
            ),
          ),
          _KbdChip(shortcut, cs),
        ],
      ),
    );
  }
}

class _KbdChip extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  const _KbdChip(this.label, this.cs);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
          color: cs.onSurface.withValues(alpha: 0.50),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: 0.24)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.44),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.28),
            ),
          ),
        ],
      ),
    );
  }
}

// Mini switch
class _MiniSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _MiniSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 190),
        width: 36,
        height: 20,
        decoration: BoxDecoration(
          color: value
              ? cs.onSurface.withValues(alpha: 0.85)
              : cs.onSurface.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2.5),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeInOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: value
                    ? cs.surface
                    : cs.onSurface.withValues(alpha: 0.36),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Badge
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final bool bold;

  const _Badge({
    required this.label,
    required this.color,
    required this.textColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          letterSpacing: bold ? 0.7 : 0,
          color: textColor,
        ),
      ),
    );
  }
}
