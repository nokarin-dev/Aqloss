import 'dart:io';

import 'package:aqloss/widgets/q_spinner.dart';
import 'package:aqloss/widgets/eq_panel.dart';
import 'package:aqloss/widgets/lastfm_auth_row.dart';
import 'package:aqloss/widgets/shared/custom_slider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/providers/audio_device_provider.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/util/android_path_helper.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Top-level page entries
enum _SettingsPage {
  musicFolders,
  audioOutput,
  playback,
  dsp,
  display,
  lastfm,
  shortcuts,
  about,
}

extension _SettingsPageX on _SettingsPage {
  String get label => switch (this) {
    _SettingsPage.musicFolders => 'Music Folders',
    _SettingsPage.audioOutput => 'Audio Output',
    _SettingsPage.playback => 'Playback',
    _SettingsPage.dsp => 'DSP / EQ',
    _SettingsPage.display => 'Display',
    _SettingsPage.lastfm => 'Last.fm',
    _SettingsPage.shortcuts => 'Shortcuts',
    _SettingsPage.about => 'About',
  };

  String get subtitle => switch (this) {
    _SettingsPage.musicFolders =>
      'Directories that Shiranami watches for audio files',
    _SettingsPage.audioOutput => 'Device and output mode selection',
    _SettingsPage.playback => 'Gapless, crossfade, ReplayGain, skip silence',
    _SettingsPage.dsp => 'Equalizer bands and soft-clip limiter',
    _SettingsPage.display => 'Theme, spectrum analyser, album art',
    _SettingsPage.lastfm => 'Scrobbling and account authentication',
    _SettingsPage.shortcuts => 'Global keyboard shortcuts',
    _SettingsPage.about => 'Version info and logs',
  };

  IconData get icon => switch (this) {
    _SettingsPage.musicFolders => Icons.folder_outlined,
    _SettingsPage.audioOutput => Icons.speaker_outlined,
    _SettingsPage.playback => Icons.play_circle_outline_rounded,
    _SettingsPage.dsp => Icons.equalizer_rounded,
    _SettingsPage.display => Icons.palette_outlined,
    _SettingsPage.lastfm => Icons.podcasts_rounded,
    _SettingsPage.shortcuts => Icons.keyboard_outlined,
    _SettingsPage.about => Icons.info_outline_rounded,
  };

  String get section => switch (this) {
    _SettingsPage.musicFolders || _SettingsPage.audioOutput => 'LIBRARY',
    _SettingsPage.playback || _SettingsPage.dsp => 'PLAYBACK',
    _SettingsPage.display || _SettingsPage.lastfm => 'APPEARANCE',
    _SettingsPage.shortcuts || _SettingsPage.about => 'SYSTEM',
  };
}

// Root widget
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  _SettingsPage _page = _SettingsPage.musicFolders;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioDeviceProvider.notifier).scan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 640;
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    if (narrow) {
      return _NarrowSettings(
        page: _page,
        onSelect: (p) => setState(() => _page = p),
        isDesktop: isDesktop,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left sidebar nav
        _SettingsSidebar(
          current: _page,
          isDesktop: isDesktop,
          onSelect: (p) => setState(() => _page = p),
        ),

        // Right content pane
        Expanded(
          child: _SettingsContent(page: _page, isDesktop: isDesktop),
        ),
      ],
    );
  }
}

// Sidebar
class _SettingsSidebar extends ConsumerWidget {
  final _SettingsPage current;
  final bool isDesktop;
  final ValueChanged<_SettingsPage> onSelect;

