import 'dart:io';

import 'package:aqloss/app_version.dart';
import 'package:aqloss/util/search_focus_tracker.dart';
import 'package:aqloss/util/update_check.dart';
import 'package:aqloss/screens/plugin_pane.dart';

import 'package:aqloss/services/audio_service.dart';
import 'package:aqloss/services/discord_service.dart';
import 'package:aqloss/services/loved_sync.dart';
import 'package:aqloss/widgets/q_spinner.dart';
import 'package:aqloss/widgets/eq_panel.dart';
import 'package:aqloss/widgets/lastfm_auth_row.dart';
import 'package:aqloss/widgets/listenbrainz_auth_row.dart';
import 'package:aqloss/widgets/shared/custom_slider.dart';
import 'package:aqloss/services/folder_picker.dart';
import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/audio_device_provider.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/services/settings_backup_service.dart';
import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/theme/ui_framework.dart';
import 'package:aqloss/util/notices.dart';
import 'package:aqloss/util/open_url.dart';
import 'package:aqloss/util/playback_speed.dart';
import 'package:aqloss/util/settings_backup.dart';
import 'package:aqloss/util/support_links.dart';
import 'package:aqloss/widgets/ui/ui_kit.dart';
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
  shortcuts,
  integrations,
  plugins,
  updates,
  support,
  about,
}

extension _SettingsPageX on _SettingsPage {
  String get label => switch (this) {
    _SettingsPage.musicFolders => 'Music Folders',
    _SettingsPage.audioOutput => 'Audio Output',
    _SettingsPage.playback => 'Playback',
    _SettingsPage.dsp => 'DSP / EQ',
    _SettingsPage.display => 'Display',
    _SettingsPage.integrations => 'Integrations',
    _SettingsPage.shortcuts => 'Shortcuts',
    _SettingsPage.plugins => 'Plugins',
    _SettingsPage.updates => 'Updates',
    _SettingsPage.support => 'Support',
    _SettingsPage.about => 'About',
  };

  String get subtitle => switch (this) {
    _SettingsPage.musicFolders => 'Folders Aqloss scans for audio files',
    _SettingsPage.audioOutput => 'Device and output mode selection',
    _SettingsPage.playback => 'Gapless, crossfade, ReplayGain, skip silence',
    _SettingsPage.dsp => 'Equalizer, soft-clip, stereo width and depth',
    _SettingsPage.display => 'Theme, spectrum analyser, album art',
    _SettingsPage.integrations =>
      'Manage external services, rich presence, and plugins',
    _SettingsPage.shortcuts => 'Global keyboard shortcuts',
    _SettingsPage.plugins => 'Installed third-party and built-in plugins',
    _SettingsPage.updates => 'Check for new releases',
    _SettingsPage.support => 'Ko-fi, Trakteer, and other ways to help',
    _SettingsPage.about => 'Version, logs, and backup',
  };

  IconData get icon => switch (this) {
    _SettingsPage.musicFolders => Icons.folder_outlined,
    _SettingsPage.audioOutput => Icons.speaker_outlined,
    _SettingsPage.playback => Icons.play_circle_outline_rounded,
    _SettingsPage.dsp => Icons.equalizer_rounded,
    _SettingsPage.display => Icons.palette_outlined,
    _SettingsPage.integrations => Icons.extension_outlined,
    _SettingsPage.shortcuts => Icons.keyboard_outlined,
    _SettingsPage.plugins => Icons.widgets_outlined,
    _SettingsPage.updates => Icons.system_update_alt_rounded,
    _SettingsPage.support => Icons.favorite_border_rounded,
    _SettingsPage.about => Icons.info_outline_rounded,
  };

  String get section => switch (this) {
    _SettingsPage.musicFolders || _SettingsPage.audioOutput => 'LIBRARY',
    _SettingsPage.playback || _SettingsPage.dsp => 'PLAYBACK',
    _SettingsPage.display || _SettingsPage.integrations => 'APPEARANCE',
    _SettingsPage.shortcuts ||
    _SettingsPage.plugins ||
    _SettingsPage.updates ||
    _SettingsPage.support ||
    _SettingsPage.about => 'SYSTEM',
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

    // On narrow screens fall back to single-column
    if (narrow) {
      return _NarrowSettings(
        page: _page,
        onSelect: (p) => setState(() => _page = p),
        isDesktop: isDesktop,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left sidebar nav
        _SettingsSidebar(
          current: _page,
          isDesktop: isDesktop,
          onSelect: (p) => setState(() => _page = p),
        ),

        // Right content pane
        Expanded(
          child: _SettingsContent(
            page: _page,
            isDesktop: isDesktop,
            onOpenSupport: () => setState(() => _page = _SettingsPage.support),
          ),
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
    final library = ref.watch(libraryProvider);
    final isScanning = library.status == LibraryStatus.scanning;

    final pages = isDesktop
        ? _SettingsPage.values
        : _SettingsPage.values
              .where((p) => p != _SettingsPage.shortcuts)
              .toList();

    final sections = <String, List<_SettingsPage>>{};
    for (final page in pages) {
      sections.putIfAbsent(page.section, () => []).add(page);
    }

    if (context.isMaterial3Ui) {
      final theme = Theme.of(context);
      final cs = theme.colorScheme;
      return Material(
        color: cs.surfaceContainerLow,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
          ),
          child: SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Playback, library, and appearance',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
                    children: [
                      for (final entry in sections.entries) ...[
                        _SidebarSectionLabel(entry.key),
                        for (final page in entry.value)
                          _SidebarNavItem(
                            page: page,
                            isActive: current == page,
                            isScanning:
                                page == _SettingsPage.musicFolders &&
                                isScanning,
                            onTap: () => onSelect(page),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final aq = context.aq;
    return Container(
      width: 220,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: aq.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    color: aq.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Aqloss preferences',
                  style: TextStyle(color: aq.onSurfaceMuted, fontSize: 10.5),
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
    if (context.isMaterial3Ui) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 8, 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final aq = context.aq;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: aq.onSurfaceMuted,
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
    final active = widget.isActive;

    if (context.isMaterial3Ui) {
      final cs = Theme.of(context).colorScheme;
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(28),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? cs.secondaryContainer
                      : _hovered
                      ? cs.onSurface.withValues(alpha: 0.06)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.page.icon,
                      size: 20,
                      color: active
                          ? cs.onSecondaryContainer
                          : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.page.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: active
                              ? cs.onSecondaryContainer
                              : cs.onSurface,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (widget.isScanning)
                      QSpinner(
                        size: 12,
                        color: cs.onSurfaceVariant,
                        strokeWidth: 1.4,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final aq = context.aq;

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
                ? aq.indicator
                : _hovered
                ? aq.onSurface.withValues(alpha: 0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(
                widget.page.icon,
                size: 15,
                color: active
                    ? aq.onSurface.withValues(alpha: 0.82)
                    : aq.onSurfaceMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.page.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                    color: active
                        ? aq.onSurface.withValues(alpha: 0.88)
                        : aq.onSurface.withValues(alpha: 0.52),
                  ),
                ),
              ),
              if (widget.isScanning)
                QSpinner(size: 10, color: aq.onSurfaceMuted, strokeWidth: 1.4),
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
  final VoidCallback onOpenSupport;

  const _SettingsContent({
    required this.page,
    required this.isDesktop,
    required this.onOpenSupport,
  });

  @override
  Widget build(BuildContext context) {
    return switch (page) {
      _SettingsPage.musicFolders => const _MusicFoldersPane(),
      _SettingsPage.audioOutput => const _AudioOutputPane(),
      _SettingsPage.playback => const _PlaybackPane(),
      _SettingsPage.dsp => const _DspPane(),
      _SettingsPage.display => const _DisplayPane(),
      _SettingsPage.integrations => const _IntegrationsPane(),
      _SettingsPage.shortcuts => const _ShortcutsPane(),
      _SettingsPage.plugins => const PluginsPane(),
      _SettingsPage.updates => const _UpdatesPane(),
      _SettingsPage.support => const _SupportPane(),
      _SettingsPage.about => _AboutPane(onOpenSupport: onOpenSupport),
    };
  }
}

// Narrow fallback
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
    if (context.isMaterial3Ui) {
      final pages = isDesktop
          ? _SettingsPage.values
          : _SettingsPage.values
                .where((p) => p != _SettingsPage.shortcuts)
                .toList();
      final theme = Theme.of(context);
      final cs = theme.colorScheme;
      final sections = <String, List<_SettingsPage>>{};
      for (final p in pages) {
        sections.putIfAbsent(p.section, () => []).add(p);
      }

      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(title: Text(page.label), scrolledUnderElevation: 0),
        drawer: NavigationDrawer(
          selectedIndex: pages.indexOf(page),
          onDestinationSelected: (i) {
            onSelect(pages[i]);
            Navigator.pop(context);
          },
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 16, 8),
              child: Text(
                'Settings',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final entry in sections.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 16, 8),
                child: Text(
                  entry.key,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final p in entry.value)
                NavigationDrawerDestination(
                  icon: Icon(p.icon),
                  label: Text(p.label),
                ),
            ],
          ],
        ),
        body: _SettingsContent(
          page: page,
          isDesktop: isDesktop,
          onOpenSupport: () => onSelect(_SettingsPage.support),
        ),
      );
    }

    final aq = context.aq;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: _NarrowSettingsNav(current: page, onSelect: onSelect),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.only(top: 10),
          color: aq.border,
        ),
        Expanded(
          child: _SettingsContent(
            page: page,
            isDesktop: isDesktop,
            onOpenSupport: () => onSelect(_SettingsPage.support),
          ),
        ),
      ],
    );
  }
}

class _NarrowSettingsNav extends StatelessWidget {
  final _SettingsPage current;
  final ValueChanged<_SettingsPage> onSelect;

