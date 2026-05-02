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

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
        children: [
          Text(
            'Settings',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 28),

          // Audio Output
          _Label('Audio Output'),
          const SizedBox(height: 8),
          const _AudioDeviceSection(),

          const SizedBox(height: 24),

          // Playback
          _Label('Playback'),
          const SizedBox(height: 8),
          _ToggleRow(
            title: 'Gapless playback',
            subtitle: 'No silence between tracks',
            value: s.gaplessPlayback,
            onChanged: (_) => n.toggleGapless(),
          ),
          const SizedBox(height: 1),
          _ToggleRow(
            title: 'ReplayGain',
            subtitle: 'Normalize loudness across tracks',
            value: s.replayGainEnabled,
            onChanged: (_) => n.toggleReplayGain(),
          ),

          const SizedBox(height: 24),

          // Display
          _Label('Display'),
          const SizedBox(height: 8),
          _ToggleRow(
            title: 'Show format details',
            subtitle: 'Bit depth & sample rate in track list',
            value: s.showBitDepthInLibrary,
            onChanged: (_) => n.toggleBitDepthDisplay(),
          ),
          const SizedBox(height: 1),
          _PickerRow(
            title: 'Theme',
            options: const ['Dark', 'Light', 'System'],
            selected: s.themeMode.index,
            onChanged: (i) => n.setTheme(ThemeMode.values[i]),
          ),

          const SizedBox(height: 24),

          // Last.fm
          _Label('Last.fm'),
          const SizedBox(height: 8),
          _ToggleRow(
            title: 'Scrobble to Last.fm',
            subtitle: 'Track your listening history',
            value: s.scrobbleLastFm,
            onChanged: (_) => n.toggleScrobble(),
          ),
          if (s.scrobbleLastFm) ...[
            const SizedBox(height: 1),
            _TapRow(
              title: 'Username',
              value: s.lastFmUsername ?? 'Not set',
              onTap: () => _showUsernameDialog(context, n, s),
            ),
          ],

          const SizedBox(height: 24),

          // About
          _Label('About'),
          const SizedBox(height: 8),
          const _InfoRow(title: 'Aqloss', value: 'Version 0.1.0'),
          const SizedBox(height: 1),
          const _InfoRow(
            title: 'Audio engine',
            value: 'Rust · Symphonia · CPAL · WASAPI',
          ),
        ],
      ),
    );
  }

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            hintText: 'Enter your username',
            hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.30)),
            filled: true,
            fillColor: cs.onSurface.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
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
                color: cs.onSurface.withValues(alpha: 0.70),
                fontSize: 13,
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
      loading: () => _scanningRow(cs),
      error: (e, _) => _errorRow(cs, e.toString()),
      data: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device list
          if (state.devices.isEmpty)
            _scanningRow(cs)
          else
            ...state.devices.map(
              (device) => Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: _DeviceRow(
                  device: device,
                  isSelected: device.id == state.selectedId,
                  currentMode: state.outputMode,
                  isSwitching: state.isSwitching,
                  onSelect: (mode) => ref
                      .read(audioDeviceProvider.notifier)
                      .selectDevice(device.id, mode),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Scan & refresh button
          GestureDetector(
            onTap: state.isSwitching
                ? null
                : () => ref.read(audioDeviceProvider.notifier).scan(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.onSurface.withValues(alpha: 0.06)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.isSwitching)
                    SizedBox(
                      width: 11,
                      height: 11,
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
                  const SizedBox(width: 6),
                  Text(
                    state.isSwitching ? 'Switching…' : 'Scan devices',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanningRow(ColorScheme cs) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: cs.onSurface.withValues(alpha: 0.02),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: cs.onSurface.withValues(alpha: 0.04)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: cs.onSurface.withValues(alpha: 0.38),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Scanning audio devices…',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withValues(alpha: 0.38),
          ),
        ),
      ],
    ),
  );

  Widget _errorRow(ColorScheme cs, String msg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: cs.error.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: cs.error.withValues(alpha: 0.18)),
    ),
    child: Text(
      'Could not scan devices: $msg',
      style: TextStyle(fontSize: 12, color: cs.error.withValues(alpha: 0.80)),
    ),
  );
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      decoration: BoxDecoration(
        color: isSelected
            ? cs.onSurface.withValues(alpha: 0.06)
            : cs.onSurface.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? cs.onSurface.withValues(alpha: 0.12)
              : cs.onSurface.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          // Active indicator dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? cs.onSurface
                  : cs.onSurface.withValues(alpha: 0.12),
            ),
          ),

          // Device name & badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        device.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? cs.onSurface
                              : cs.onSurface.withValues(alpha: 0.60),
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (device.isDefault) ...[
                      const SizedBox(width: 6),
                      _Badge(label: 'Default', cs: cs, subtle: true),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (canExclusive)
                      _Badge(label: 'EXCLUSIVE', cs: cs, subtle: false)
                    else
                      _Badge(label: 'SHARED ONLY', cs: cs, subtle: true),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Text(
                        canExclusive && currentMode == AudioOutputMode.exclusive
                            ? 'bit-perfect'
                            : 'system mixer',
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurface.withValues(alpha: 0.30),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Mode toggle
          if (isSelected && canExclusive)
            _ModeToggle(
              exclusive: currentMode == AudioOutputMode.exclusive,
              onChanged: (excl) => isSwitching
                  ? null
                  : onSelect(
                      excl ? AudioOutputMode.exclusive : AudioOutputMode.system,
                    ),
              cs: cs,
            )
          else if (!isSelected)
            GestureDetector(
              onTap: isSwitching
                  ? null
                  : () => onSelect(
                      canExclusive
                          ? AudioOutputMode.exclusive
                          : AudioOutputMode.system,
                    ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: cs.onSurface.withValues(alpha: 0.10),
                  ),
                ),
                child: Text(
                  'Select',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.40),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Mode toggle
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pill('Shared', !exclusive, () => onChanged?.call(false)),
        const SizedBox(width: 3),
        _pill('Exclusive', exclusive, () => onChanged?.call(true)),
      ],
    );
  }

  Widget _pill(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? cs.onSurface.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: active
                  ? cs.onSurface.withValues(alpha: 0.24)
                  : cs.onSurface.withValues(alpha: 0.06),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: active
                  ? cs.onSurface
                  : cs.onSurface.withValues(alpha: 0.36),
              fontWeight: active ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
      );
}

