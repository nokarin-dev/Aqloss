import 'dart:io';

import 'package:aqloss/app_channel.dart';
import 'package:aqloss/app_version.dart';
import 'package:aqloss/l10n/l10n.dart';
import 'package:aqloss/plugins/plugin_api.dart';
import 'package:aqloss/plugins/plugin_io_service.dart';
import 'package:aqloss/providers/plugin_provider.dart';
import 'package:aqloss/providers/audio_device_provider.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/services/audio_service.dart';
import 'package:aqloss/services/discord_service.dart';
import 'package:aqloss/services/folder_picker.dart';
import 'package:aqloss/services/ios_folder_access.dart';
import 'package:aqloss/services/lastfm_service.dart';
import 'package:aqloss/services/listenbrainz_service.dart';
import 'package:aqloss/services/loved_sync.dart';
import 'package:aqloss/services/settings_backup_service.dart';
import 'package:aqloss/ui/shell/tokens.dart';
import 'package:aqloss/util/eq_presets.dart';
import 'package:aqloss/util/logger.dart';
import 'package:aqloss/util/notices.dart';
import 'package:aqloss/util/open_url.dart';
import 'package:aqloss/util/playback_speed.dart';
import 'package:aqloss/util/settings_backup.dart';
import 'package:aqloss/util/shortcut_keys.dart';
import 'package:aqloss/util/support_links.dart';
import 'package:aqloss/util/update_check.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:open_file/open_file.dart';

part 'settings_panes.dart';

enum SettingsPane {
  folders,
  output,
  playback,
  dsp,
  display,
  integrations,
  shortcuts,
  plugins,
  updates,
  support,
  about,
}

class SettingsItem {
  final SettingsPane pane;
  final IconData icon;

  const SettingsItem(this.pane, this.icon);
}

class SettingsGroup {
  final String label;
  final List<SettingsItem> items;

  const SettingsGroup(this.label, this.items);
}

const settingsGroups = <SettingsGroup>[
  SettingsGroup('sidebar.library', [
    SettingsItem(SettingsPane.folders, CupertinoIcons.folder_fill),
  ]),
  SettingsGroup('settings.playback', [
    SettingsItem(SettingsPane.output, CupertinoIcons.speaker_2_fill),
    SettingsItem(SettingsPane.playback, CupertinoIcons.play_circle_fill),
    SettingsItem(SettingsPane.dsp, CupertinoIcons.slider_horizontal_3),
  ]),
  SettingsGroup('settings.appearance', [
    SettingsItem(SettingsPane.display, CupertinoIcons.paintbrush_fill),
  ]),
  SettingsGroup('settings.app', [
    SettingsItem(SettingsPane.integrations, CupertinoIcons.link),
    SettingsItem(SettingsPane.shortcuts, CupertinoIcons.keyboard),
    SettingsItem(SettingsPane.plugins, CupertinoIcons.square_grid_2x2),
    SettingsItem(SettingsPane.updates, CupertinoIcons.arrow_down_circle_fill),
    SettingsItem(SettingsPane.support, CupertinoIcons.heart_fill),
    SettingsItem(SettingsPane.about, CupertinoIcons.info_circle_fill),
  ]),
];

class PhoneSettingsPage extends StatefulWidget {
  const PhoneSettingsPage({super.key});

  @override
  State<PhoneSettingsPage> createState() => _PhoneSettingsPageState();
}

class _PhoneSettingsPageState extends State<PhoneSettingsPage> {
  SettingsPane? _pane;

