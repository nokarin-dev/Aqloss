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
import 'package:aqloss/util/search_focus_tracker.dart';
import 'package:aqloss/widgets/mini_player_bar.dart';
import 'package:aqloss/widgets/shared/input_dialog.dart';
import 'package:aqloss/widgets/sidebar/side_nav.dart';
import 'package:aqloss/widgets/sidebar/title_bar.dart';
import 'package:aqloss/widgets/playlist/playlist_detail_screen.dart';
import 'album_screen.dart';
import 'library_screen.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import 'history_screen.dart';
import 'artists_screen.dart';
import 'package:aqloss/widgets/mini_player_window.dart';
import 'package:aqloss/widgets/queue_panel.dart';
import 'package:aqloss/widgets/global_search.dart';

const _kSidebarCollapsed = 'aqloss_sidebar_collapsed';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WindowListener {
  int _route = 0;
  bool _isMaximized = false;
  bool _sidebarCollapsed = false;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    if (_isDesktop) windowManager.addListener(this);
    _loadSidebarPref();
    HardwareKeyboard.instance.addHandler(_globalKeyHandler);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_globalKeyHandler);
    if (_isDesktop) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);
  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  Future<void> _loadSidebarPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(
        () => _sidebarCollapsed = prefs.getBool(_kSidebarCollapsed) ?? false,
      );
    }
  }

  Future<void> _toggleSidebar() async {
    final next = !_sidebarCollapsed;
    setState(() => _sidebarCollapsed = next);
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_kSidebarCollapsed, next);
  }

  Widget _buildScreen() {
    if (_route == 0) return const PlayerScreen();
    if (_route == 1) return const LibraryScreen();
    if (_route == 2) return const AlbumsScreen();
    if (_route == 3) return const SettingsScreen();
    if (_route == 4) return const HistoryScreen();
    if (_route == 5) return const ArtistsScreen();

    final playlists = ref.read(playlistProvider);
    final idx = _route - 10;
    if (idx >= 0 && idx < playlists.length) {
      return PlaylistDetailScreen(playlist: playlists[idx]);
    }
    return const PlayerScreen();
  }

  // Global key handler
  bool _globalKeyHandler(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (SearchFocusTracker.instance.hasFocus) return false;

    final settings = ref.read(settingsProvider);
    final pressed = _keyEventToString(event);
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
        _toggleSidebar();
      case ShortcutAction.toggleQueue:
        final n = ref.read(queuePanelOpenProvider.notifier);
        n.state = !n.state;
      case ShortcutAction.search:
        globalSearchKey.currentState?.show();
      case ShortcutAction.miniPlayer:
        MiniPlayerWindow.toggle(context);
      case ShortcutAction.navPlayer:
        setState(() => _route = 0);
      case ShortcutAction.navLibrary:
        setState(() => _route = 1);
      case ShortcutAction.navAlbums:
        setState(() => _route = 2);
      case ShortcutAction.navArtists:
        setState(() => _route = 5);
      case ShortcutAction.navHistory:
        setState(() => _route = 4);
      case ShortcutAction.navSettings:
        setState(() => _route = 3);
      case ShortcutAction.newPlaylist:
        _showCreatePlaylistDialog();
    }
    return true;
  }

  Future<void> _showCreatePlaylistDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => InputDialog(
        title: 'New playlist',
        hint: 'Playlist name',
        confirmLabel: 'Create',
        controller: ctrl,
      ),
    );
    if (name != null && name.isNotEmpty) {
      ref.read(playlistProvider.notifier).create(name);
    }
  }

  // Convert a KeyDownEvent to a canonical string
  static String? _keyEventToString(KeyEvent event) {
    final ctrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;

    // Modifier-only keys
    if (key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.alt) {
      return null;
    }

    final keyName = _logicalKeyName(key);
    if (keyName == null) return null;

    final parts = <String>[if (ctrl) 'Ctrl', if (shift) 'Shift', keyName];
    return parts.join('+');
  }

  static String? _logicalKeyName(LogicalKeyboardKey key) {
    final names = <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.space: 'Space',
      LogicalKeyboardKey.arrowLeft: 'ArrowLeft',
      LogicalKeyboardKey.arrowRight: 'ArrowRight',
      LogicalKeyboardKey.arrowUp: 'ArrowUp',
      LogicalKeyboardKey.arrowDown: 'ArrowDown',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.keyA: 'A',
      LogicalKeyboardKey.keyB: 'B',
      LogicalKeyboardKey.keyC: 'C',
      LogicalKeyboardKey.keyD: 'D',
      LogicalKeyboardKey.keyE: 'E',
      LogicalKeyboardKey.keyF: 'F',
      LogicalKeyboardKey.keyG: 'G',
      LogicalKeyboardKey.keyH: 'H',
      LogicalKeyboardKey.keyI: 'I',
      LogicalKeyboardKey.keyJ: 'J',
      LogicalKeyboardKey.keyK: 'K',
      LogicalKeyboardKey.keyL: 'L',
      LogicalKeyboardKey.keyM: 'M',
      LogicalKeyboardKey.keyN: 'N',
      LogicalKeyboardKey.keyO: 'O',
      LogicalKeyboardKey.keyP: 'P',
      LogicalKeyboardKey.keyQ: 'Q',
      LogicalKeyboardKey.keyR: 'R',
      LogicalKeyboardKey.keyS: 'S',
      LogicalKeyboardKey.keyT: 'T',
      LogicalKeyboardKey.keyU: 'U',
      LogicalKeyboardKey.keyV: 'V',
      LogicalKeyboardKey.keyW: 'W',
      LogicalKeyboardKey.keyX: 'X',
      LogicalKeyboardKey.keyY: 'Y',
      LogicalKeyboardKey.keyZ: 'Z',
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
    return names[key];
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    final player = ref.watch(playerProvider);
    final hasTrack = player.currentTrack != null;

    return Focus(
      autofocus: true,
      child: Scaffold(
        body: SafeArea(
          top: !_isDesktop,
          bottom: false,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                if (_isDesktop) CustomTitleBar(isMaximized: _isMaximized),
                Expanded(
                  child: isWide
                      ? GlobalSearchOverlay(
                          key: globalSearchKey,
                          child: Row(
                            children: [
                              SideNav(
                                route: _route,
                                collapsed: _sidebarCollapsed,
                                onSelect: (r) => setState(() => _route = r),
                                onToggleCollapse: _toggleSidebar,
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Expanded(child: _buildScreen()),
                                    if (hasTrack && _route != 0)
                                      MiniPlayerBar(
                                        onTap: () => setState(() => _route = 0),
                                      ),
                                  ],
                                ),
                              ),
                              const QueuePanel(),
                            ],
                          ),
                        )
                      : _buildScreen(),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: isWide
            ? null
            : _MobileNavBar(
                selectedIndex: _route.clamp(0, 3),
                onDestinationSelected: (i) => setState(() => _route = i),
                hasTrack: hasTrack && _route != 0,
                onMiniPlayerTap: () => setState(() => _route = 0),
              ),
      ),
    );
  }
}

