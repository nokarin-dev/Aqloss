import 'package:aqloss/widgets/eq_panel.dart';
import 'package:aqloss/widgets/lastfm_auth_row.dart';
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
    final narrow = MediaQuery.of(context).size.width < 600;
    final hPad = narrow ? 20.0 : 32.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, narrow ? 24 : 32, hPad, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: narrow ? 20 : 24,
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
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: hPad,
              vertical: narrow ? 20 : 28,
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
                _gap(narrow),

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
                      subtitle:
                          'Removes silence between consecutive tracks for seamless album listening.',
                      value: s.gaplessPlayback,
                      onChanged: (_) => n.toggleGapless(),
                    ),
                    _Div(),
                    _PickerRow(
                      icon: Icons.compare_arrows_rounded,
                      title: 'Crossfade',
                      subtitle:
                          'Fade the ending track out while fading the next one in. Disabled when gapless is on.',
                      options: const ['Off', '2s', '4s', '8s'],
                      selected: s.crossfade.index,
                      onChanged: (i) => n.setCrossfade(CrossfadeMode.values[i]),
                      disabled: s.gaplessPlayback,
                      disabledHint: 'Disabled while gapless is on',
                    ),
                    _Div(),
                    _PickerRow(
                      icon: Icons.graphic_eq_rounded,
                      title: 'ReplayGain',
                      subtitle:
                          'Normalises loudness using tags embedded in the file.',
                      options: const ['Off', 'Track', 'Album', 'Auto'],
                      selected: s.replayGainMode.index,
                      onChanged: (i) =>
                          n.setReplayGainMode(ReplayGainMode.values[i]),
                    ),
                    if (s.replayGainEnabled) ...[
                      _Div(),
                      _SliderRow(
                        icon: Icons.tune_rounded,
                        title: 'Pre-amp',
                        subtitle:
                            'Boost or cut applied before ReplayGain. Negative values prevent clipping.',
                        value: s.replayGainPreamp,
                        min: -12,
                        max: 12,
                        divisions: 24,
                        label: (v) =>
                            '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)} dB',
                        onChanged: n.setReplayGainPreamp,
                      ),
                    ],
                    _Div(),
                    _ToggleRow(
                      icon: Icons.fast_forward_rounded,
                      title: 'Skip silence',
                      subtitle:
                          'Skips leading/trailing silence at track boundaries. Useful for live recordings.',
                      value: s.skipSilence,
                      onChanged: (_) => n.toggleSkipSilence(),
                    ),
                    _Div(),
                    _PickerRow(
                      icon: Icons.stop_circle_outlined,
                      title: 'Stop after',
                      subtitle:
                          'Automatically stops playback after the current track or album finishes.',
                      options: const ['Off', 'Track', 'Album'],
                      selected: s.stopAfter.index,
                      onChanged: (i) => n.setStopAfter(StopAfterMode.values[i]),
                    ),
                  ],
                ),
                _gap(narrow),

                // DSP / EQ
                _SectionHeader(
                  icon: Icons.equalizer_rounded,
                  title: 'DSP / EQ',
                ),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _ToggleRow(
                      icon: Icons.bar_chart_rounded,
                      title: '10-band Equalizer',
                      subtitle:
                          'Per-frequency gain ±12 dB using peaking EQ filters. No effect in WASAPI Exclusive.',
                      value: s.eqEnabled,
                      onChanged: (_) => n.toggleEq(),
                    ),
                    if (s.eqEnabled) ...[_Div(), const EqPanel()],
                    _Div(),
                    _ToggleRow(
                      icon: Icons.compress_rounded,
                      title: 'Soft-clip limiter',
                      subtitle:
                          'Prevents digital clipping above 0 dBFS. Recommended with ReplayGain pre-amp or EQ boosts.',
                      value: s.notchFilter,
                      onChanged: (_) => n.toggleNotchFilter(),
                    ),
                  ],
                ),
                _gap(narrow),

                // Display
                _SectionHeader(icon: Icons.palette_outlined, title: 'Display'),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _PickerRow(
                      icon: Icons.dark_mode_outlined,
                      title: 'Theme',
                      subtitle: 'Colour scheme for the app.',
                      options: const ['Dark', 'Light', 'System'],
                      selected: s.themeMode.index,
                      onChanged: (i) => n.setTheme(ThemeMode.values[i]),
                    ),
                    _Div(),
                    _ToggleRow(
                      icon: Icons.image_outlined,
                      title: 'Album art background',
                      subtitle:
                          'Blurred album art behind the player. Disable on low-end devices to save GPU.',
                      value: s.showAlbumArtBackground,
                      onChanged: (_) => n.toggleAlbumArtBackground(),
                    ),
                    _Div(),
                    _ToggleRow(
                      icon: Icons.info_outline_rounded,
                      title: 'Format details in library',
                      subtitle:
                          'Shows bit depth and sample rate next to each track.',
                      value: s.showBitDepthInLibrary,
                      onChanged: (_) => n.toggleBitDepthDisplay(),
                    ),
                    _Div(),
                    _ToggleRow(
                      icon: Icons.show_chart_rounded,
                      title: 'Spectrum analyser',
                      subtitle:
                          'Real-time frequency display on the player screen.',
                      value: s.spectrumEnabled,
                      onChanged: (_) => n.toggleSpectrum(),
                    ),
                    if (s.spectrumEnabled) ...[
                      _Div(),
                      _PickerRow(
                        icon: Icons.auto_graph_rounded,
                        title: 'Spectrum style',
                        subtitle: 'Visual style of the analyser.',
                        options: const ['Bars', 'Wave', 'Dots'],
                        selected: s.spectrumStyle,
                        onChanged: n.setSpectrumStyle,
                      ),
                    ],
                  ],
                ),
                _gap(narrow),

                // Last.fm
                _SectionHeader(icon: Icons.podcasts_rounded, title: 'Last.fm'),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _ToggleRow(
                      icon: Icons.radio_button_checked_rounded,
                      title: 'Scrobble',
                      subtitle:
                          'Submit track plays to Last.fm after 50% played or 4 minutes.',
                      value: s.scrobbleLastFm,
                      onChanged: (_) => n.toggleScrobble(),
                    ),
                    if (s.scrobbleLastFm) ...[_Div(), const LastFmAuthRow()],
                  ],
                ),
                _gap(narrow),

                // Keyboard shortcuts
                _SectionHeader(
                  icon: Icons.keyboard_outlined,
                  title: 'Keyboard Shortcuts',
                ),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _ShortcutRow(label: 'Play / Pause', shortcut: 'Space'),
                    _Div(),
                    _ShortcutRow(label: 'Previous track', shortcut: 'Ctrl ←'),
                    _Div(),
                    _ShortcutRow(label: 'Next track', shortcut: 'Ctrl →'),
                    _Div(),
                    _ShortcutRow(label: 'Volume up 5%', shortcut: 'Ctrl ↑'),
                    _Div(),
                    _ShortcutRow(label: 'Volume down 5%', shortcut: 'Ctrl ↓'),
                    _Div(),
                    _ShortcutRow(label: 'Toggle sidebar', shortcut: 'Ctrl B'),
                    _Div(),
                    _ShortcutRow(label: 'Now Playing', shortcut: 'Ctrl 1'),
                    _Div(),
                    _ShortcutRow(label: 'Library', shortcut: 'Ctrl 2'),
                    _Div(),
                    _ShortcutRow(label: 'Settings', shortcut: 'Ctrl 3'),
                    _Div(),
                    _ShortcutRow(label: 'New playlist', shortcut: 'Ctrl N'),
                  ],
                ),
                _gap(narrow),

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
                    _Div(),
                    _InfoRow(
                      icon: Icons.memory_rounded,
                      title: 'Audio engine',
                      value: 'Rust · Symphonia',
                    ),
                    _Div(),
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

  Widget _gap(bool narrow) => SizedBox(height: narrow ? 28 : 36);
}