  const _NarrowSettingsNav({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final aq = context.aq;
    final sections = <String, List<_SettingsPage>>{};
    for (final p in _SettingsPage.values) {
      sections.putIfAbsent(p.section, () => []).add(p);
    }

    return Row(
      children: [
        for (final entry in sections.entries) ...[
          for (final p in entry.value)
            _NarrowNavChip(
              page: p,
              active: current == p,
              onTap: () => onSelect(p),
            ),
          if (entry.key != sections.keys.last)
            Container(
              width: 1,
              height: 22,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: aq.border,
            ),
        ],
      ],
    );
  }
}

class _NarrowNavChip extends StatelessWidget {
  final _SettingsPage page;
  final bool active;
  final VoidCallback onTap;

  const _NarrowNavChip({
    required this.page,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final aq = context.aq;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active ? aq.indicator : aq.onSurface.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? aq.border : aq.onSurface.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              page.icon,
              size: 12,
              color: active
                  ? aq.onSurface.withValues(alpha: 0.80)
                  : aq.onSurfaceMuted,
            ),
            const SizedBox(width: 5),
            Text(
              page.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                color: active
                    ? aq.onSurface.withValues(alpha: 0.86)
                    : aq.onSurface.withValues(alpha: 0.40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Shared pane wrapper
class _Pane extends StatelessWidget {
  final _SettingsPage page;
  final List<Widget> children;

  const _Pane({required this.page, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (context.isMaterial3Ui) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    page.label,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    page.subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 48),
            sliver: SliverList(delegate: SliverChildListDelegate(children)),
          ),
        ],
      );
    }

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
    final library = ref.read(libraryProvider.notifier);
    await addMusicFolderFromPicker(context, onAdded: library.addFolder);
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
                    onSelect: (mode) async {
                      try {
                        await ref
                            .read(audioDeviceProvider.notifier)
                            .selectDevice(state.devices[i].id, mode);
                      } catch (e) {
                        if (!context.mounted) return;
                        final text = e.toString().replaceFirst(
                          'Exception: ',
                          '',
                        );
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(text)));
                      }
                    },
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
          if (Platform.isLinux) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Exclusive / bit-perfect is only available on ALSA hardware devices (hw:). PipeWire and other mixer outputs stay in shared mode. Switching to exclusive pauses other apps on the sound card.',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.38),
                  height: 1.4,
                ),
              ),
            ),
          ],
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

// Playback pane
class _PlaybackPane extends ConsumerWidget {
  const _PlaybackPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final bitPerfect = ref.watch(exclusiveModeProvider);

