import 'dart:io' show Platform;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/providers/library_nav_provider.dart';
import 'package:aqloss/screens/album_screen.dart';
import 'package:aqloss/screens/artists_screen.dart';
import 'package:aqloss/screens/history_screen.dart';
import 'package:aqloss/screens/library_screen.dart';
import 'package:aqloss/screens/player_screen.dart';
import 'package:aqloss/screens/settings_screen.dart';
import 'package:aqloss/ui/m3/chrome/m3_mini_player.dart';
import 'package:aqloss/widgets/ui/floating_nav_bar.dart';
import 'package:aqloss/ui/m3/chrome/m3_queue_drawer.dart';
import 'package:aqloss/ui/m3/m3_route.dart';
import 'package:aqloss/ui/m3/shell/m3_desktop_nav.dart';
import 'package:aqloss/ui/m3/shell/m3_app_drawer.dart';
import 'package:aqloss/util/search_focus_tracker.dart';
import 'package:aqloss/widgets/global_search.dart';
import 'package:aqloss/widgets/mini_player_window.dart';
import 'package:aqloss/widgets/playlist/playlist_detail_screen.dart';
import 'package:aqloss/widgets/queue_panel.dart';
import 'package:aqloss/widgets/sidebar/title_bar.dart';

class M3HomeShell extends ConsumerStatefulWidget {
  const M3HomeShell({super.key});

  @override
  ConsumerState<M3HomeShell> createState() => _M3HomeShellState();
}