// Audio device section
class _AudioDeviceSection extends ConsumerWidget {
  const _AudioDeviceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final devAsync = ref.watch(audioDeviceProvider);

    return devAsync.when(
      loading: () => _scanCard(cs),
      error: (e, _) => _errorCard(cs, e.toString()),
      data: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.devices.isEmpty)
            _scanCard(cs)
          else
            _SettingsCard(
              children: [
                for (int i = 0; i < state.devices.length; i++) ...[
                  if (i > 0) _Div(),
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

  Widget _scanCard(ColorScheme cs) => _SettingsCard(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: cs.onSurface.withValues(alpha: 0.36),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Scanning audio devices…',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.36),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _errorCard(ColorScheme cs, String msg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: cs.error.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: cs.error.withValues(alpha: 0.14)),
    ),
    child: Row(
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 15,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered && !widget.isScanning
                ? cs.onSurface.withValues(alpha: 0.05)
                : cs.onSurface.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.07)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isScanning)
                SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: cs.onSurface.withValues(alpha: 0.36),
                  ),
                )
              else
                Icon(
                  Icons.refresh_rounded,
                  size: 12,
                  color: cs.onSurface.withValues(alpha: 0.36),
                ),
              const SizedBox(width: 7),
              Text(
                widget.isScanning ? 'Switching…' : 'Rescan devices',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? (device.supportsExclusive &&
                                    currentMode == AudioOutputMode.exclusive
                                ? const Color(0xFF50FA7B)
                                : cs.onSurface)
                            .withValues(alpha: 0.90)
                      : cs.onSurface.withValues(alpha: 0.10),
                ),
              ),
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
                              : cs.onSurface.withValues(alpha: 0.52),
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (device.isDefault) ...[
                      const SizedBox(width: 6),
                      _Badge(
                        label: 'Default',
                        color: cs.onSurface.withValues(alpha: 0.06),
                        textColor: cs.onSurface.withValues(alpha: 0.34),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isSelected)
                _SelectBtn(
                  onTap: isSwitching
                      ? null
                      : () => onSelect(
                          device.supportsExclusive
                              ? AudioOutputMode.exclusive
                              : AudioOutputMode.system,
                        ),
                  cs: cs,
                )
              else if (device.supportsExclusive)
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
          Padding(
            padding: const EdgeInsets.only(left: 15, top: 4),
            child: Wrap(
              spacing: 5,
              children: [
                _Badge(
                  label: device.supportsExclusive ? 'EXCLUSIVE' : 'SHARED ONLY',
                  color: device.supportsExclusive
                      ? cs.onSurface.withValues(alpha: 0.07)
                      : cs.onSurface.withValues(alpha: 0.03),
                  textColor: device.supportsExclusive
                      ? cs.onSurface.withValues(alpha: 0.60)
                      : cs.onSurface.withValues(alpha: 0.28),
                  bold: true,
                ),
                if (isSelected)
                  _Badge(
                    label:
                        device.supportsExclusive &&
                            currentMode == AudioOutputMode.exclusive
                        ? 'bit-perfect'
                        : 'system mixer',
                    color: Colors.transparent,
                    textColor: cs.onSurface.withValues(alpha: 0.26),
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
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _hovered
              ? widget.cs.onSurface.withValues(alpha: 0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: widget.cs.onSurface.withValues(alpha: 0.10),
          ),
        ),
        child: Text(
          'Select',
          style: TextStyle(
            fontSize: 11,
            color: widget.cs.onSurface.withValues(alpha: 0.42),
          ),
        ),
      ),
    ),
  );
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
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: cs.onSurface.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: cs.onSurface.withValues(alpha: 0.07)),
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

  Widget _pill(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? cs.onSurface.withValues(alpha: 0.13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active
                  ? cs.onSurface
                  : cs.onSurface.withValues(alpha: 0.32),
            ),
          ),
        ),
      );
}

