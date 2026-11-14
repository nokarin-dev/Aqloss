import 'dart:io' show Platform;
import 'dart:ui';

import 'package:aqloss/l10n/l10n.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/services/metadata_service.dart';
import 'package:aqloss/ui/shell/artists_page.dart';
import 'package:aqloss/ui/shell/history_page.dart';
import 'package:aqloss/ui/shell/glyphs.dart';
import 'package:aqloss/ui/shell/tokens.dart';
import 'package:aqloss/ui/shell/home_page.dart';
import 'package:aqloss/ui/shell/playlists_page.dart';
import 'package:aqloss/ui/shell/queue_overlay.dart';
import 'package:aqloss/ui/shell/settings_page.dart';
import 'package:aqloss/ui/shell/window_buttons.dart';
import 'package:aqloss/ui/shell/album_art.dart';
import 'package:aqloss/ui/shell/glass.dart';
import 'package:aqloss/ui/shell/sleep_sheet.dart';
import 'package:aqloss/util/ab_loop.dart';
import 'package:aqloss/util/search_focus_tracker.dart';
import 'package:aqloss/util/sleep_timer.dart';
import 'package:aqloss/util/shortcut_keys.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

const _green = playGreen;
const _muted = textMuted;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  NavDest _dest = NavDest.home;
  NavDest _returnDest = NavDest.home;
  SettingsPane _settingsPane = SettingsPane.folders;
  HomeBrowse _browse = HomeBrowse.nowPlaying;
  bool _queueOpen = false;
  late final AnimationController _nav = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );
  Uint8List? _art;
  String? _artPath;
  bool? _seenGlow;
  final _capture = LiquidGlassViewController();

  bool get _phone => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _loadArt(ref.read(playerProvider).currentTrack?.path);
    _captureSoon();
  }

  void _captureSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _capture.captureOnce();
    });
    Future<void>.delayed(motionDuration, () {
      if (mounted) _capture.captureOnce();
    });
  }

  void _captureGround(bool glow) {
    if (_seenGlow == glow) return;
    _seenGlow = glow;
    _captureSoon();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _nav.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    if (SearchFocusTracker.instance.hasFocus || shortcutCapture) return false;
    if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) {
      return false;
    }
    final pressed = shortcutChord(event);
    if (pressed == null) return false;
    final settings = ref.read(settingsProvider);
    ShortcutAction? action;
    for (final candidate in ShortcutAction.values) {
      if (settings.binding(candidate) == pressed) {
        action = candidate;
        break;
      }
    }
    if (action == null) return false;
    switch (action) {
      case ShortcutAction.playPause:
        final player = ref.read(playerProvider);
        if (player.currentTrack == null) return false;
        final notifier = ref.read(playerProvider.notifier);
        if (player.status == PlayerStatus.playing) {
          notifier.pause();
        } else {
          notifier.play();
        }
      case ShortcutAction.skipNext:
        ref.read(playerProvider.notifier).skipNext();
      case ShortcutAction.skipPrevious:
        ref.read(playerProvider.notifier).skipPrevious();
      case ShortcutAction.volumeUp:
        final vol = (ref.read(playerProvider).volume + 0.05)
            .clamp(0.0, 1.0)
            .toDouble();
        ref.read(playerProvider.notifier).setVolume(vol);
      case ShortcutAction.volumeDown:
        final vol = (ref.read(playerProvider).volume - 0.05)
            .clamp(0.0, 1.0)
            .toDouble();
        ref.read(playerProvider.notifier).setVolume(vol);
      case ShortcutAction.toggleSidebar:
        if (_phone) return false;
        _toggleNav();
      case ShortcutAction.toggleQueue:
        setState(() => _queueOpen = !_queueOpen);
      case ShortcutAction.navPlayer:
        _show(NavDest.home, HomeBrowse.nowPlaying);
      case ShortcutAction.navLibrary:
        _show(NavDest.home, HomeBrowse.library);
      case ShortcutAction.navAlbums:
        _show(NavDest.home, HomeBrowse.albums);
      case ShortcutAction.navArtists:
        _show(NavDest.artists);
      case ShortcutAction.navHistory:
        _show(NavDest.history);
      case ShortcutAction.navSettings:
        _show(NavDest.settings);
      case ShortcutAction.newPlaylist:
        _newPlaylist();
    }
    return true;
  }

  void _show(NavDest dest, [HomeBrowse? browse]) {
    setState(() {
      _dest = dest;
      if (browse != null) _browse = browse;
    });
  }

  void _newPlaylist() {
    setState(() => _dest = NavDest.playlists);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(playlistCreateTickProvider.notifier).update((n) => n + 1);
    });
  }

  void _toggleNav() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _nav.value = _nav.value < 0.5 ? 1 : 0;
      return;
    }
    final closing =
        _nav.status == AnimationStatus.forward ||
        (_nav.status == AnimationStatus.completed && _nav.value == 1);
    if (closing) {
      _nav.reverse();
    } else {
      _nav.forward();
    }
  }

  // Keep the cover bytes for the Now Playing glow
  Future<void> _loadArt(String? path) async {
    if (path == _artPath) return;
    _artPath = path;
    if (path == null) {
      if (_art != null && mounted) setState(() => _art = null);
      _art = null;
      _captureSoon();
      return;
    }
    try {
      final bytes = await backend.readAlbumArt(path: path);
      if (!mounted || _artPath != path) return;
      setState(() {
        _art = bytes == null ? null : Uint8List.fromList(bytes);
      });
      _captureSoon();
    } catch (_) {
      if (mounted && _artPath == path) {
        setState(() => _art = null);
        _captureSoon();
      }
    }
  }

  void _open(NavDest dest) {
    setState(() {
      if (dest == NavDest.settings && _dest != NavDest.settings) {
        _returnDest = _dest;
      }
      _dest = dest;
      if (dest == NavDest.home) _browse = HomeBrowse.nowPlaying;
    });
  }

  void _leaveSettings() {
    final back = _returnDest == NavDest.settings ? NavDest.home : _returnDest;
    setState(() => _dest = back);
  }

  void _openNowPlaying() {
    setState(() {
      _dest = NavDest.home;
      _browse = HomeBrowse.nowPlaying;
    });
  }

  void _toggleQueue() => setState(() => _queueOpen = !_queueOpen);

  void _openLibrary() {
    setState(() {
      _queueOpen = false;
      _dest = NavDest.home;
      _browse = HomeBrowse.library;
    });
  }

  void _onDock(int index) {
    final dest = NavDest.values[index];
    if (dest == NavDest.queue) {
      _toggleQueue();
      return;
    }
    setState(() => _queueOpen = false);
    _open(dest);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playerProvider, (prev, next) {
      if (prev?.currentTrack?.path != next.currentTrack?.path) {
        _loadArt(next.currentTrack?.path);
      }
    });

    final playing = ref.watch(
      playerProvider.select((player) => player.status == PlayerStatus.playing),
    );
    final hasTrack = ref.watch(
      playerProvider.select((player) => player.currentTrack != null),
    );
    final queueCount = ref.watch(
      playerProvider.select((player) => player.queue.length),
    );
    final artGlow = ref.watch(
      settingsProvider.select((s) => s.showAlbumArtBackground),
    );
    final glow =
        artGlow &&
        _dest == NavDest.home &&
        _browse == HomeBrowse.nowPlaying &&
        hasTrack &&
        _art != null;

    final page = Crossfade(
      child: KeyedSubtree(
        key: ValueKey(_dest),
        child: switch (_dest) {
          NavDest.home => HomePage(
            browse: _browse,
            art: _art,
            onBrowse: (next) => setState(() => _browse = next),
            queueOpen: _queueOpen,
            queue: _phone
                ? null
                : QueueOverlay(
                    open: _queueOpen,
                    phone: false,
                    margin: const EdgeInsets.only(bottom: 96),
                    onClose: _toggleQueue,
                    onOpenLibrary: _openLibrary,
                  ),
          ),
          NavDest.playlists => const PlaylistsPage(),
          NavDest.artists => ArtistsPage(
            onOpenSettings: () => _open(NavDest.settings),
          ),
          NavDest.history => HistoryPage(
            onOpenHome: () => setState(() {
              _dest = NavDest.home;
              _browse = HomeBrowse.library;
            }),
          ),
          // Queue slides over the page. It is not a destination.
          NavDest.queue => const SizedBox.shrink(),
          NavDest.settings =>
            _phone
                ? const PhoneSettingsPage()
                : SettingsPage(pane: _settingsPane),
        },
      ),
    );

    final showMini =
        hasTrack &&
        !(_dest == NavDest.home && _browse == HomeBrowse.nowPlaying);
    _captureGround(glow);

    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          surface: Colors.black,
          onSurface: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        iconButtonTheme: const IconButtonThemeData(
          style: ButtonStyle(
            mouseCursor: WidgetStatePropertyAll(SystemMouseCursors.click),
          ),
        ),
        textButtonTheme: const TextButtonThemeData(
          style: ButtonStyle(
            mouseCursor: WidgetStatePropertyAll(SystemMouseCursors.click),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          mouseCursor: WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: ShellCapture(
          controller: _capture,
          child: LiquidGlassView(
            controller: _capture,
            backgroundWidget: _Ground(glow: glow, art: _art),
            pixelRatio: 0.6,
            realTimeCapture: false,
            refreshRate: LiquidGlassRefreshRate.medium,
            child: SafeArea(
              bottom: false,
              child: _phone
                  ? Column(
                      children: [
                        Expanded(
                          child: _PageLayer(
                            showMini: showMini,
                            phone: true,
                            showQueue: true,
                            onOpen: _openNowPlaying,
                            queueOpen: _queueOpen,
                            onCloseQueue: _toggleQueue,
                            onOpenLibrary: _openLibrary,
                            child: page,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            10 + MediaQuery.paddingOf(context).bottom,
                          ),
                          child: _Dock(
                            dest: _queueOpen ? NavDest.queue : _dest,
                            playing: playing,
                            onSelected: _onDock,
                          ),
                        ),
                      ],
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final height = (constraints.maxHeight - 32).clamp(
                          0.0,
                          constraints.maxHeight,
                        );
                        return AnimatedBuilder(
                          animation: _nav,
                          child: page,
                          builder: (context, child) {
                            final open = Curves.easeInOutCubic.transform(
                              _nav.value,
                            );
                            return Stack(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        16,
                                        0,
                                        16,
                                      ),
                                      child: _SideChrome(
                                        height: height,
                                        open: open,
                                        settings: _dest == NavDest.settings,
                                        nav: (shown) => _Sidebar(
                                          dest: _dest,
                                          playing: playing,
                                          queueCount: queueCount,
                                          open: shown,
                                          onToggle: _toggleNav,
                                          onQueue: _toggleQueue,
                                          onSelected: _open,
                                        ),
                                        settingsBody: _SettingsSide(
                                          pane: _settingsPane,
                                          onBack: _leaveSettings,
                                          onSelected: (pane) => setState(
                                            () => _settingsPane = pane,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: _PageLayer(
                                        showMini: showMini,
                                        phone: false,
                                        showQueue: _dest != NavDest.home,
                                        onOpen: _openNowPlaying,
                                        queueOpen: _queueOpen,
                                        onCloseQueue: _toggleQueue,
                                        onOpenLibrary: _openLibrary,
                                        child: child!,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_dest != NavDest.home)
                                  const Positioned(
                                    top: 12,
                                    right: 16,
                                    child: WindowButtons(compact: true),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Ground extends StatelessWidget {
  final bool glow;
  final Uint8List? art;

  const _Ground({required this.glow, required this.art});

  @override
  Widget build(BuildContext context) {
    final shown = glow && art != null;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: motionOf(context),
            curve: motionCurve,
            child: Crossfade(
              child: art == null
                  ? const SizedBox.expand(key: ValueKey('flat'))
                  : ImageFiltered(
                      key: ValueKey(identityHashCode(art)),
                      imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                      child: Opacity(
                        opacity: 0.55,
                        child: Image.memory(art!, fit: BoxFit.cover),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideChrome extends StatefulWidget {
  final double height;
  final double open;
  final bool settings;
  final Widget Function(double shown) nav;
  final Widget settingsBody;

  const _SideChrome({
    required this.height,
    required this.open,
    required this.settings,
    required this.nav,
    required this.settingsBody,
  });

  @override
  State<_SideChrome> createState() => _SideChromeState();
}

class _SideChromeState extends State<_SideChrome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blend = AnimationController(
    vsync: this,
    duration: motionDuration,
    value: widget.settings ? 1 : 0,
  );

  @override
  void didUpdateWidget(_SideChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings == widget.settings) return;
    final next = widget.settings ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _blend.value = next;
      return;
    }
    if (widget.settings) {
      _blend.forward();
    } else {
      _blend.reverse();
    }
  }

  @override
  void dispose() {
    _blend.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _blend,
      builder: (context, _) {
        final t = motionCurve.transform(_blend.value);
        final shown = widget.open + (1 - widget.open) * t;
        final side = 8 + 4 * shown;
        return SizedBox(
          width: 48 + (208 - 48) * shown,
          height: widget.height,
          child: ShellLens(
            radius: 14,
            padding: EdgeInsets.fromLTRB(side, 18, side, 12),
            child: ClipRect(
              child: Crossfade(
                child: KeyedSubtree(
                  key: ValueKey(widget.settings),
                  child: widget.settings
                      ? widget.settingsBody
                      : widget.nav(shown),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

final _navKeys = <NavDest, GlobalKey>{
  for (final dest in NavDest.values) dest: GlobalKey(),
};

final _paneKeys = <SettingsPane, GlobalKey>{
  for (final pane in SettingsPane.values) pane: GlobalKey(),
};

class _SettingsSide extends StatelessWidget {
  final SettingsPane pane;
  final VoidCallback onBack;
  final ValueChanged<SettingsPane> onSelected;

  const _SettingsSide({
    required this.pane,
    required this.onBack,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 28,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              tr('sidebar.settings'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              MovingFill(
                selectedKey: _paneKeys[pane]!,
                color: const Color(0x14FFFFFF),
                radius: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final group in settingsGroups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                        child: Text(
                          tr(group.label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ),
                      for (final item in group.items)
                        _SettingsRow(
                          fillKey: _paneKeys[item.pane]!,
                          icon: item.icon,
                          label: settingsPaneTitle(item.pane),
                          selected: item.pane == pane,
                          onTap: () => onSelected(item.pane),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0x14FFFFFF)),
        _SettingsBack(onBack: onBack),
      ],
    );
  }
}

class _SettingsBack extends StatelessWidget {
  final VoidCallback onBack;

  const _SettingsBack({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onBack,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 36,
          child: Row(
            children: [
              const SizedBox(width: 8),
              const Icon(CupertinoIcons.chevron_left, size: 16, color: _muted),
              const SizedBox(width: 8),
              Text(
                tr('sidebar.back'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final GlobalKey fillKey;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.fillKey,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : _muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            key: fillKey,
            height: 36,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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

class _Sidebar extends StatelessWidget {
  final NavDest dest;
  final bool playing;
  final int queueCount;
  final double open;
  final VoidCallback onToggle;
  final VoidCallback onQueue;
  final ValueChanged<NavDest> onSelected;

  const _Sidebar({
    required this.dest,
    required this.playing,
    required this.queueCount,
    required this.open,
    required this.onToggle,
    required this.onQueue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final collapsed = open < 0.5;
    return ClipRect(
      child: MovingFill(
        selectedKey: _navKeys[dest]!,
        color: const Color(0x14FFFFFF),
        radius: 10,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SizedBox(
                height: 28,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _Reveal(
                        open: open,
                        child: Opacity(
                          opacity: open,
                          child: Transform.scale(
                            scale: open == 0 ? 0.001 : open,
                            alignment: Alignment.centerLeft,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image(
                                  image: AssetImage('assets/icons/icon_32.png'),
                                  width: 28,
                                  height: 28,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Aqloss',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.lerp(
                        Alignment.center,
                        Alignment.centerRight,
                        open,
                      )!,
                      child: IconButton(
                        onPressed: onToggle,
                        tooltip: tr(
                          collapsed ? 'sidebar.expand' : 'sidebar.collapse',
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
                        ),
                        icon: Transform.rotate(
                          angle: (1 - open) * 3.1416,
                          child: const Icon(
                            CupertinoIcons.chevron_left,
                            size: 16,
                            color: _muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _NavRow(
              fillKey: _navKeys[NavDest.home]!,
              label: tr('sidebar.home'),
              icon: CupertinoIcons.house_fill,
              selected: dest == NavDest.home,
              dot: playing,
              open: open,
              onTap: () => onSelected(NavDest.home),
            ),
            _NavRow(
              fillKey: _navKeys[NavDest.playlists]!,
              label: tr('sidebar.playlists'),
              icon: CupertinoIcons.music_note_list,
              selected: dest == NavDest.playlists,
              open: open,
              onTap: () => onSelected(NavDest.playlists),
            ),
            _NavRow(
              fillKey: _navKeys[NavDest.artists]!,
              label: tr('sidebar.artists'),
              icon: CupertinoIcons.person_2_fill,
              selected: dest == NavDest.artists,
              open: open,
              onTap: () => onSelected(NavDest.artists),
            ),
            _NavRow(
              fillKey: _navKeys[NavDest.history]!,
              label: tr('sidebar.history'),
              icon: CupertinoIcons.clock_fill,
              selected: dest == NavDest.history,
              open: open,
              onTap: () => onSelected(NavDest.history),
            ),
            const Spacer(),
            _NavRow(
              fillKey: _navKeys[NavDest.queue]!,
              label: tr('sidebar.queue'),
              icon: CupertinoIcons.list_bullet,
              selected: false,
              open: open,
              trailing: queueCount > 0
                  ? (queueCount > 99 ? '99+' : '$queueCount')
                  : null,
              onTap: onQueue,
            ),
            _NavRow(
              fillKey: _navKeys[NavDest.settings]!,
              label: tr('sidebar.settings'),
              icon: CupertinoIcons.gear_solid,
              selected: dest == NavDest.settings,
              open: open,
              onTap: () => onSelected(NavDest.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  final double open;
  final Widget child;

  const _Reveal({required this.open, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: open,
        child: child,
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool dot;

  const _NavIcon({required this.icon, required this.color, required this.dot});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          Positioned(
            right: -4,
            top: -3,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: dot ? 1 : 0),
              duration: motionOf(context),
              curve: motionCurve,
              builder: (context, t, child) {
                return Opacity(
                  opacity: t,
                  child: Transform.scale(
                    scale: t == 0 ? 0.01 : t,
                    child: child,
                  ),
                );
              },
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 5, height: 5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final GlobalKey fillKey;
  final String label;
  final IconData icon;
  final bool selected;
  final bool dot;
  final double open;
  final String? trailing;
  final VoidCallback onTap;

  const _NavRow({
    required this.fillKey,
    required this.label,
    required this.icon,
    required this.selected,
    required this.open,
    required this.onTap,
    this.dot = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : _muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            key: fillKey,
            height: 36,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Align(
                  alignment: Alignment.lerp(
                    Alignment.center,
                    Alignment.centerLeft,
                    open,
                  )!,
                  child: Padding(
                    padding: EdgeInsets.only(left: 8 * open),
                    child: _NavIcon(icon: icon, color: color, dot: dot),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 16 + 8 * open),
                  child: _Reveal(
                    open: open,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: motionOf(context),
                            switchInCurve: motionCurve,
                            switchOutCurve: motionCurve,
                            child: trailing == null
                                ? const SizedBox(
                                    key: ValueKey('count-off'),
                                    width: 0,
                                    height: 0,
                                  )
                                : Padding(
                                    key: ValueKey(trailing),
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      trailing!,
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
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

class _Dock extends StatelessWidget {
  final NavDest dest;
  final bool playing;
  final ValueChanged<int> onSelected;

  const _Dock({
    required this.dest,
    required this.playing,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return LiquidGlassTabBar(
            style: shellGlass,
            width: constraints.maxWidth,
            height: 56,
            margin: EdgeInsets.zero,
            itemPadding: 4,
            selectedIndex: dest.index,
            onChanged: onSelected,
            pillStyle: const LiquidGlassTabPillStyle(
              mode: LiquidGlassPillMode.none,
              animated: true,
              rest: LiquidGlassStyle(
                color: Color(0x24FFFFFF),
                shape: LiquidGlassShape.continuousRoundedRectangle(
                  cornerRadius: 999,
                ),
              ),
            ),
            itemStyle: const LiquidGlassTabItemStyle(
              iconSize: 22,
              selectedColor: Colors.white,
              unselectedColor: textMuted,
            ),
            items: [
              LiquidGlassTabBarItem(
                iconBuilder: (_, _) => _HomeGlyph(playing: playing),
              ),
              const LiquidGlassTabBarItem(icon: CupertinoIcons.music_note_list),
              const LiquidGlassTabBarItem(icon: CupertinoIcons.person_2_fill),
              const LiquidGlassTabBarItem(icon: CupertinoIcons.clock_fill),
              const LiquidGlassTabBarItem(icon: CupertinoIcons.list_bullet),
              const LiquidGlassTabBarItem(icon: CupertinoIcons.gear_solid),
            ],
          );
        },
      ),
    );
  }
}

class _HomeGlyph extends StatelessWidget {
  final bool playing;

  const _HomeGlyph({required this.playing});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          const Icon(CupertinoIcons.house_fill),
          Positioned(
            right: -1,
            top: 1,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: playing ? 1 : 0),
              duration: motionOf(context),
              curve: motionCurve,
              builder: (context, t, child) {
                return Opacity(
                  opacity: t,
                  child: Transform.scale(scale: t, child: child),
                );
              },
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 5, height: 5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageLayer extends StatelessWidget {
  final bool showMini;
  final bool phone;
  final bool showQueue;
  final VoidCallback onOpen;
  final bool queueOpen;
  final VoidCallback onCloseQueue;
  final VoidCallback onOpenLibrary;
  final Widget child;

  const _PageLayer({
    required this.showMini,
    required this.phone,
    required this.showQueue,
    required this.onOpen,
    required this.queueOpen,
    required this.onCloseQueue,
    required this.onOpenLibrary,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedPadding(
          duration: motionOf(context),
          curve: motionCurve,
          padding: EdgeInsets.only(bottom: showMini && phone ? 80 : 0),
          child: child,
        ),
        if (showQueue)
          QueueOverlay(
            open: queueOpen,
            phone: phone,
            margin: phone
                ? EdgeInsets.zero
                : const EdgeInsets.fromLTRB(0, 20, 20, 112),
            onClose: onCloseQueue,
            onOpenLibrary: onOpenLibrary,
          ),
        Positioned(
          left: phone ? 16 : 24,
          right: phone ? 16 : 24,
          bottom: phone ? 8 : 20,
          child: IgnorePointer(
            ignoring: !showMini,
            child: AnimatedSlide(
              offset: showMini ? Offset.zero : const Offset(0, 0.3),
              duration: motionOf(context),
              curve: motionCurve,
              child: AnimatedOpacity(
                opacity: showMini ? 1 : 0,
                duration: motionOf(context),
                curve: motionCurve,
                child: phone
                    ? _MiniCard(onOpen: onOpen)
                    : _DeskCard(onOpen: onOpen),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeskCard extends ConsumerWidget {
  final VoidCallback onOpen;

  const _DeskCard({required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final track = player.currentTrack;
    if (track == null) return const SizedBox.shrink();
    final playing = player.status == PlayerStatus.playing;
    final notifier = ref.read(playerProvider.notifier);
    final duration = track.duration;
    final position = player.position > duration ? duration : player.position;
    final elapsed = MetadataService.formatDuration(position);
    final total = MetadataService.formatDuration(duration);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x2EFFFFFF)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: onOpen,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          MiniAlbumArt(path: track.path, size: 48, radius: 10),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  track.displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  track.uiArtist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Text(
                  '$elapsed / $total',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(width: 8),
                const _DeskSleep(),
                _DeskButton(
                  tooltip: tr('player.shuffle'),
                  onPressed: notifier.toggleShuffle,
                  icon: ShellIcon(
                    glyph: ShellGlyph.shuffle,
                    color: player.shuffle ? Colors.white : _muted,
                    size: 18,
                  ),
                ),
                _DeskButton(
                  tooltip: switch (player.loopMode) {
                    LoopMode.off => tr('player.repeat'),
                    LoopMode.track => tr('player.repeat_track'),
                    LoopMode.album => tr('player.repeat_album'),
                    LoopMode.playlist => tr('player.repeat_all'),
                  },
                  onPressed: notifier.cycleLoopMode,
                  icon: ShellIcon(
                    glyph: player.loopMode == LoopMode.track
                        ? ShellGlyph.repeatOne
                        : ShellGlyph.repeat,
                    color: player.loopMode == LoopMode.off
                        ? _muted
                        : Colors.white,
                    size: 18,
                  ),
                ),
                TextButton(
                  onPressed: notifier.tapAbLoop,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(36, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'A-B',
                    style: TextStyle(
                      color: player.abLoop == AbLoopPhase.off
                          ? _muted
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _DeskButton(
                  tooltip: tr('player.previous_track'),
                  onPressed: notifier.previous,
                  icon: const ShellIcon(
                    glyph: ShellGlyph.previous,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                _DeskButton(
                  tooltip: tr('player.play_pause'),
                  onPressed: playing ? notifier.pause : notifier.play,
                  icon: IconFade(
                    child: ShellIcon(
                      key: ValueKey(playing),
                      glyph: playing ? ShellGlyph.pause : ShellGlyph.play,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
                _DeskButton(
                  tooltip: tr('player.next_track'),
                  onPressed: notifier.next,
                  icon: const ShellIcon(
                    glyph: ShellGlyph.next,
                    color: Colors.white,
                    size: 18,
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

class _DeskSleep extends ConsumerWidget {
  const _DeskSleep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final ticking =
        player.sleepActive && player.sleepMode != SleepTimerMode.endOfTrack;
    if (!ticking) return _button(context, player);
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, _) => _button(context, player),
    );
  }

  Widget _button(BuildContext context, PlayerState player) {
    return _DeskButton(
      tooltip: sleepTimerTooltip(
        mode: player.sleepMode,
        until: player.sleepUntil,
      ),
      onPressed: () {
        final box = context.findRenderObject() as RenderBox?;
        final origin = box == null
            ? Offset.zero
            : box.localToGlobal(box.size.center(Offset.zero));
        showSleepTimerSheet(context, origin);
      },
      icon: ShellIcon(
        glyph: ShellGlyph.moon,
        color: player.sleepActive ? Colors.white : _muted,
        size: 18,
      ),
    );
  }
}

class _DeskButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;
  final Widget icon;

  const _DeskButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      icon: icon,
    );
  }
}

class _MiniCard extends ConsumerWidget {
  final VoidCallback onOpen;

  const _MiniCard({required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final track = player.currentTrack;
    if (track == null) return const SizedBox.shrink();
    final playing = player.status == PlayerStatus.playing;
    final notifier = ref.read(playerProvider.notifier);

    return ShellLens(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onOpen,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    MiniAlbumArt(path: track.path, size: 44, radius: 8),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            track.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            track.uiArtist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: tr('player.play_pause'),
            onPressed: playing ? notifier.pause : notifier.play,
            icon: IconFade(
              child: Icon(
                playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                key: ValueKey(playing),
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