// Small badge
class _Badge extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  final bool subtle;

  const _Badge({required this.label, required this.cs, required this.subtle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: subtle
            ? cs.onSurface.withValues(alpha: 0.05)
            : cs.onSurface.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: subtle
              ? cs.onSurface.withValues(alpha: 0.38)
              : cs.onSurface.withValues(alpha: 0.70),
        ),
      ),
    );
  }
}

// Shared UI widgets
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: cs.onSurface.withValues(alpha: 0.24),
        letterSpacing: 1.5,
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.70),
                    ),
                  ),
                  const SizedBox(height: 2),
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
            _MiniSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

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
        duration: const Duration(milliseconds: 180),
        width: 34,
        height: 18,
        decoration: BoxDecoration(
          color: value ? cs.onSurface : cs.onSurface.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: value
                    ? cs.surface
                    : cs.onSurface.withValues(alpha: 0.38),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final String title;
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  const _PickerRow({
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.70),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: options.asMap().entries.map((e) {
              final isSel = e.key == selected;
              return GestureDetector(
                onTap: () => onChanged(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isSel
                        ? cs.onSurface.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isSel
                          ? cs.onSurface.withValues(alpha: 0.24)
                          : cs.onSurface.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSel
                          ? cs.onSurface
                          : cs.onSurface.withValues(alpha: 0.38),
                      fontWeight: isSel ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;
  const _TapRow({
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.70),
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.38),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: cs.onSurface.withValues(alpha: 0.24),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String title;
  final String value;
  const _InfoRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.38),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.24),
            ),
          ),
        ],
      ),
    );
  }
}