// Shared UI primitives
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
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
    indent: 14,
    endIndent: 14,
  );
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 12, color: cs.onSurface.withValues(alpha: 0.26)),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: cs.onSurface.withValues(alpha: 0.26),
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }
}

// Row types
class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                icon,
                size: 16,
                color: cs.onSurface.withValues(alpha: 0.34),
              ),
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.28),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: _MiniSwitch(value: value, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;
  final bool disabled;
  final String? disabledHint;

  const _PickerRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.disabled = false,
    this.disabledHint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final narrow = MediaQuery.of(context).size.width < 500;

    Widget picker = _SegmentedPicker(
      options: options,
      selected: selected,
      onChanged: disabled ? (_) {} : onChanged,
      cs: cs,
      disabled: disabled,
    );

    return Opacity(
      opacity: disabled ? 0.40 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    icon,
                    size: 16,
                    color: cs.onSurface.withValues(alpha: 0.34),
                  ),
                ),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.28),
                          height: 1.4,
                        ),
                      ),
                      if (disabled && disabledHint != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          disabledHint!,
                          style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurface.withValues(alpha: 0.20),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!narrow) ...[const SizedBox(width: 12), picker],
              ],
            ),
            if (narrow) ...[
              const SizedBox(height: 9),
              Padding(padding: const EdgeInsets.only(left: 28), child: picker),
            ],
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final double value, min, max;
  final int divisions;
  final String Function(double) label;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  icon,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: 0.34),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.80),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          label(value),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface.withValues(alpha: 0.58),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.28),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 2,
                activeTrackColor: cs.onSurface.withValues(alpha: 0.58),
                inactiveTrackColor: cs.onSurface.withValues(alpha: 0.10),
                thumbColor: cs.onSurface.withValues(alpha: 0.80),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String label, shortcut;
  const _ShortcutRow({required this.label, required this.shortcut});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.60),
              ),
            ),
          ),
          _KbdChip(shortcut, cs),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title, value;
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 15, color: cs.onSurface.withValues(alpha: 0.22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.42),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.26),
            ),
          ),
        ],
      ),
    );
  }
}

// Small components
class _SegmentedPicker extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;
  final ColorScheme cs;
  final bool disabled;
  const _SegmentedPicker({
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.cs,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: cs.onSurface.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: cs.onSurface.withValues(alpha: 0.07)),
    ),
    padding: const EdgeInsets.all(2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: options.asMap().entries.map((e) {
        final isSel = e.key == selected;
        return GestureDetector(
          onTap: disabled ? null : () => onChanged(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSel
                  ? cs.onSurface.withValues(alpha: 0.13)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              e.value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                color: isSel
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.34),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
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
        height: 19,
        decoration: BoxDecoration(
          color: value
              ? cs.onSurface.withValues(alpha: 0.85)
              : cs.onSurface.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2.5),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: value
                    ? cs.surface
                    : cs.onSurface.withValues(alpha: 0.34),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
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

class _KbdChip extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  const _KbdChip(this.label, this.cs);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: cs.onSurface.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: cs.onSurface.withValues(alpha: 0.09)),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        fontFamily: 'monospace',
        color: cs.onSurface.withValues(alpha: 0.48),
        letterSpacing: 0.2,
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color, textColor;
  final bool bold;
  const _Badge({
    required this.label,
    required this.color,
    required this.textColor,
    this.bold = false,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 9,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        letterSpacing: bold ? 0.6 : 0,
        color: textColor,
      ),
    ),
  );
}
