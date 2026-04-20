import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                'Settings',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Audio Output
                _SectionLabel('Audio Output'),
                _Card(
                  child: Column(
                    children: [
                      _RadioRow<AudioOutputMode>(
                        title: 'Bit-perfect / Exclusive',
                        subtitle: 'Bypasses OS mixer · WASAPI · CoreAudio',
                        value: AudioOutputMode.exclusive,
                        groupValue: settings.outputMode,
                        leadingIcon: Icons.high_quality_rounded,
                        onChanged: notifier.setOutputMode,
                      ),
                      _Divider(),
                      _RadioRow<AudioOutputMode>(
                        title: 'System mixer',
                        subtitle: 'Shared mode · may resample audio',
                        value: AudioOutputMode.system,
                        groupValue: settings.outputMode,
                        leadingIcon: Icons.speaker_rounded,
                        onChanged: notifier.setOutputMode,
                      ),
                    ],
                  ),
                ),

                // Playback
                _SectionLabel('Playback'),
                _Card(
                  child: Column(
                    children: [
                      _SwitchRow(
                        title: 'Gapless playback',
                        subtitle: 'No silence between tracks',
                        icon: Icons.queue_music_rounded,
                        value: settings.gaplessPlayback,
                        onChanged: (_) => notifier.toggleGapless(),
                      ),
                      _Divider(),
                      _SwitchRow(
                        title: 'ReplayGain',
                        subtitle: 'Normalize loudness across tracks',
                        icon: Icons.tune_rounded,
                        value: settings.replayGainEnabled,
                        onChanged: (_) => notifier.toggleReplayGain(),
                      ),
                    ],
                  ),
                ),

                // Library
                _SectionLabel('Library'),
                _Card(
                  child: _SwitchRow(
                    title: 'Show format details',
                    subtitle: 'Bit depth & sample rate in track list',
                    icon: Icons.info_outline_rounded,
                    value: settings.showBitDepthInLibrary,
                    onChanged: (_) => notifier.toggleBitDepthDisplay(),
                  ),
                ),

                // Appearance
                _SectionLabel('Appearance'),
                _Card(
                  child: _SegmentedRow(
                    title: 'Theme',
                    icon: Icons.palette_outlined,
                    options: const ['Dark', 'Light', 'System'],
                    selected: settings.themeMode.index,
                    onChanged: (i) =>
                        notifier.setTheme(ThemeMode.values[i]),
                  ),
                ),

                // Last.fm
                _SectionLabel('Last.fm'),
                _Card(
                  child: Column(
                    children: [
                      _SwitchRow(
                        title: 'Scrobble to Last.fm',
                        subtitle: 'Track your listening history',
                        icon: Icons.radio_rounded,
                        value: settings.scrobbleLastFm,
                        onChanged: (_) => notifier.toggleScrobble(),
                      ),
                      if (settings.scrobbleLastFm) ...[
                        _Divider(),
                        _TapRow(
                          title: 'Username',
                          subtitle: settings.lastFmUsername ?? 'Not set',
                          icon: Icons.person_outline_rounded,
                          onTap: () =>
                              _showUsernameDialog(context, notifier, settings),
                        ),
                      ],
                    ],
                  ),
                ),

                // About
                _SectionLabel('About'),
                _Card(
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.music_note_rounded,
                        title: 'Aqloss',
                        subtitle: 'Version 0.1.0',
                      ),
                      _Divider(),
                      _InfoRow(
                        icon: Icons.code_rounded,
                        title: 'Audio engine',
                        subtitle: 'Rust · Symphonia · CPAL · Rubato',
                      ),
                      _Divider(),
                      _InfoRow(
                        icon: Icons.favorite_border_rounded,
                        title: 'Lossless everywhere.',
                        subtitle: 'Built for audiophiles',
                      ),
                    ],
                  ),
                ),
              ]),
            ),
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
    final controller =
        TextEditingController(text: settings.lastFmUsername ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Last.fm Username',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w400)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter your username',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              notifier.setLastFmUsername(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

// Building blocks
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white24,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white.withValues(alpha: 0.05),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _IconBox(icon),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(subtitle,
          style:
              const TextStyle(color: Colors.white38, fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.black : Colors.white30),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : Colors.white12),
      ),
    );
  }
}

class _RadioRow<T> extends StatelessWidget {
  final String title;
  final String subtitle;
  final T value;
  final T groupValue;
  final IconData leadingIcon;
  final ValueChanged<T> onChanged;
  const _RadioRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.leadingIcon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _IconBox(leadingIcon),
      title: Text(title,
          style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 14,
              fontWeight:
                  selected ? FontWeight.w500 : FontWeight.w400)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Colors.white38, fontSize: 12)),
      trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: selected ? Colors.white : Colors.white24, width: 1.5),
          color: selected ? Colors.white : Colors.transparent,
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 12, color: Colors.black)
            : null,
      ),
      onTap: () => onChanged(value),
    );
  }
}

class _TapRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _TapRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _IconBox(icon),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Colors.white38, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: Colors.white24, size: 18),
      onTap: onTap,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoRow(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _IconBox(icon),
      title: Text(title,
          style: const TextStyle(color: Colors.white70, fontSize: 14)),
      subtitle: Text(subtitle,
          style:
              const TextStyle(color: Colors.white30, fontSize: 12)),
    );
  }
}

class _SegmentedRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;
  const _SegmentedRow({
    required this.title,
    required this.icon,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _IconBox(icon),
          const SizedBox(width: 12),
          Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
          const Spacer(),
          Container(
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: options.asMap().entries.map((e) {
                final isSelected = e.key == selected;
                return GestureDetector(
                  onTap: () => onChanged(e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Center(
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white
                              : Colors.white38,
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  const _IconBox(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: Colors.white54),
    );
  }
}
