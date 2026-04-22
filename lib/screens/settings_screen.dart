import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 28),

          // Audio Output
          _Label('Audio Output'),
          const SizedBox(height: 8),
          _OptionRow(
            title: 'Bit-perfect / Exclusive',
            subtitle: 'Bypasses OS mixer · WASAPI · CoreAudio',
            selected: s.outputMode == AudioOutputMode.exclusive,
            onTap: () => n.setOutputMode(AudioOutputMode.exclusive),
          ),
          const SizedBox(height: 1),
          _OptionRow(
            title: 'System mixer',
            subtitle: 'Shared mode · may resample audio',
            selected: s.outputMode == AudioOutputMode.system,
            onTap: () => n.setOutputMode(AudioOutputMode.system),
          ),

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
          // Theme picker inline
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
            value: 'Rust · Symphonia · CPAL',
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
    final controller = TextEditingController(
      text: settings.lastFmUsername ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Last.fm Username',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w400,
            fontSize: 16,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter your username',
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () {
              notifier.setLastFmUsername(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// Building blocks
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: Colors.white24,
        letterSpacing: 1.5,
      ),
    );
  }
}

// Selection Row
class _OptionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _OptionRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
          ),
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
                      color: selected ? Colors.white : Colors.white54,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.white30),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.white : Colors.white24,
                  width: 1.5,
                ),
                color: selected ? Colors.white : Colors.transparent,
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 9,
                      color: Colors.black,
                    )
                  : null,
            ),
          ],
        ),
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
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.white30),
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

/// Tiny custom switch
class _MiniSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _MiniSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 34,
        height: 18,
        decoration: BoxDecoration(
          color: value ? Colors.white : Colors.white12,
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
                color: value ? Colors.black : Colors.white38,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
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
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isSel
                          ? Colors.white24
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSel ? Colors.white : Colors.white38,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 12, color: Colors.white38),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: Colors.white24,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 13, color: Colors.white38),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, color: Colors.white24),
          ),
        ],
      ),
    );
  }
}