    return _Pane(
      page: _SettingsPage.playback,
      children: [
        if (bitPerfect) ...[
          const _ExclusiveLockBanner(
            'Exclusive mode is on. Crossfade, ReplayGain, skip silence, and playback speed can\'t be used.',
          ),
          const SizedBox(height: 16),
        ],
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
              disabled: s.gaplessPlayback || bitPerfect,
              disabledHint: bitPerfect
                  ? kBitPerfectUnavailableHint
                  : 'Disabled while gapless is on',
            ),
            _Div(),
            _PickerRow(
              icon: Icons.graphic_eq_rounded,
              title: 'ReplayGain',
              subtitle: 'Normalises loudness using tags embedded in the file.',
              options: const ['Off', 'Track', 'Album', 'Auto'],
              selected: s.replayGainMode.index,
              onChanged: (i) => n.setReplayGainMode(ReplayGainMode.values[i]),
              disabled: bitPerfect,
              disabledHint: kBitPerfectUnavailableHint,
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
                disabled: bitPerfect,
                disabledHint: kBitPerfectUnavailableHint,
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
              disabled: bitPerfect,
              disabledHint: kBitPerfectUnavailableHint,
            ),
            _Div(),
            _PickerRow(
              icon: Icons.slow_motion_video_rounded,
              title: 'Playback speed',
              subtitle: 'Play faster or slower. Pitch follows the speed.',
              options: kPlaybackSpeedLabels,
              selected: playbackSpeedIndex(s.playbackSpeed),
              onChanged: (i) => n.setPlaybackSpeed(kPlaybackSpeeds[i]),
              disabled: bitPerfect,
              disabledHint: kBitPerfectUnavailableHint,
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
    final bitPerfect = ref.watch(exclusiveModeProvider);

    return _Pane(
      page: _SettingsPage.dsp,
      children: [
        if (bitPerfect) ...[
          const _ExclusiveLockBanner(
            'Exclusive mode is on. EQ, soft-clip, stereo width, and Haas delay can\'t be used.',
          ),
          const SizedBox(height: 16),
        ],
        _SettingsCard(
          children: [
            _ToggleRow(
              icon: Icons.bar_chart_rounded,
              title: '10-band Equalizer',
              subtitle: 'Per-frequency gain ±12 dB using peaking EQ filters.',
              value: s.eqEnabled,
              onChanged: (_) => n.toggleEq(),
              disabled: bitPerfect,
              disabledHint: kBitPerfectUnavailableHint,
            ),
            if (s.eqEnabled && !bitPerfect) ...[_Div(), const EqPanel()],
            _Div(),
            _ToggleRow(
              icon: Icons.compress_rounded,
              title: 'Soft-clip limiter',
              subtitle:
                  'Prevents digital clipping above 0 dBFS. Recommended with ReplayGain pre-amp or EQ boosts.',
              value: s.notchFilter,
              onChanged: (_) => n.toggleNotchFilter(),
              disabled: bitPerfect,
              disabledHint: kBitPerfectUnavailableHint,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsCard(
          children: [
            _LiveSliderRow(
              icon: Icons.spatial_audio_off_rounded,
              title: 'Stereo Width',
              subtitle:
                  'M/S expansion. Below 1.0 narrows the image; above 1.0 pushes instruments further apart. 1.0 = off.',
              value: s.stereoWidth,
              min: 0.0,
              max: 2.0,
              divisions: 40,
              label: (v) {
                if ((v - 1.0).abs() < 0.025) return 'Off';
                return v.toStringAsFixed(2);
              },
              onCommit: (v) {
                n.setStereoWidth(v);
                AudioService.setStereoWidth(v);
              },
              disabled: bitPerfect,
              disabledHint: kBitPerfectUnavailableHint,
            ),
            _Div(),
            _LiveSliderRow(
              icon: Icons.spatial_audio_rounded,
              title: 'Haas Delay',
              subtitle:
                  'Micro-delay on the right channel (0–25 ms) to create depth and front-back separation.',
              value: s.haasMs,
              min: 0.0,
              max: 25.0,
              divisions: 50,
              label: (v) => v < 0.5 ? 'Off' : '${v.toStringAsFixed(0)} ms',
              onCommit: (v) {
                n.setHaasMs(v);
                AudioService.setHaasMs(v);
              },
              disabled: bitPerfect,
              disabledHint: kBitPerfectUnavailableHint,
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
              icon: Icons.layers_outlined,
              title: 'UI framework',
              subtitle:
                  'Default uses the custom Aqloss interface. Material 3 follows Google\'s design system.',
              options: const ['Default', 'Material Design 3'],
              selected: s.uiFramework.index,
              onChanged: (i) => n.setUiFramework(UiFramework.values[i]),
            ),
            if (s.uiFramework == UiFramework.standalone) ...[
              _Div(),
              _PickerRow(
                icon: Icons.palette_outlined,
                title: 'Sidebar style',
                subtitle: 'Legacy or Islands sidebar layout (default only).',
                options: const ['Legacy', 'Islands'],
                selected: s.appStyle.index,
                onChanged: (i) => n.setAppStyle(AppStyle.values[i]),
              ),
            ],
            if (s.uiFramework == UiFramework.material3) ...[
              _Div(),
              _ToggleRow(
                icon: Icons.color_lens_outlined,
                title: 'Dynamic colour',
                subtitle:
                    'Use system wallpaper colours (Android 12+, Windows 11, GNOME).',
                value: s.materialYou,
                onChanged: (_) => n.toggleMaterialYou(),
              ),
            ],
            _Div(),
            _ToggleRow(
              icon: Icons.speed_rounded,
              title: 'Hardware acceleration',
              subtitle:
                  'GPU rendering for the interface. Turn off if the UI glitches or looks jagged; restart Aqloss after changing.',
              value: s.hardwareAcceleration,
              onChanged: (_) => n.toggleHardwareAcceleration(),
            ),
            _Div(),
            _ToggleRow(
              icon: Icons.motion_photos_off_outlined,
              title: 'Reduce motion',
              subtitle:
                  'Skip waves, toasts, and page motion. Also follows the system reduce-motion setting.',
              value: s.reduceMotion,
              onChanged: (_) => n.toggleReduceMotion(),
            ),
            if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ...[
              _Div(),
              _ToggleRow(
                icon: Icons.web_asset_outlined,
                title: 'Show Title Bar',
                subtitle:
                    'Turns off the title bar on the window.',
                value: s.showTitleBar,
                onChanged: (_) => n.toggleShowTitleBar(),
              ),
            ],
            if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ...[
              _Div(),
              _ToggleRow(
                icon: Icons.desktop_windows_outlined,
                title: 'Close to tray',
                subtitle:
                    'Closing the window keeps music playing. Quit from the tray icon to exit.',
                value: s.closeToTray,
                onChanged: (_) => n.toggleCloseToTray(),
              ),
            ],
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
              icon: Icons.album_outlined,
              title: 'Now playing card',
              subtitle:
                  'Large card at the top of library pages. Off by default; the bottom bar already shows the current track.',
              value: s.showNowPlayingHeader,
              onChanged: (_) => n.toggleNowPlayingHeader(),
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
                options: const ['Bars', 'Wave', 'Dots', 'Classic'],
                selected: s.spectrumStyle,
                onChanged: n.setSpectrumStyle,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        const _AccentColorCard(),
      ],
    );
  }
}

// Accent color card
class _AccentColorCard extends ConsumerWidget {
  const _AccentColorCard();

  static const _swatches = [
    Color(0xFFFF453A),
    Color(0xFFFF9F0A),
    Color(0xFFFFD60A),
    Color(0xFF30D158),
    Color(0xFF64D2FF),
    Color(0xFF0A84FF),
    Color(0xFF5E5CE6),
    Color(0xFFBF5AF2),
    Color(0xFFFF375F),
    Color(0xFFFF6961),
    Color(0xFF34C759),
    Color(0xFF00C7BE),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return _SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.color_lens_outlined,
                    size: 16,
                    color: cs.onSurface.withValues(alpha: 0.40),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Accent colour',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.88),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tints interactive elements. Auto picks from album art.',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.36),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Mode toggle
                  _AccentModeChip(
                    label: 'Off',
                    selected: s.accentMode == AccentMode.off,
                    onTap: () => n.setAccentMode(AccentMode.off),
                    cs: cs,
                  ),
                  const SizedBox(width: 4),
                  _AccentModeChip(
                    label: 'Auto',
                    selected: s.accentMode == AccentMode.auto,
                    onTap: () => n.setAccentMode(AccentMode.auto),
                    cs: cs,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _swatches.map((color) {
                  final isSelected =
                      s.accentMode == AccentMode.custom &&
                      s.accentColor == color.toARGB32();
                  return GestureDetector(
                    onTap: () => n.setAccentColor(color.toARGB32()),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? cs.onSurface.withValues(alpha: 0.90)
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.40),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccentModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  const _AccentModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected
            ? cs.onSurface.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.onSurface.withValues(alpha: selected ? 0.16 : 0.08),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: cs.onSurface.withValues(alpha: selected ? 0.88 : 0.38),
        ),
      ),
    ),
  );
}

// Shortcuts pane
class _ShortcutsPane extends ConsumerStatefulWidget {
  const _ShortcutsPane();
  @override
  ConsumerState<_ShortcutsPane> createState() => _ShortcutsPaneState();
}

class _ShortcutsPaneState extends ConsumerState<_ShortcutsPane> {
  ShortcutAction? _capturing;

  void _startCapture(ShortcutAction action) {
    setState(() => _capturing = action);
    SearchFocusTracker.instance.setCapturingShortcut(true);
  }

  void _cancelCapture() {
    setState(() => _capturing = null);
    SearchFocusTracker.instance.setCapturingShortcut(false);
  }

  void _onKeyCaptured(ShortcutAction action, String key) {
    ref.read(settingsProvider.notifier).setShortcut(action, key);
    setState(() => _capturing = null);
    SearchFocusTracker.instance.setCapturingShortcut(false);
  }

  // Group actions for display
  static const _groups = <String, List<ShortcutAction>>{
    'PLAYBACK': [
      ShortcutAction.playPause,
      ShortcutAction.skipNext,
      ShortcutAction.skipPrevious,
      ShortcutAction.volumeUp,
      ShortcutAction.volumeDown,
    ],
    'APP': [
      ShortcutAction.toggleSidebar,
      ShortcutAction.toggleQueue,
      ShortcutAction.search,
      ShortcutAction.miniPlayer,
      ShortcutAction.newPlaylist,
    ],
    'NAVIGATE': [
      ShortcutAction.navPlayer,
      ShortcutAction.navLibrary,
      ShortcutAction.navAlbums,
      ShortcutAction.navArtists,
      ShortcutAction.navHistory,
      ShortcutAction.navSettings,
    ],
  };

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final cs = Theme.of(context).colorScheme;

    return _Pane(
      page: _SettingsPage.shortcuts,
      children: [
        for (final entry in _groups.entries) ...[
          if (entry.key != _groups.keys.first) const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              entry.key,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: cs.onSurface.withValues(alpha: 0.24),
              ),
            ),
          ),
          _SettingsCard(
            children: [
              for (int i = 0; i < entry.value.length; i++) ...[
                if (i > 0) _Div(),
                _ShortcutBindingRow(
                  action: entry.value[i],
                  bound: s.binding(entry.value[i]),
                  isDefault: !s.shortcuts.containsKey(entry.value[i]),
                  capturing: _capturing == entry.value[i],
                  onCapture: () => _startCapture(entry.value[i]),
                  onCancel: _cancelCapture,
                  onCaptured: (key) => _onKeyCaptured(entry.value[i], key),
                  onReset: () {
                    ref
                        .read(settingsProvider.notifier)
                        .resetShortcut(entry.value[i]);
                    if (_capturing == entry.value[i]) _cancelCapture();
                  },
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 16),
        _ActionButton(
          icon: Icons.refresh_rounded,
          label: 'Reset all to defaults',
          onTap: () {
            ref.read(settingsProvider.notifier).resetAllShortcuts();
            _cancelCapture();
          },
        ),
      ],
    );
  }
}

class _ShortcutBindingRow extends StatelessWidget {
  final ShortcutAction action;
  final String bound;
  final bool isDefault;
  final bool capturing;
  final VoidCallback onCapture;
  final VoidCallback onCancel;
  final void Function(String) onCaptured;
  final VoidCallback onReset;

  const _ShortcutBindingRow({
    required this.action,
    required this.bound,
    required this.isDefault,
    required this.capturing,
    required this.onCapture,
    required this.onCancel,
    required this.onCaptured,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              action.label,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ),
          if (capturing)
            _CaptureInput(onCaptured: onCaptured, onCancel: onCancel)
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onCapture,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 110),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(
                          alpha: isDefault ? 0.04 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: cs.onSurface.withValues(
                            alpha: isDefault ? 0.08 : 0.16,
                          ),
                        ),
                      ),
                      child: Text(
                        _prettyKey(bound),
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(
                            alpha: isDefault ? 0.42 : 0.72,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isDefault) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onReset,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(
                        Icons.restore_rounded,
                        size: 13,
                        color: cs.onSurface.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  String _prettyKey(String key) {
    const remap = {
      'ArrowLeft': '←',
      'ArrowRight': '→',
      'ArrowUp': '↑',
      'ArrowDown': '↓',
      'Space': '␣',
    };
    final parts = key.split('+');
    return parts.map((p) => remap[p] ?? p).join(' ');
  }
}

// Inline capture widget
class _CaptureInput extends StatefulWidget {
  final void Function(String) onCaptured;
  final VoidCallback onCancel;
  const _CaptureInput({required this.onCaptured, required this.onCancel});

  @override
  State<_CaptureInput> createState() => _CaptureInputState();
}

class _CaptureInputState extends State<_CaptureInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  String? _eventToKey(KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    final ctrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape) {
      widget.onCancel();
      return null;
    }
    if (key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.alt) {
      return null;
    }

    final namedLogical = <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.space: 'Space',
      LogicalKeyboardKey.arrowLeft: 'ArrowLeft',
      LogicalKeyboardKey.arrowRight: 'ArrowRight',
      LogicalKeyboardKey.arrowUp: 'ArrowUp',
      LogicalKeyboardKey.arrowDown: 'ArrowDown',
      LogicalKeyboardKey.enter: 'Enter',
      LogicalKeyboardKey.tab: 'Tab',
      LogicalKeyboardKey.backspace: 'Backspace',
      LogicalKeyboardKey.delete: 'Delete',
      LogicalKeyboardKey.home: 'Home',
      LogicalKeyboardKey.end: 'End',
      LogicalKeyboardKey.pageUp: 'PageUp',
      LogicalKeyboardKey.pageDown: 'PageDown',
      LogicalKeyboardKey.f1: 'F1',
      LogicalKeyboardKey.f2: 'F2',
      LogicalKeyboardKey.f3: 'F3',
      LogicalKeyboardKey.f4: 'F4',
      LogicalKeyboardKey.f5: 'F5',
      LogicalKeyboardKey.f6: 'F6',
      LogicalKeyboardKey.f7: 'F7',
      LogicalKeyboardKey.f8: 'F8',
      LogicalKeyboardKey.f9: 'F9',
      LogicalKeyboardKey.f10: 'F10',
      LogicalKeyboardKey.f11: 'F11',
      LogicalKeyboardKey.f12: 'F12',
    };

    String? keyName;
    if (ctrl) {
      keyName = _resolvePhysical(event.physicalKey);
    }
    keyName ??= namedLogical.containsKey(key)
        ? namedLogical[key]!
        : (key.keyLabel.isNotEmpty ? key.keyLabel.toUpperCase() : null);
    if (keyName == null) return null;

    final parts = <String>[if (ctrl) 'Ctrl', if (shift) 'Shift', keyName];
    return parts.join('+');
  }

  static String? _resolvePhysical(PhysicalKeyboardKey physical) {
    final label = physical.debugName;
    if (label == null) return null;
    // Letter keys
    if (label.startsWith('Key ')) return label.substring(4).toUpperCase();
    // Digit keys
    if (label.startsWith('Digit ')) return label.substring(6);
    // Named keys
    const named = <String, String>{
      'Space': 'Space',
      'Arrow Left': 'ArrowLeft',
      'Arrow Right': 'ArrowRight',
      'Arrow Up': 'ArrowUp',
      'Arrow Down': 'ArrowDown',
      'Enter': 'Enter',
      'Numpad Enter': 'Enter',
      'Tab': 'Tab',
      'Backspace': 'Backspace',
      'Delete': 'Delete',
      'Home': 'Home',
      'End': 'End',
      'Page Up': 'PageUp',
      'Page Down': 'PageDown',
      'F1': 'F1',
      'F2': 'F2',
      'F3': 'F3',
      'F4': 'F4',
      'F5': 'F5',
      'F6': 'F6',
      'F7': 'F7',
      'F8': 'F8',
      'F9': 'F9',
      'F10': 'F10',
      'F11': 'F11',
      'F12': 'F12',
    };
    return named[label];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return KeyboardListener(
      focusNode: _focus,
      onKeyEvent: (e) {
        final key = _eventToKey(e);
        if (key != null) widget.onCaptured(key);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(
                strokeWidth: 1.2,
                color: cs.onSurface.withValues(alpha: 0.40),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              'Press a key…',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.46),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onCancel,
              child: Icon(
                Icons.close_rounded,
                size: 12,
                color: cs.onSurface.withValues(alpha: 0.30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Updates pane
enum _UpdateStatus { idle, checking, upToDate, available, error }

class _UpdatesPane extends StatefulWidget {
  const _UpdatesPane();

  @override
  State<_UpdatesPane> createState() => _UpdatesPaneState();
}

class _UpdatesPaneState extends State<_UpdatesPane> {
  _UpdateStatus _status = _UpdateStatus.idle;
  String? _latestVersion;
  String? _releaseNotes;
  String? _releaseUrl;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdates());
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _status = _UpdateStatus.checking;
      _latestVersion = null;
      _releaseNotes = null;
      _releaseUrl = null;
      _errorMsg = null;
    });

    try {
      final result = await checkGithubLatest(currentVersion: kAppVersion);
      if (!mounted) return;
      switch (result.status) {
        case UpdateCheckStatus.upToDate:
          setState(() => _status = _UpdateStatus.upToDate);
        case UpdateCheckStatus.available:
          setState(() {
            _latestVersion = result.latestVersion;
            _releaseNotes = result.notes;
            _releaseUrl = result.url;
            _status = _UpdateStatus.available;
          });
        case UpdateCheckStatus.error:
          setState(() {
            _status = _UpdateStatus.error;
            _errorMsg = result.error;
          });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _UpdateStatus.error;
        _errorMsg = formatUpdateCheckError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Pane(
      page: _SettingsPage.updates,
      children: [
        _SettingsCard(
          children: [
            const _InfoRow(
              icon: Icons.tag_rounded,
              title: 'Installed version',
              value: kAppVersion,
            ),
            _Div(),
            _UpdateStatusRow(
              status: _status,
              latestVersion: _latestVersion,
              onRecheck: _checkForUpdates,
            ),
          ],
        ),
        if (_status == _UpdateStatus.available && _releaseNotes != null) ...[
          const SizedBox(height: 16),
          _ReleaseNotesCard(notes: _releaseNotes!),
        ],
        if (_status == _UpdateStatus.error && _errorMsg != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.error.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: cs.error.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _errorMsg!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.error.withValues(alpha: 0.65),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_status == _UpdateStatus.available && _releaseUrl != null) ...[
          const SizedBox(height: 14),
          _DownloadButton(version: _latestVersion!, url: _releaseUrl!),
        ],
      ],
    );
  }
}

class _UpdateStatusRow extends StatelessWidget {
  final _UpdateStatus status;
  final String? latestVersion;
  final VoidCallback onRecheck;
  const _UpdateStatusRow({
    required this.status,
    required this.latestVersion,
    required this.onRecheck,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget leading;
    String label;
    Color labelColor;

    switch (status) {
      case _UpdateStatus.idle:
        leading = Icon(
          Icons.hourglass_empty_rounded,
          size: 14,
          color: cs.onSurface.withValues(alpha: 0.22),
        );
        label = 'Not checked yet';
        labelColor = cs.onSurface.withValues(alpha: 0.36);
      case _UpdateStatus.checking:
        leading = QSpinner(
          size: 13,
          color: cs.onSurface.withValues(alpha: 0.38),
          strokeWidth: 1.5,
        );
        label = 'Checking for updates…';
        labelColor = cs.onSurface.withValues(alpha: 0.48);
      case _UpdateStatus.upToDate:
        leading = Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF50FA7B),
          ),
        );
        label = latestVersion != null
            ? 'Up to date  ·  $latestVersion is the latest'
            : "You're on the latest version";
        labelColor = cs.onSurface.withValues(alpha: 0.55);
      case _UpdateStatus.available:
        leading = Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFFB86C),
          ),
        );
        label = 'v$latestVersion is available';
        labelColor = const Color(0xFFFFB86C);
      case _UpdateStatus.error:
        leading = Icon(
          Icons.wifi_off_rounded,
          size: 14,
          color: cs.onSurface.withValues(alpha: 0.30),
        );
        label = 'Could not check for updates';
        labelColor = cs.onSurface.withValues(alpha: 0.40);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: labelColor),
            ),
          ),
          if (status != _UpdateStatus.checking)
            _HoverTextBtn(label: 'Check now', onTap: onRecheck),
        ],
      ),
    );
  }
}