  const _SettingsSidebar({
    required this.current,
    required this.isDesktop,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final library = ref.watch(libraryProvider);
    final isScanning = library.status == LibraryStatus.scanning;

    final pages = isDesktop
        ? _SettingsPage.values
        : _SettingsPage.values
              .where((p) => p != _SettingsPage.shortcuts)
              .toList();

    // Group by section
    final sections = <String, List<_SettingsPage>>{};
    for (final page in pages) {
      sections.putIfAbsent(page.section, () => []).add(page);
    }

    return Container(
      width: 220,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: cs.onSurface.withValues(alpha: 0.055)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Aqloss preferences',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.28),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in sections.entries) ...[
                    _SidebarSectionLabel(entry.key),
                    for (final page in entry.value)
                      _SidebarNavItem(
                        page: page,
                        isActive: current == page,
                        isScanning:
                            page == _SettingsPage.musicFolders && isScanning,
                        onTap: () => onSelect(page),
                      ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  final String label;
  const _SidebarSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: cs.onSurface.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  final _SettingsPage page;
  final bool isActive;
  final bool isScanning;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.page,
    required this.isActive,
    required this.isScanning,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = widget.isActive;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? cs.onSurface.withValues(alpha: 0.09)
                : _hovered
                ? cs.onSurface.withValues(alpha: 0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(
                widget.page.icon,
                size: 15,
                color: active
                    ? cs.onSurface.withValues(alpha: 0.82)
                    : cs.onSurface.withValues(alpha: 0.38),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.page.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                    color: active
                        ? cs.onSurface.withValues(alpha: 0.88)
                        : cs.onSurface.withValues(alpha: 0.52),
                  ),
                ),
              ),
              if (widget.isScanning)
                QSpinner(
                  size: 10,
                  color: cs.onSurface.withValues(alpha: 0.28),
                  strokeWidth: 1.4,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Content pane dispatcher
class _SettingsContent extends StatelessWidget {
  final _SettingsPage page;
  final bool isDesktop;

  const _SettingsContent({required this.page, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return switch (page) {
      _SettingsPage.musicFolders => const _MusicFoldersPane(),
      _SettingsPage.audioOutput => const _AudioOutputPane(),
      _SettingsPage.playback => const _PlaybackPane(),
      _SettingsPage.dsp => const _DspPane(),
      _SettingsPage.display => const _DisplayPane(),
      _SettingsPage.lastfm => const _LastFmPane(),
      _SettingsPage.shortcuts => const _ShortcutsPane(),
      _SettingsPage.about => const _AboutPane(),
    };
  }
}

// Narrow fallback (single-column) ─────────────────────────────────────────

class _NarrowSettings extends StatelessWidget {
  final _SettingsPage page;
  final ValueChanged<_SettingsPage> onSelect;
  final bool isDesktop;

  const _NarrowSettings({
    required this.page,
    required this.onSelect,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsContent(page: page, isDesktop: isDesktop);
  }
}

// Shared pane wrapper
class _Pane extends StatelessWidget {
  final _SettingsPage page;
  final List<Widget> children;

  const _Pane({required this.page, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      page.icon,
                      size: 16,
                      color: cs.onSurface.withValues(alpha: 0.30),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      page.label,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.88),
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Text(
                    page.subtitle,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.26),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
          sliver: SliverList(delegate: SliverChildListDelegate(children)),
        ),
      ],
    );
  }
}

// Music Folders pane
class _MusicFoldersPane extends ConsumerWidget {
  const _MusicFoldersPane();

  Future<void> _addFolder(BuildContext context, WidgetRef ref) async {
    if (Platform.isAndroid) {
      final granted = await requestAndroidStoragePermission();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Storage permission required to scan music folders',
              ),
            ),
          );
        }
        return;
      }
    }
    final result = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select music folder',
    );
    if (result != null) {
      final path = resolveAndroidPath(result);
      ref.read(libraryProvider.notifier).addFolder(path);
    }
  }

  String _shortPath(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    if (parts.length <= 3) return path;
    return '…/${parts.sublist(parts.length - 2).join('/')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final library = ref.watch(libraryProvider);
    final folders = library.folders;
    final isScanning = library.status == LibraryStatus.scanning;

    return _Pane(
      page: _SettingsPage.musicFolders,
      children: [
        // Folder list card
        _SettingsCard(
          children: [
            if (folders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 20,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_off_outlined,
                      size: 14,
                      color: cs.onSurface.withValues(alpha: 0.18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'No folders added yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.28),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (int i = 0; i < folders.length; i++) ...[
                if (i > 0) _Div(),
                _FolderRow(
                  path: folders[i],
                  shortPath: _shortPath(folders[i]),
                  onRemove: () => ref
                      .read(libraryProvider.notifier)
                      .removeFolder(folders[i]),
                ),
              ],
          ],
        ),

        const SizedBox(height: 12),

        // Action row
        Row(
          children: [
            _ActionButton(
              icon: Icons.add_rounded,
              label: 'Add Folder',
              disabled: isScanning,
              onTap: () => _addFolder(context, ref),
            ),
            const SizedBox(width: 8),
            _ActionButton(
              icon: isScanning ? null : Icons.refresh_rounded,
              spinner: isScanning,
              label: isScanning ? 'Scanning…' : 'Rescan Library',
              disabled: isScanning || folders.isEmpty,
              onTap: () => ref.read(libraryProvider.notifier).rescanAll(),
            ),
          ],
        ),

        if (library.totalTracks > 0) ...[
          const SizedBox(height: 20),
          _SettingsCard(
            children: [
              _InfoRow(
                icon: Icons.music_note_rounded,
                title: 'Tracks indexed',
                value: '${library.totalTracks}',
              ),
              _Div(),
              _InfoRow(
                icon: Icons.folder_rounded,
                title: 'Watched folders',
                value: '${folders.length}',
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FolderRow extends StatefulWidget {
  final String path;
  final String shortPath;
  final VoidCallback onRemove;

  const _FolderRow({
    required this.path,
    required this.shortPath,
    required this.onRemove,
  });

  @override
  State<_FolderRow> createState() => _FolderRowState();
}

class _FolderRowState extends State<_FolderRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _hovered
            ? cs.onSurface.withValues(alpha: 0.02)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Icon(
              Icons.folder_rounded,
              size: 14,
              color: cs.onSurface.withValues(alpha: 0.24),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.shortPath,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: cs.onSurface.withValues(alpha: 0.70),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.path != widget.shortPath)
                    Text(
                      widget.path,
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: 0.20),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: _hovered ? 1 : 0.3,
              child: _IconBtn26(
                icon: Icons.remove_rounded,
                onTap: widget.onRemove,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData? icon;
  final bool spinner;
  final String label;
  final bool disabled;
  final VoidCallback? onTap;

  const _ActionButton({
    this.icon,
    this.spinner = false,
    required this.label,
    this.disabled = false,
    this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final alpha = widget.disabled ? 0.3 : 1.0;

    return MouseRegion(
      cursor: widget.disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.disabled ? null : widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: alpha,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: _hovered && !widget.disabled
                  ? cs.onSurface.withValues(alpha: 0.07)
                  : cs.onSurface.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.spinner)
                  QSpinner(
                    size: 11,
                    color: cs.onSurface.withValues(alpha: 0.40),
                    strokeWidth: 1.4,
                  )
                else if (widget.icon != null)
                  Icon(
                    widget.icon,
                    size: 13,
                    color: cs.onSurface.withValues(alpha: 0.50),
                  ),
                const SizedBox(width: 7),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Audio Output pane
class _AudioOutputPane extends ConsumerWidget {
  const _AudioOutputPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devAsync = ref.watch(audioDeviceProvider);

    return _Pane(
      page: _SettingsPage.audioOutput,
      children: [
        devAsync.when(
          loading: () => const _AudioDeviceSection(),
          error: (_, _) => const _AudioDeviceSection(),
          data: (_) => const _AudioDeviceSection(),
        ),
      ],
    );
  }
}

// Kept as-is from original, just moved here
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
            QSpinner(
              size: 13,
              color: cs.onSurface.withValues(alpha: 0.36),
              strokeWidth: 1.5,
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

// ─── Playback pane ────────────────────────────────────────────────────────────

class _PlaybackPane extends ConsumerWidget {
  const _PlaybackPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    return _Pane(
      page: _SettingsPage.playback,
      children: [
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
              subtitle: 'Normalises loudness using tags embedded in the file.',
              options: const ['Off', 'Track', 'Album', 'Auto'],
              selected: s.replayGainMode.index,
              onChanged: (i) => n.setReplayGainMode(ReplayGainMode.values[i]),
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
                label: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)} dB',
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
      ],
    );
  }
}

// DSP pane
class _DspPane extends ConsumerWidget {
  const _DspPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    return _Pane(
      page: _SettingsPage.dsp,
      children: [
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
      ],
    );
  }
}

// Display pane
class _DisplayPane extends ConsumerWidget {
  const _DisplayPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    return _Pane(
      page: _SettingsPage.display,
      children: [
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
            _PickerRow(
              icon: Icons.palette_outlined,
              title: 'UI Style',
              subtitle: 'Choose between Legacy or Islands sidebar style.',
              options: const ['Legacy', 'Islands'],
              selected: s.appStyle.index,
              onChanged: (i) => n.setAppStyle(AppStyle.values[i]),
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
              subtitle: 'Shows bit depth and sample rate next to each track.',
              value: s.showBitDepthInLibrary,
              onChanged: (_) => n.toggleBitDepthDisplay(),
            ),
            _Div(),
            _ToggleRow(
              icon: Icons.show_chart_rounded,
              title: 'Spectrum analyser',
              subtitle: 'Real-time frequency display on the player screen.',
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
      ],
    );
  }
}

// Last.fm pane
class _LastFmPane extends ConsumerWidget {
  const _LastFmPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    return _Pane(
      page: _SettingsPage.lastfm,
      children: [
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
      ],
    );
  }
}

// Shortcuts pane
class _ShortcutsPane extends StatelessWidget {
  const _ShortcutsPane();

  @override
  Widget build(BuildContext context) {
    return _Pane(
      page: _SettingsPage.shortcuts,
      children: [
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
            _ShortcutRow(label: 'Albums', shortcut: 'Ctrl 3'),
            _Div(),
            _ShortcutRow(label: 'Settings', shortcut: 'Ctrl 4'),
            _Div(),
            _ShortcutRow(label: 'New playlist', shortcut: 'Ctrl N'),
          ],
        ),
      ],
    );
  }
}

// About pane
class _AboutPane extends StatelessWidget {
  const _AboutPane();

  @override
  Widget build(BuildContext context) {
    return _Pane(
      page: _SettingsPage.about,
      children: [
        _SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_rounded,
                    size: 15,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Logs Folder',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.42),
                      ),
                    ),
                  ),
                  _HoverTextBtn(
                    label: 'Open Logs',
                    onTap: () async {
                      final appDir = await getApplicationSupportDirectory();
                      final logDirPath = p.join(appDir.path, 'logs');
                      OpenFile.open(logDirPath);
                    },
                  ),
                ],
              ),
            ),
            _Div(),
            const _InfoRow(
              icon: Icons.music_note_rounded,
              title: 'Aqloss',
              value: 'Version 0.2.3',
            ),
            _Div(),
            const _InfoRow(
              icon: Icons.memory_rounded,
              title: 'Audio engine',
              value: 'Rust · Symphonia',
            ),
            _Div(),
            const _InfoRow(
              icon: Icons.headphones_rounded,
              title: 'Output backends',
              value: 'CPAL · WASAPI',
            ),
          ],
        ),
      ],
    );
  }
}

