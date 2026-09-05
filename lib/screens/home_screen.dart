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
import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/widgets/ui/app_shell.dart';
import 'package:aqloss/theme/ui_framework.dart';
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
import 'package:aqloss/ui/m3/shell/m3_home_shell.dart';
import 'package:aqloss/widgets/ui/floating_nav_bar.dart';

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

    final keyName = ctrl
        ? (_physicalKeyName(event.physicalKey) ?? _logicalKeyName(key))
        : _logicalKeyName(key);
    if (keyName == null) return null;

    final parts = <String>[if (ctrl) 'Ctrl', if (shift) 'Shift', keyName];
    return parts.join('+');
  }

  // Physical key resolution
  static String? _physicalKeyName(PhysicalKeyboardKey physical) {
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

  static String? _logicalKeyName(LogicalKeyboardKey key) {
    final named = <LogicalKeyboardKey, String>{
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
    if (named.containsKey(key)) return named[key];
    final label = key.keyLabel;
    if (label.isNotEmpty) return label.toUpperCase();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LibraryNavRequest?>(libraryNavProvider, (prev, next) {
      if (next == null) return;
      if (_route != next.route) setState(() => _route = next.route);
    });

    final settings = ref.watch(settingsProvider);
    if (settings.uiFramework == UiFramework.material3) {
      return const M3HomeShell();
    }

    final isWide = MediaQuery.of(context).size.width > 700;
    final player = ref.watch(playerProvider);
    final hasTrack = player.currentTrack != null;
    final bg = context.aq.surface;

    return Focus(
      autofocus: true,
      child: AppShell(
        color: bg,
        child: SafeArea(
          top: !_isDesktop,
          bottom: false,
          child: Column(
            children: [
              if (settings.showTitleBar && _isDesktop) CustomTitleBar(isMaximized: _isMaximized),
              Expanded(
                child: isWide
                    ? GlobalSearchOverlay(
                        key: globalSearchKey,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    : _MobileShell(
                        route: _route,
                        hasTrack: hasTrack,
                        onRouteChanged: (r) => setState(() => _route = r),
                        onCreatePlaylist: _showCreatePlaylistDialog,
                        screen: _buildScreen(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileShell extends StatefulWidget {
  final int route;
  final bool hasTrack;
  final ValueChanged<int> onRouteChanged;
  final VoidCallback onCreatePlaylist;
  final Widget screen;

  const _MobileShell({
    required this.route,
    required this.hasTrack,
    required this.onRouteChanged,
    required this.onCreatePlaylist,
    required this.screen,
  });

  @override
  State<_MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<_MobileShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  int get _navIndex {
    if (widget.route >= 10) return 4;
    if (widget.route == 4) return 4;
    if (widget.route == 5) return 4;
    return widget.route.clamp(0, 3);
  }

  void _onNavSelected(int i) {
    if (i == 4) {
      _scaffoldKey.currentState?.openDrawer();
    } else {
      widget.onRouteChanged(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aq = context.aq;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final showMini = widget.hasTrack && widget.route != 0;
    final contentBottom = 72.0 + bottom + (showMini ? 58.0 : 0.0);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      extendBody: true,
      drawer: _MobileDrawer(
        route: widget.route,
        onSelect: widget.onRouteChanged,
        onCreatePlaylist: widget.onCreatePlaylist,
      ),
      body: Padding(
        padding: EdgeInsets.only(bottom: contentBottom),
        child: widget.screen,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showMini)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Material(
                elevation: 5,
                shadowColor: Colors.black.withValues(alpha: 0.3),
                color: aq.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: MiniPlayerBar(onTap: () => widget.onRouteChanged(0)),
              ),
            ),
          FloatingNavBar(selectedIndex: _navIndex, onSelected: _onNavSelected),
        ],
      ),
    );
  }
}

class _MobileDrawer extends ConsumerWidget {
  final int route;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreatePlaylist;

  const _MobileDrawer({
    required this.route,
    required this.onSelect,
    required this.onCreatePlaylist,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistProvider);
    final isM3 = context.isMaterial3Ui;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Aqloss',
                      style: TextStyle(
                        fontSize: isM3 ? 20 : 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: isM3 ? 0 : 2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'New playlist',
                    onPressed: () {
                      Navigator.pop(context);
                      onCreatePlaylist();
                    },
                  ),
                ],
              ),
            ),
            _DrawerTile(
              icon: Icons.person_outline_rounded,
              label: 'Artists',
              selected: route == 5,
              onTap: () {
                Navigator.pop(context);
                onSelect(5);
              },
            ),
            _DrawerTile(
              icon: Icons.history_rounded,
              label: 'History',
              selected: route == 4,
              onTap: () {
                Navigator.pop(context);
                onSelect(4);
              },
            ),
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                'PLAYLISTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: playlists.isEmpty
                  ? Center(
                      child: Text(
                        'No playlists yet',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: playlists.length,
                      itemBuilder: (ctx, i) {
                        final pl = playlists[i];
                        return _DrawerTile(
                          icon: Icons.queue_music_rounded,
                          label: pl.name,
                          subtitle: '${pl.length} tracks',
                          selected: route == i + 10,
                          onTap: () {
                            Navigator.pop(context);
                            onSelect(i + 10);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isMaterial3Ui) {
      return ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        selected: selected,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
    }

    final aq = context.aq;
    return ListTile(
      leading: Icon(
        icon,
        size: 20,
        color: selected ? aq.onSurface : aq.onSurfaceMuted,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? aq.onSurface : aq.onSurface.withValues(alpha: 0.75),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(fontSize: 11, color: aq.onSurfaceMuted),
            )
          : null,
      selected: selected,
      selectedTileColor: aq.onSurface.withValues(alpha: 0.06),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