class _ReleaseNotesCard extends StatelessWidget {
  final String notes;
  const _ReleaseNotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lines = notes.split('\n').where((l) => l.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(
                Icons.article_outlined,
                size: 11,
                color: cs.onSurface.withValues(alpha: 0.24),
              ),
              const SizedBox(width: 6),
              Text(
                'RELEASE NOTES',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: cs.onSurface.withValues(alpha: 0.24),
                ),
              ),
            ],
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.05)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines.map((line) {
                  final t = line.trimLeft();
                  final isBullet = t.startsWith('- ') || t.startsWith('* ');
                  final isHeading = t.startsWith('## ') || t.startsWith('# ');
                  final text = isBullet
                      ? t.substring(2)
                      : isHeading
                      ? t.replaceFirst(RegExp(r'^#+\s*'), '')
                      : t;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: isHeading ? 8 : 4,
                      top: isHeading ? 4 : 0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isBullet)
                          Padding(
                            padding: const EdgeInsets.only(top: 5, right: 8),
                            child: Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cs.onSurface.withValues(alpha: 0.30),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            text,
                            style: TextStyle(
                              fontSize: isHeading ? 12 : 11.5,
                              fontWeight: isHeading
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isHeading
                                  ? cs.onSurface.withValues(alpha: 0.72)
                                  : cs.onSurface.withValues(alpha: 0.54),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DownloadButton extends StatefulWidget {
  final String version, url;
  const _DownloadButton({required this.version, required this.url});

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          if (Platform.isWindows) {
            Process.run('cmd', ['/c', 'start', widget.url]);
          } else if (Platform.isLinux) {
            Process.run('xdg-open', [widget.url]);
          } else if (Platform.isMacOS) {
            Process.run('open', [widget.url]);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: _hovered
                ? cs.onSurface.withValues(alpha: 0.12)
                : cs.onSurface.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: cs.onSurface.withValues(alpha: 0.60),
              ),
              const SizedBox(width: 8),
              Text(
                'View release on GitHub  ·  v${widget.version}',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Integrations pane
class _IntegrationsPane extends ConsumerWidget {
  const _IntegrationsPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return _Pane(
        page: _SettingsPage.integrations,
        children: [
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Text(
                  'No integrations available on this platform.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.36),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return _Pane(
      page: _SettingsPage.integrations,
      children: [
        _SettingsCard(
          children: [
            _ToggleRow(
              icon: Icons.videogame_asset_outlined,
              title: 'Discord Rich Presence',
              subtitle:
                  'Shows the current track in your Discord status. Requires Discord to be running.',
              value: s.discordRpc,
              onChanged: (_) {
                n.toggleDiscordRpc();
                DiscordService.enabled = !s.discordRpc;
              },
            ),
            _Div(),
            _ToggleRow(
              icon: Icons.radio_button_checked_rounded,
              title: 'Scrobble to Last.fm',
              subtitle:
                  'Submit track plays to Last.fm after 50% played or 4 minutes.',
              value: s.scrobbleLastFm,
              onChanged: (_) => n.toggleScrobble(),
            ),
            if (s.scrobbleLastFm) ...[_Div(), const LastFmAuthRow()],
            _Div(),
            _ToggleRow(
              icon: Icons.library_music_outlined,
              title: 'Scrobble to ListenBrainz',
              subtitle:
                  'Same threshold as Last.fm. You can enable both at once.',
              value: s.scrobbleListenBrainz,
              onChanged: (_) => n.toggleScrobbleListenBrainz(),
            ),
            if (s.scrobbleListenBrainz) ...[
              _Div(),
              const ListenBrainzAuthRow(),
            ],
            if (s.scrobbleReady || s.listenBrainzReady) ...[
              _Div(),
              const _SyncLovedRow(),
            ],
          ],
        ),
      ],
    );
  }
}

class _SyncLovedRow extends ConsumerStatefulWidget {
  const _SyncLovedRow();

  @override
  ConsumerState<_SyncLovedRow> createState() => _SyncLovedRowState();
}

class _SyncLovedRowState extends ConsumerState<_SyncLovedRow> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await LovedSync.importInto(ref);
    if (!mounted) return;
    setState(() => _busy = false);
    final msg = result.remoteCount == 0
        ? 'No loved tracks found on Last.fm or ListenBrainz.'
        : 'Loved ${result.imported} library tracks from ${result.remoteCount} remote likes.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (context.isMaterial3Ui) {
      return ListTile(
        leading: const Icon(Icons.favorite_outline_rounded),
        title: const Text('Sync loved tracks'),
        subtitle: const Text(
          'Mark local files as loved when they match likes on Last.fm or ListenBrainz.',
        ),
        trailing: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(onPressed: _run, child: const Text('Sync')),
        onTap: _busy ? null : _run,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.favorite_outline_rounded,
              size: 16,
              color: context.stOnSurface(0.34),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync loved tracks',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.stOnSurface(0.80),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Mark local files as loved when they match likes on Last.fm or ListenBrainz.',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.stMuted(),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (_busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          else
            _HoverTextBtn(label: 'Sync', onTap: _run),
        ],
      ),
    );
  }
}

// About pane
class _AboutPane extends ConsumerWidget {
  final VoidCallback onOpenSupport;
  const _AboutPane({required this.onOpenSupport});

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final result = await SettingsBackupService.export(
      settings: ref.read(settingsProvider),
      playlists: ref.read(playlistProvider),
      folders: ref.read(libraryProvider).folders,
    );
    if (!context.mounted) return;
    if (result.success) {
      _snack(context, kBackupSavedMessage);
    } else if (result.error != null) {
      _snack(context, result.error!);
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final picked = await SettingsBackupService.import();
    if (!context.mounted) return;
    if (!picked.success) {
      if (picked.error != null) _snack(context, picked.error!);
      return;
    }
    final payload = picked.payload;
    if (payload == null) return;
    final confirmed = await showUiDialog<bool>(
      context: context,
      title: 'Restore backup?',
      content: const Text('This replaces your current settings and playlists.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Restore'),
        ),
      ],
    );
    if (confirmed != true || !context.mounted) return;
    final settings = settingsFromJson(
      payload.settings,
      defaultOutputMode: platformDefaultOutputMode(),
    );
    await ref.read(settingsProvider.notifier).applyBackup(settings);
    await ref.read(playlistProvider.notifier).replaceAll(payload.playlists);
    await ref.read(libraryProvider.notifier).restoreFolders(payload.folders);
    if (context.mounted) _snack(context, kBackupRestoredMessage);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    Icons.favorite_border_rounded,
                    size: 15,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Support the project',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.42),
                      ),
                    ),
                  ),
                  _HoverTextBtn(label: 'Open', onTap: onOpenSupport),
                ],
              ),
            ),
            _Div(),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Icon(
                    Icons.backup_rounded,
                    size: 15,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Backup',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.42),
                      ),
                    ),
                  ),
                  _HoverTextBtn(
                    label: 'Export',
                    onTap: () => _export(context, ref),
                  ),
                  const SizedBox(width: 8),
                  _HoverTextBtn(
                    label: 'Restore',
                    onTap: () => _restore(context, ref),
                  ),
                ],
              ),
            ),
            _Div(),
            _InfoRow(
              icon: Icons.music_note_rounded,
              title: 'Aqloss',
              value: 'Version $kAppVersion',
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

class _SupportPane extends StatelessWidget {
  const _SupportPane();

  @override
  Widget build(BuildContext context) {
    final locale = View.of(context).platformDispatcher.locale;
    final groups = supportGroups(
      indonesiaFirst: preferIndonesianSupport(locale),
    );

    return _Pane(
      page: _SettingsPage.support,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Aqloss is free software. If you want to help keep development going, pick a platform below.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: context.stOnSurface(0.42),
            ),
          ),
        ),
        for (int i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _SupportGroupCard(group: groups[i]),
        ],
      ],
    );
  }
}