// Shared primitives
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
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(horizontal: 14),
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
  );
}

class _IconBtn26 extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn26({required this.icon, required this.onTap});

  @override
  State<_IconBtn26> createState() => _IconBtn26State();
}

class _IconBtn26State extends State<_IconBtn26> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: _hovered
                ? cs.onSurface.withValues(alpha: 0.07)
                : cs.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.icon,
            size: 13,
            color: cs.onSurface.withValues(alpha: 0.36),
          ),
        ),
      ),
    );
  }
}

// Row types

class _ToggleRow extends StatefulWidget {
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
  State<_ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends State<_ToggleRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          color: _hovered
              ? cs.onSurface.withValues(alpha: 0.025)
              : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    widget.icon,
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
                        widget.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.80),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
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
                  child: _MiniSwitch(
                    value: widget.value,
                    onChanged: widget.onChanged,
                  ),
                ),
              ],
            ),
          ),
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
            child: _RangeSlider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              cs: cs,
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeSlider extends StatefulWidget {
  final double value, min, max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ColorScheme cs;
  const _RangeSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.cs,
  });
  @override
  State<_RangeSlider> createState() => _RangeSliderState();
}

class _RangeSliderState extends State<_RangeSlider> {
  void _snap(double normalised) {
    final range = widget.max - widget.min;
    final step = range / widget.divisions;
    final raw = widget.min + normalised * range;
    final snapped = (raw / step).round() * step;
    widget.onChanged(snapped.clamp(widget.min, widget.max));
  }

  @override
  Widget build(BuildContext context) {
    final normalised = ((widget.value - widget.min) / (widget.max - widget.min))
        .clamp(0.0, 1.0);
    return CustomSlider(
      value: normalised,
      trackHeight: 2,
      thumbRadius: 6,
      activeColor: widget.cs.onSurface.withValues(alpha: 0.58),
      inactiveColor: widget.cs.onSurface.withValues(alpha: 0.10),
      thumbColor: widget.cs.onSurface.withValues(alpha: 0.80),
      onChanged: _snap,
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

class _HoverTextBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _HoverTextBtn({required this.label, required this.onTap});
  @override
  State<_HoverTextBtn> createState() => _HoverTextBtnState();
}

class _HoverTextBtnState extends State<_HoverTextBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered
                ? cs.onSurface.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.12)),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.60),
            ),
          ),
        ),
      ),
    );
  }
}

// Audio output pane
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
      cursor: SystemMouseCursors.click,
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
                QSpinner(
                  size: 11,
                  color: cs.onSurface.withValues(alpha: 0.36),
                  strokeWidth: 1.5,
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
    cursor: SystemMouseCursors.click,
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