// Mobile nav bar
class _MobileNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool hasTrack;
  final VoidCallback onMiniPlayerTap;

  const _MobileNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.hasTrack,
    required this.onMiniPlayerTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasTrack) MiniPlayerBar(onTap: onMiniPlayerTap),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            border: Border(
              top: BorderSide(color: cs.onSurface.withValues(alpha: 0.06)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 54,
              child: Row(
                children: [
                  _NavTab(
                    icon: Icons.play_circle_outline_rounded,
                    activeIcon: Icons.play_circle_rounded,
                    label: 'Now Playing',
                    isSelected: selectedIndex == 0,
                    onTap: () => onDestinationSelected(0),
                  ),
                  _NavTab(
                    icon: Icons.library_music_outlined,
                    activeIcon: Icons.library_music_rounded,
                    label: 'Library',
                    isSelected: selectedIndex == 1,
                    onTap: () => onDestinationSelected(1),
                  ),
                  _NavTab(
                    icon: Icons.album_outlined,
                    activeIcon: Icons.album_rounded,
                    label: 'Albums',
                    isSelected: selectedIndex == 2,
                    onTap: () => onDestinationSelected(2),
                  ),
                  _NavTab(
                    icon: Icons.tune_outlined,
                    activeIcon: Icons.tune_rounded,
                    label: 'Settings',
                    isSelected: selectedIndex == 3,
                    onTap: () => onDestinationSelected(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavTab extends ConsumerWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isIslands = ref.watch(settingsProvider).appStyle == AppStyle.islands;
    final activeColor = isIslands ? cs.primary : cs.onSurface;
    final inactiveColor = cs.onSurface.withValues(alpha: 0.30);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey(isSelected),
                size: 22,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? activeColor : inactiveColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