class _SupportGroupCard extends StatelessWidget {
  final SupportGroup group;
  const _SupportGroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final primary = group.links.firstWhere((l) => l.primary);
    final rest = group.links.where((l) => !l.primary).toList();

    return _SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.stOnSurface(0.78),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                group.subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: context.stOnSurface(0.34),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _SupportPrimaryBtn(link: primary),
          ),
        ),
        if (rest.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final link in rest)
                  _HoverTextBtn(
                    label: link.name,
                    onTap: () => openExternalUrl(link.url),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SupportPrimaryBtn extends StatefulWidget {
  final SupportLink link;
  const _SupportPrimaryBtn({required this.link});

  @override
  State<_SupportPrimaryBtn> createState() => _SupportPrimaryBtnState();
}

class _SupportPrimaryBtnState extends State<_SupportPrimaryBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => openExternalUrl(widget.link.url),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _hovered
                ? context.stOnSurface(0.12)
                : context.stOnSurface(0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.stOnSurface(0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.open_in_new_rounded,
                size: 13,
                color: context.stOnSurface(0.60),
              ),
              const SizedBox(width: 8),
              Text(
                widget.link.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.stOnSurface(0.78),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _SettingsTheme on BuildContext {
  Color stOnSurface([double alpha = 1.0]) => isMaterial3Ui
      ? Theme.of(this).colorScheme.onSurface.withValues(alpha: alpha)
      : aq.onSurface.withValues(alpha: alpha);

  Color stSurface([double alpha = 1.0]) => isMaterial3Ui
      ? Theme.of(this).colorScheme.surface.withValues(alpha: alpha)
      : aq.surface.withValues(alpha: alpha);

  Color stMuted() => isMaterial3Ui
      ? Theme.of(this).colorScheme.onSurfaceVariant
      : aq.onSurfaceMuted;

  Color stBorder() =>
      isMaterial3Ui ? Theme.of(this).colorScheme.outlineVariant : aq.border;
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    if (context.isMaterial3Ui) {
      return Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
    }

    final aq = context.aq;
    return Container(
      decoration: BoxDecoration(
        color: aq.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: aq.border),
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
  Widget build(BuildContext context) =>
      const UiDivider(margin: EdgeInsets.symmetric(horizontal: 14));
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
                ? context.stOnSurface(0.07)
                : context.stOnSurface(0.04),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(widget.icon, size: 13, color: context.stOnSurface(0.36)),
        ),
      ),
    );
  }
}