  @override
  Widget build(BuildContext context) {
    final pane = _pane;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: pane == null
          ? _settingsScroll([
              Text(tr('settings.tune'), style: _pageTitle),
              const SizedBox(height: 8),
              for (final group in settingsGroups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text(
                    tr(group.label),
                    style: const TextStyle(color: textMuted, fontSize: 12),
                  ),
                ),
                _Rows(
                  children: [
                    for (final item in group.items)
                      _PaneLink(
                        icon: item.icon,
                        label: settingsPaneTitle(item.pane),
                        onTap: () => setState(() => _pane = item.pane),
                      ),
                  ],
                ),
              ],
            ])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _pane = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                      icon: const Icon(CupertinoIcons.chevron_left, size: 18),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        settingsPaneTitle(pane),
                        style: _pageTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(child: settingsPaneBody(pane)),
              ],
            ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final SettingsPane pane;

  const SettingsPage({super.key, required this.pane});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 50 : 20, wide ? 36 : 24, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _settingsWidth),
            child: Text(settingsPaneTitle(pane), style: _pageTitle),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Crossfade(
              child: KeyedSubtree(
                key: ValueKey(pane),
                child: settingsPaneBody(pane),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget settingsPaneBody(SettingsPane pane) {
  return switch (pane) {
    SettingsPane.folders => const _Folders(),
    SettingsPane.output => const _OutputPane(),
    SettingsPane.playback => const _Playback(),
    SettingsPane.dsp => const _DspPane(),
    SettingsPane.display => const _DisplayPane(),
    SettingsPane.integrations => const _IntegrationsPane(),
    SettingsPane.shortcuts => const _ShortcutsPane(),
    SettingsPane.plugins => const _PluginsPane(),
    SettingsPane.updates => const _UpdatesPane(),
    SettingsPane.support => const _SupportPane(),
    SettingsPane.about => const _AboutPane(),
  };
}

class _Folders extends ConsumerWidget {
  const _Folders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final folders = library.folders;
    final scanning = library.status == LibraryStatus.scanning;
    return _settingsScroll([
      Text(
        '${tr('folders.indexed')}  ${library.tracks.length}',
        style: const TextStyle(color: textMuted, fontSize: 13),
      ),
      const SizedBox(height: 12),
      if (folders.isEmpty)
        _Rows(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Text(
                tr('folders.empty_sentence'),
                style: const TextStyle(color: textMuted, fontSize: 14),
              ),
            ),
          ],
        )
      else
        _Rows(
          children: [
            for (final folder in folders)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _folderName(folder),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            folder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _OutlineButton(
                      label: tr('playlists.remove'),
                      onPressed: () {
                        ref.read(libraryProvider.notifier).removeFolder(folder);
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _OutlineButton(
            label: tr('folders.add_short'),
            onPressed: () {
              addMusicFolderFromPicker(
                context,
                onAdded: ref.read(libraryProvider.notifier).addFolder,
              );
            },
          ),
          _OutlineButton(
            label: tr('folders.rescan'),
            onPressed: scanning
                ? null
                : () => ref.read(libraryProvider.notifier).rescanAll(),
          ),
        ],
      ),
    ]);
  }
}

class _Playback extends ConsumerWidget {
  const _Playback();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final locked = ref.watch(exclusiveModeProvider);
    final fadeLocked = locked || settings.gaplessPlayback;
    return _settingsScroll([
      if (locked) ...[
        Text(
          tr('playback.exclusive'),
          style: const TextStyle(color: textMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
      ],
      _Rows(
        children: [
          _SwitchRow(
            label: tr('playback.gapless'),
            value: settings.gaplessPlayback,
            onChanged: (_) => notifier.toggleGapless(),
          ),
          _ValueRow(
            label: tr('playback.crossfade'),
            value: _crossfadeLabel(settings.crossfade),
            enabled: !fadeLocked,
            tooltip: locked
                ? tr('playback.exclusive')
                : tr('playback.gapless_locked'),
            onTap: () => notifier.setCrossfade(
              _next(CrossfadeMode.values, settings.crossfade),
            ),
          ),
          _ValueRow(
            label: tr('playback.replaygain'),
            value: _gainLabel(settings.replayGainMode),
            enabled: !locked,
            tooltip: tr('playback.exclusive'),
            onTap: () {
              notifier.setReplayGainMode(
                _next(ReplayGainMode.values, settings.replayGainMode),
              );
            },
          ),
          if (settings.replayGainEnabled)
            _LiveSlider(
              label: tr('playback.preamp'),
              value: settings.replayGainPreamp,
              min: -12,
              max: 12,
              divisions: 24,
              enabled: !locked,
              labelFor: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)} dB',
              onCommit: notifier.setReplayGainPreamp,
            ),
          _SwitchRow(
            label: tr('playback.skip_silence'),
            value: settings.skipSilence,
            enabled: !locked,
            onChanged: (_) => notifier.toggleSkipSilence(),
          ),
          _ValueRow(
            label: tr('playback.speed'),
            value: playbackSpeedLabel(settings.playbackSpeed),
            enabled: !locked,
            tooltip: tr('playback.exclusive'),
            onTap: () {
              final speeds = kPlaybackSpeeds;
              final index = playbackSpeedIndex(settings.playbackSpeed);
              notifier.setPlaybackSpeed(speeds[(index + 1) % speeds.length]);
            },
          ),
          _ValueRow(
            label: tr('playback.stop_after'),
            value: _stopLabel(settings.stopAfter),
            onTap: () => notifier.setStopAfter(
              _next(StopAfterMode.values, settings.stopAfter),
            ),
          ),
        ],
      ),
    ]);
  }
}