class _M3HomeShellState extends ConsumerState<M3HomeShell> with WindowListener {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _route = M3Route.player;
  bool _isMaximized = false;
  bool _navCollapsed = false;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    if (_isDesktop) windowManager.addListener(this);
    _loadNavPref();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    if (_isDesktop) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);
  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  Future<void> _loadNavPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(
        () => _navCollapsed = prefs.getBool('m3_nav_collapsed') ?? false,
      );
    }
  }

  Future<void> _toggleNav() async {
    final next = !_navCollapsed;
    setState(() => _navCollapsed = next);
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('m3_nav_collapsed', next);
  }

  Widget _screen() {
    return switch (_route) {
      M3Route.player => const PlayerScreen(),
      M3Route.library => const LibraryScreen(),
      M3Route.albums => const AlbumsScreen(),
      M3Route.settings => const SettingsScreen(),
      M3Route.history => const HistoryScreen(),
      M3Route.artists => const ArtistsScreen(),
      _ => _playlistScreen(),
    };
  }

  Widget _playlistScreen() {
    final playlists = ref.read(playlistProvider);
    final idx = _route - M3Route.playlistBase;
    if (idx >= 0 && idx < playlists.length) {
      return PlaylistDetailScreen(playlist: playlists[idx]);
    }
    return const PlayerScreen();
  }

  Future<void> _createPlaylist() async {
    await showM3CreatePlaylistDialog(context, ref);
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (SearchFocusTracker.instance.hasFocus) return false;

    final settings = ref.read(settingsProvider);
    final pressed = _keyToString(event);
    if (pressed == null) return false;

    final action = ShortcutAction.values.firstWhereOrNull(
      (a) => settings.binding(a) == pressed,
    );
    if (action == null) {
      if (event.logicalKey == LogicalKeyboardKey.escape &&
          globalSearchKey.currentState?.isOpen == true) {
        globalSearchKey.currentState?.hide();
        return true;
      }
      return false;
    }

    switch (action) {
      case ShortcutAction.playPause:
        final player = ref.read(playerProvider);
        if (player.currentTrack == null) return false;
        if (player.status == PlayerStatus.playing) {
          ref.read(playerProvider.notifier).pause();
        } else {
          ref.read(playerProvider.notifier).play();
        }
      case ShortcutAction.skipNext:
        ref.read(playerProvider.notifier).skipNext();
      case ShortcutAction.skipPrevious:
        ref.read(playerProvider.notifier).skipPrevious();
      case ShortcutAction.volumeUp:
        final vol = (ref.read(playerProvider).volume + 0.05).clamp(0.0, 1.0);
        ref.read(playerProvider.notifier).setVolume(vol);
      case ShortcutAction.volumeDown:
        final vol = (ref.read(playerProvider).volume - 0.05).clamp(0.0, 1.0);
        ref.read(playerProvider.notifier).setVolume(vol);
      case ShortcutAction.toggleSidebar:
        _toggleNav();
      case ShortcutAction.toggleQueue:
        _scaffoldKey.currentState?.openEndDrawer();
        ref.read(queuePanelOpenProvider.notifier).state = true;
      case ShortcutAction.search:
        globalSearchKey.currentState?.show();
      case ShortcutAction.miniPlayer:
        MiniPlayerWindow.toggle(context);
      case ShortcutAction.navPlayer:
        setState(() => _route = M3Route.player);
      case ShortcutAction.navLibrary:
        setState(() => _route = M3Route.library);
      case ShortcutAction.navAlbums:
        setState(() => _route = M3Route.albums);
      case ShortcutAction.navArtists:
        setState(() => _route = M3Route.artists);
      case ShortcutAction.navHistory:
        setState(() => _route = M3Route.history);
      case ShortcutAction.navSettings:
        setState(() => _route = M3Route.settings);
      case ShortcutAction.newPlaylist:
        _createPlaylist();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LibraryNavRequest?>(libraryNavProvider, (prev, next) {
      if (next == null) return;
      if (_route != next.route) setState(() => _route = next.route);
    });

    final isWide = MediaQuery.sizeOf(context).width > 700;
    final player = ref.watch(playerProvider);
    final hasTrack = player.currentTrack != null;

    final scaffold = Scaffold(
      key: _scaffoldKey,
      extendBody: !isWide,
      drawer: isWide
          ? null
          : M3AppDrawer(
              route: _route,
              onSelect: (r) => setState(() => _route = r),
              onCreatePlaylist: _createPlaylist,
              onSearch: () => globalSearchKey.currentState?.show(),
              onOpenQueue: () {
                _scaffoldKey.currentState?.openEndDrawer();
                ref.read(queuePanelOpenProvider.notifier).state = true;
              },
            ),
      endDrawer: const M3QueueDrawer(),
      onEndDrawerChanged: (open) {
        ref.read(queuePanelOpenProvider.notifier).state = open;
      },
      body: isWide ? _desktopBody(hasTrack) : _mobileBody(),
      bottomNavigationBar: isWide
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasTrack && _route != M3Route.player)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                    child: M3MiniPlayerBar(
                      onTap: () => setState(() => _route = M3Route.player),
                      onOpenQueue: () {
                        _scaffoldKey.currentState?.openEndDrawer();
                        ref.read(queuePanelOpenProvider.notifier).state = true;
                      },
                    ),
                  ),
                FloatingNavBar(
                  selectedIndex: _mobileNavIndex(),
                  onSelected: (i) {
                    if (i == 4) {
                      _scaffoldKey.currentState?.openDrawer();
                    } else {
                      setState(() => _route = _mobileRouteFor(i));
                    }
                  },
                ),
              ],
            ),
    );

    return Focus(autofocus: true, child: scaffold);
  }

  Widget _mobileBody() {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final player = ref.watch(playerProvider);
    final hasTrack = player.currentTrack != null;
    final showMini = hasTrack && _route != M3Route.player;
    final contentBottom = 80.0 + bottom + (showMini ? 58.0 : 0.0);

    return SafeArea(
      bottom: false,
      child: GlobalSearchOverlay(
        key: globalSearchKey,
        child: Padding(
          padding: EdgeInsets.only(bottom: contentBottom),
          child: _screen(),
        ),
      ),
    );
  }

  Widget _desktopBody(bool hasTrack) {
    return Column(
      children: [
        if (_isDesktop) CustomTitleBar(isMaximized: _isMaximized),
        Expanded(
          child: GlobalSearchOverlay(
            key: globalSearchKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                M3DesktopNav(
                  route: _route,
                  collapsed: _navCollapsed,
                  onSelect: (r) => setState(() => _route = r),
                  onToggleCollapse: _toggleNav,
                  onOpenQueue: () {
                    _scaffoldKey.currentState?.openEndDrawer();
                    ref.read(queuePanelOpenProvider.notifier).state = true;
                  },
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _screen()),
                      if (hasTrack && _route != M3Route.player)
                        M3MiniPlayerBar(
                          onTap: () => setState(() => _route = M3Route.player),
                          onOpenQueue: () {
                            _scaffoldKey.currentState?.openEndDrawer();
                            ref.read(queuePanelOpenProvider.notifier).state =
                                true;
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  int _mobileNavIndex() {
    if (_route >= M3Route.playlistBase) return 4;
    if (_route == M3Route.history || _route == M3Route.artists) return 4;
    return _route.clamp(0, 3);
  }

  int _mobileRouteFor(int i) => switch (i) {
    0 => M3Route.player,
    1 => M3Route.library,
    2 => M3Route.albums,
    3 => M3Route.settings,
    _ => M3Route.player,
  };

  static String? _keyToString(KeyEvent event) {
    final ctrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.alt) {
      return null;
    }
    String? name;
    final label = key.keyLabel;
    if (label.length == 1) {
      name = label.toUpperCase();
    } else {
      name = switch (key) {
        LogicalKeyboardKey.space => 'Space',
        LogicalKeyboardKey.f1 => 'F1',
        LogicalKeyboardKey.f2 => 'F2',
        LogicalKeyboardKey.f3 => 'F3',
        LogicalKeyboardKey.f4 => 'F4',
        LogicalKeyboardKey.f5 => 'F5',
        LogicalKeyboardKey.f6 => 'F6',
        LogicalKeyboardKey.f7 => 'F7',
        LogicalKeyboardKey.f8 => 'F8',
        LogicalKeyboardKey.f9 => 'F9',
        LogicalKeyboardKey.f10 => 'F10',
        LogicalKeyboardKey.f11 => 'F11',
        LogicalKeyboardKey.f12 => 'F12',
        _ => null,
      };
    }
    if (name == null) return null;
    return [if (ctrl) 'Ctrl', if (shift) 'Shift', name].join('+');
  }
}