// Row types
class _ExclusiveLockBanner extends StatelessWidget {
  final String text;
  const _ExclusiveLockBanner(this.text);

  @override
  Widget build(BuildContext context) {
    if (context.isMaterial3Ui) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: context.stOnSurface(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.stBorder()),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 14,
              color: context.stOnSurface(0.45),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: context.stOnSurface(0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnavailableNote extends StatelessWidget {
  final String text;
  const _UnavailableNote(this.text);

  @override
  Widget build(BuildContext context) {
    if (context.isMaterial3Ui) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          height: 1.35,
          color: context.stOnSurface(0.50),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatefulWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool disabled;
  final String? disabledHint;
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.disabled = false,
    this.disabledHint,
  });

  @override
  State<_ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends State<_ToggleRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (context.isMaterial3Ui) {
      return SwitchListTile(
        secondary: Icon(widget.icon),
        title: Text(widget.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.subtitle),
            if (widget.disabled && widget.disabledHint != null)
              _UnavailableNote(widget.disabledHint!),
          ],
        ),
        value: widget.value,
        onChanged: widget.disabled ? null : widget.onChanged,
      );
    }

    final fade = widget.disabled ? 0.42 : 1.0;
    return MouseRegion(
      cursor: widget.disabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.disabled ? null : () => widget.onChanged(!widget.value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          color: _hovered && !widget.disabled
              ? context.stOnSurface(0.025)
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
                    color: context.stOnSurface(0.34 * fade),
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
                          color: context.stOnSurface(0.80 * fade),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.disabled
                              ? context.stOnSurface(0.32)
                              : context.stMuted(),
                          height: 1.4,
                        ),
                      ),
                      if (widget.disabled && widget.disabledHint != null)
                        _UnavailableNote(widget.disabledHint!),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: IgnorePointer(
                    ignoring: widget.disabled,
                    child: _MiniSwitch(
                      value: widget.value,
                      onChanged: widget.disabled ? null : widget.onChanged,
                    ),
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
    if (context.isMaterial3Ui) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon),
              title: Text(title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subtitle),
                  if (disabled && disabledHint != null)
                    _UnavailableNote(disabledHint!),
                ],
              ),
            ),
            IgnorePointer(
              ignoring: disabled,
              child: SegmentedButton<int>(
                segments: [
                  for (var i = 0; i < options.length; i++)
                    ButtonSegment<int>(
                      value: i,
                      label: Text(options[i]),
                      enabled: !disabled,
                    ),
                ],
                selected: {selected},
                showSelectedIcon: false,
                onSelectionChanged: disabled
                    ? null
                    : (selection) => onChanged(selection.first),
              ),
            ),
          ],
        ),
      );
    }

    final narrow = MediaQuery.of(context).size.width < 500;
    final fade = disabled ? 0.42 : 1.0;

    Widget picker = IgnorePointer(
      ignoring: disabled,
      child: _SegmentedPicker(
        options: options,
        selected: selected,
        onChanged: onChanged,
        disabled: disabled,
      ),
    );

    return Padding(
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
                  color: context.stOnSurface(0.34 * fade),
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
                        color: context.stOnSurface(0.80 * fade),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: disabled
                            ? context.stOnSurface(0.32)
                            : context.stMuted(),
                        height: 1.4,
                      ),
                    ),
                    if (disabled && disabledHint != null)
                      _UnavailableNote(disabledHint!),
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
  final ValueChanged<double>? onChangeEnd;
  final bool disabled;
  final String? disabledHint;

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
    this.disabled = false,
    this.disabledHint,
  }) : onChangeEnd = null;

  @override
  Widget build(BuildContext context) {
    if (context.isMaterial3Ui) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon),
              title: Text(title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subtitle),
                  if (disabled && disabledHint != null)
                    _UnavailableNote(disabledHint!),
                ],
              ),
              trailing: Text(
                label(value),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: label(value),
              onChanged: disabled ? null : onChanged,
            ),
          ],
        ),
      );
    }

    final fade = disabled ? 0.42 : 1.0;
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
                  color: context.stOnSurface(0.34 * fade),
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
                            color: context.stOnSurface(0.80 * fade),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          label(value),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: context.stOnSurface(0.58 * fade),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: disabled
                            ? context.stOnSurface(0.32)
                            : context.stMuted(),
                        height: 1.4,
                      ),
                    ),
                    if (disabled && disabledHint != null)
                      _UnavailableNote(disabledHint!),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: IgnorePointer(
              ignoring: disabled,
              child: _RangeSlider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: disabled ? null : onChanged,
                onChangeEnd: disabled ? null : onChangeEnd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveSliderRow extends StatefulWidget {
  final IconData icon;
  final String title, subtitle;
  final double value, min, max;
  final int divisions;
  final String Function(double) label;
  final ValueChanged<double> onCommit;
  final bool disabled;
  final String? disabledHint;

  const _LiveSliderRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onCommit,
    this.disabled = false,
    this.disabledHint,
  });

  @override
  State<_LiveSliderRow> createState() => _LiveSliderRowState();
}