class _Rows extends StatelessWidget {
  final List<Widget> children;

  const _Rows({required this.children});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2D2D)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: Color(0xFF2D2D2D)),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _PaneLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PaneLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(child: _RowCopy(label: label)),
          _ShellSwitch(value: value, enabled: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _RowCopy extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool enabled;

  const _RowCopy({required this.label, this.subtitle, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.white : textMuted,
            fontSize: 15,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: const TextStyle(color: textMuted, fontSize: 12, height: 1.3),
          ),
        ],
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final String value;
  final VoidCallback onTap;
  final bool enabled;
  final String? tooltip;

  const _ValueRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(
      value,
      style: const TextStyle(color: textMuted, fontSize: 14),
    );
    final hit = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: text,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: _RowCopy(label: label, subtitle: subtitle, enabled: enabled),
          ),
          if (!enabled && tooltip != null)
            Tooltip(message: tooltip!, child: hit)
          else
            hit,
        ],
      ),
    );
  }
}

class _LiveSlider extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final bool enabled;
  final String Function(double value) labelFor;
  final ValueChanged<double> onCommit;

  const _LiveSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.labelFor,
    required this.onCommit,
    this.divisions,
    this.enabled = true,
  });

  @override
  State<_LiveSlider> createState() => _LiveSliderState();
}

class _LiveSliderState extends State<_LiveSlider> {
  double? _drag;

