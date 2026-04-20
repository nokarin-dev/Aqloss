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
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Audio Output
          _SectionHeader('Audio Output'),
          RadioListTile<AudioOutputMode>(
            title: const Text('Bit-perfect / Exclusive'),
            subtitle: const Text(
              'Bypasses system mixer. Best quality. (WASAPI Exclusive, CoreAudio)',
            ),
            value: AudioOutputMode.exclusive,
            groupValue: settings.outputMode,
            onChanged: (v) => notifier.setOutputMode(v!),
          ),
          RadioListTile<AudioOutputMode>(
            title: const Text('System mixer'),
            subtitle: const Text(
              'Goes through OS audio stack. May resample or alter audio.',
            ),
            value: AudioOutputMode.system,
            groupValue: settings.outputMode,
            onChanged: (v) => notifier.setOutputMode(v!),
          ),

          // Playback
          _SectionHeader('Playback'),
          SwitchListTile(
            title: const Text('Gapless playback'),
            subtitle: const Text('No silence between tracks'),
            value: settings.gaplessPlayback,
            onChanged: (_) => notifier.toggleGapless(),
          ),
          SwitchListTile(
            title: const Text('ReplayGain'),
            subtitle: const Text('Normalize volume across tracks'),
            value: settings.replayGainEnabled,
            onChanged: (_) => notifier.toggleReplayGain(),
          ),

          // Library
          _SectionHeader('Library'),
          SwitchListTile(
            title: const Text('Show bit depth & sample rate'),
            subtitle: const Text('Display hi-res info in track list'),
            value: settings.showBitDepthInLibrary,
            onChanged: (_) => notifier.toggleBitDepthDisplay(),
          ),

          // Appearance
          _SectionHeader('Appearance'),
          ListTile(
            title: const Text('Theme'),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: const Text('Dark'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: const Text('Light'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: const Text('System'),
                ),
              ],
              onChanged: (v) => notifier.setTheme(v!),
            ),
          ),

          // Last.fm
          _SectionHeader('Last.fm'),
          SwitchListTile(
            title: const Text('Scrobble to Last.fm'),
            value: settings.scrobbleLastFm,
            onChanged: (_) => notifier.toggleScrobble(),
          ),
          if (settings.scrobbleLastFm)
            ListTile(
              title: const Text('Username'),
              subtitle: Text(settings.lastFmUsername ?? 'Not set'),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => _showUsernameDialog(context, notifier, settings),
            ),

          // About
          _SectionHeader('About'),
          ListTile(
            title: const Text('Aqloss'),
            subtitle: const Text('v0.1.0 - Lossless everywhere.'),
            leading: const Icon(Icons.info_outline),
          ),

          const SizedBox(height: 32),
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
        title: const Text('Last.fm Username'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter your username'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              notifier.setLastFmUsername(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