class _LiveSliderRowState extends State<_LiveSliderRow> {
  double? _dragValue;

  double get _display => _dragValue ?? widget.value;

  void _onDrag(double normalised) {
    final raw = widget.min + normalised * (widget.max - widget.min);
    setState(() => _dragValue = raw.clamp(widget.min, widget.max));
  }

  void _onCommit(double normalised) {
    final range = widget.max - widget.min;
    final step = range / widget.divisions;
    final raw = widget.min + normalised * range;
    final snapped = (raw / step).round() * step;
    final v = snapped.clamp(widget.min, widget.max);
    setState(() => _dragValue = null);
    widget.onCommit(v);
  }

  @override
  void didUpdateWidget(_LiveSliderRow old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _dragValue = null;
  }

  @override
  Widget build(BuildContext context) {
    if (context.isMaterial3Ui) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(widget.icon),
              title: Text(widget.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.subtitle),
                  if (widget.disabled && widget.disabledHint != null)
                    _UnavailableNote(widget.disabledHint!),
                ],
              ),
              trailing: Text(
                widget.label(_display),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Slider(
              value: _display.clamp(widget.min, widget.max),
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              label: widget.label(_display),
              onChanged: widget.disabled
                  ? null
                  : (v) => _onDrag(
                      ((v - widget.min) / (widget.max - widget.min)).clamp(
                        0.0,
                        1.0,
                      ),
                    ),
              onChangeEnd: widget.disabled
                  ? null
                  : (v) => _onCommit(
                      ((v - widget.min) / (widget.max - widget.min)).clamp(
                        0.0,
                        1.0,
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    final normalised = ((_display - widget.min) / (widget.max - widget.min))
        .clamp(0.0, 1.0);
    final fade = widget.disabled ? 0.42 : 1.0;

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
                  widget.icon,
                  size: 16,
                  color: context.stOnSurface(0.34 * fade),
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
                          widget.title,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.stOnSurface(0.80 * fade),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          widget.label(_display),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: context.stOnSurface(0.58 * fade),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.disabled
                            ? context.stOnSurface(0.32)
                            : context.stMuted(),
                        height: 1.4,
                      ),
                    ),
                    if (widget.disabled && widget.disabledHint != null)
                      _UnavailableNote(widget.disabledHint!),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: IgnorePointer(
              ignoring: widget.disabled,
              child: CustomSlider(
                value: normalised,
                trackHeight: 2,
                thumbRadius: 6,
                activeColor: context.stOnSurface(0.58 * fade),
                inactiveColor: context.stOnSurface(0.10),
                thumbColor: context.stOnSurface(0.80 * fade),
                onChanged: widget.disabled ? null : _onDrag,
                onChangeEnd: widget.disabled ? null : _onCommit,
              ),
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
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  const _RangeSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    this.onChanged,
    this.onChangeEnd,
  });
  @override
  State<_RangeSlider> createState() => _RangeSliderState();
}