  double _step(double value) {
    final divisions = widget.divisions;
    final clamped = value.clamp(widget.min, widget.max);
    if (divisions == null || divisions <= 0) return clamped;
    final step = (widget.max - widget.min) / divisions;
    final index = ((clamped - widget.min) / step).round();
    return (widget.min + index * step).clamp(widget.min, widget.max);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _drag ?? widget.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _RowCopy(label: widget.label, enabled: widget.enabled),
              ),
              Text(
                widget.labelFor(shown),
                style: TextStyle(
                  color: widget.enabled ? Colors.white : textMuted,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              if (width < 48) return const SizedBox.shrink();
              return IgnorePointer(
                ignoring: !widget.enabled,
                child: LiquidGlassSlider(
                  value: _step(shown),
                  minimumValue: widget.min,
                  maximumValue: widget.max,
                  width: width,
                  activeColor: Colors.white,
                  inactiveColor: const Color(0x2EFFFFFF),
                  thumbColor: Colors.white,
                  motion: const LiquidGlassLensMotionSpec(maxDeformation: 0),
                  layout: const LiquidGlassSliderLayout(
                    trackHeight: 3,
                    thumbWidth: 22,
                    thumbHeight: 14,
                    liftedThumbWidth: 34,
                    liftedThumbHeight: 22,
                  ),
                  onChanged: (value) => setState(() => _drag = _step(value)),
                  onChangeEnd: (value) {
                    final next = _step(value);
                    setState(() => _drag = null);
                    widget.onCommit(next);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _OutlineButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: LiquidGlassButton(
        label: label,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        fontSize: 14,
        fontWeight: FontWeight.w500,
        foregroundColor: enabled ? Colors.white : textMuted,
        onPressed: onPressed,
      ),
    );
  }
}

class _ShellSwitch extends StatefulWidget {
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ShellSwitch({
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<_ShellSwitch> createState() => _ShellSwitchState();
}

class _ShellSwitchState extends State<_ShellSwitch> {
  bool _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter && key != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    widget.onChanged(!widget.value);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.value;
    final duration = motionOf(context);
    return Semantics(
      button: true,
      toggled: on,
      enabled: widget.enabled,
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: widget.enabled ? () => widget.onChanged(!on) : null,
          behavior: HitTestBehavior.opaque,
          child: Focus(
            canRequestFocus: widget.enabled,
            onFocusChange: (focused) => setState(() => _focused = focused),
            onKeyEvent: _onKey,
            child: Opacity(
              opacity: widget.enabled ? 1 : 0.4,
              child: SizedBox(
                width: 63,
                height: 44,
                child: Center(
                  child: AnimatedContainer(
                    duration: duration,
                    curve: motionCurve,
                    width: 63,
                    height: 28,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: on ? Colors.white : const Color(0xFF3A3A3C),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _focused
                            ? (on ? const Color(0xFF1C1C1E) : Colors.white)
                            : const Color(0x00000000),
                      ),
                    ),
                    child: AnimatedAlign(
                      duration: duration,
                      curve: motionCurve,
                      alignment: on
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: duration,
                        curve: motionCurve,
                        width: 37,
                        height: 24,
                        decoration: BoxDecoration(
                          color: on ? const Color(0xFF1C1C1E) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _settingsWidth = 680.0;

const _pageTitle = TextStyle(
  color: Colors.white,
  fontSize: 28,
  height: 36 / 28,
  fontWeight: FontWeight.w600,
);

String settingsPaneTitle(SettingsPane pane) => switch (pane) {
  SettingsPane.folders => tr('settings.folders'),
  SettingsPane.output => tr('settings.output'),
  SettingsPane.playback => tr('settings.playback'),
  SettingsPane.dsp => tr('settings.dsp'),
  SettingsPane.display => tr('settings.display'),
  SettingsPane.integrations => tr('settings.integrations'),
  SettingsPane.shortcuts => tr('settings.shortcuts'),
  SettingsPane.plugins => tr('settings.plugins'),
  SettingsPane.updates => tr('settings.updates'),
  SettingsPane.support => tr('settings.support'),
  SettingsPane.about => tr('settings.about'),
};

String _folderName(String folder) {
  final parts = folder.split(Platform.pathSeparator);
  final name = parts.isEmpty ? folder : parts.last;
  return name.isEmpty ? folder : name;
}

T _next<T>(List<T> values, T current) {
  final index = values.indexOf(current);
  return values[(index + 1) % values.length];
}

String _crossfadeLabel(CrossfadeMode mode) => switch (mode) {
  CrossfadeMode.off => tr('playback.off'),
  CrossfadeMode.short => tr('playback.s2'),
  CrossfadeMode.medium => tr('playback.s4'),
  CrossfadeMode.long => tr('playback.s8'),
};

String _gainLabel(ReplayGainMode mode) => switch (mode) {
  ReplayGainMode.off => tr('playback.off'),
  ReplayGainMode.track => tr('library.track'),
  ReplayGainMode.album => tr('library.album'),
  ReplayGainMode.auto => tr('playback.auto'),
};

String _stopLabel(StopAfterMode mode) => switch (mode) {
  StopAfterMode.off => tr('playback.off'),
  StopAfterMode.track => tr('library.track'),
  StopAfterMode.album => tr('library.album'),
};