class _RangeSliderState extends State<_RangeSlider> {
  double? _localValue;

  double get _displayValue => _localValue ?? widget.value;

  void _onDragChanged(double normalised) {
    final range = widget.max - widget.min;
    final raw = widget.min + normalised * range;
    setState(() => _localValue = raw.clamp(widget.min, widget.max));
  }

  void _onDragEnd(double normalised) {
    final range = widget.max - widget.min;
    final step = range / widget.divisions;
    final raw = widget.min + normalised * range;
    final snapped = (raw / step).round() * step;
    final v = snapped.clamp(widget.min, widget.max);
    setState(() => _localValue = null);
    if (widget.onChangeEnd != null) {
      widget.onChangeEnd!(v);
    } else {
      widget.onChanged?.call(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalised =
        ((_displayValue - widget.min) / (widget.max - widget.min)).clamp(
          0.0,
          1.0,
        );
    return CustomSlider(
      value: normalised,
      trackHeight: 2,
      thumbRadius: 6,
      activeColor: context.stOnSurface(0.58),
      inactiveColor: context.stOnSurface(0.10),
      thumbColor: context.stOnSurface(0.80),
      onChanged: widget.onChanged == null ? null : _onDragChanged,
      onChangeEnd: widget.onChanged == null ? null : _onDragEnd,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 15, color: context.stOnSurface(0.22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 13, color: context.stOnSurface(0.42)),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, color: context.stOnSurface(0.26)),
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
  final bool disabled;
  const _SegmentedPicker({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.stOnSurface(0.04),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: context.stBorder()),
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
              color: isSel ? context.stOnSurface(0.13) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              e.value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                color: isSel
                    ? context.stOnSurface(disabled ? 0.40 : 1.0)
                    : context.stOnSurface(disabled ? 0.22 : 0.34),
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
  final ValueChanged<bool>? onChanged;
  const _MiniSwitch({required this.value, this.onChanged});
  @override
  Widget build(BuildContext context) {
    if (context.isMaterial3Ui) {
      return Switch(value: value, onChanged: onChanged);
    }

    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 34,
        height: 19,
        decoration: BoxDecoration(
          color: value
              ? context.stOnSurface(onChanged == null ? 0.28 : 0.85)
              : context.stOnSurface(onChanged == null ? 0.06 : 0.10),
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
                color: value ? context.stSurface() : context.stOnSurface(0.34),
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
            color: _hovered ? context.stOnSurface(0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: context.stBorder()),
          ),
          child: Text(
            widget.label,
            style: TextStyle(fontSize: 11, color: context.stOnSurface(0.60)),
          ),
        ),
      ),
    );
  }
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
                ? context.stOnSurface(0.05)
                : context.stOnSurface(0.02),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.stBorder()),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isScanning)
                QSpinner(
                  size: 11,
                  color: context.stOnSurface(0.36),
                  strokeWidth: 1.5,
                )
              else
                Icon(
                  Icons.refresh_rounded,
                  size: 12,
                  color: context.stOnSurface(0.36),
                ),
              const SizedBox(width: 7),
              Text(
                widget.isScanning ? 'Switching…' : 'Rescan devices',
                style: TextStyle(
                  fontSize: 12,
                  color: context.stOnSurface(0.48),
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
