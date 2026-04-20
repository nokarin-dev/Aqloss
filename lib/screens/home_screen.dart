import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'library_screen.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/widgets/mini_player_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WindowListener {
  int _currentIndex = 0;
  bool _isMaximized = false;

  final _screens = const [LibraryScreen(), PlayerScreen(), SettingsScreen()];

  @override
  void initState() {
    super.initState();
    if (_isDesktop) windowManager.addListener(this);
  }

  @override
  void dispose() {
    if (_isDesktop) windowManager.removeListener(this);
    super.dispose();
  }

  void onWindowMaximize() => setState(() => _isMaximized = true);
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    final player = ref.watch(playerProvider);
    final hasTrack = player.currentTrack != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Column(
        children: [
          if (_isDesktop) _CustomTitleBar(isMaximized: _isMaximized),

          Expanded(
            child: isWide
                ? Row(
                    children: [
                      _SideNav(
                        currentIndex: _currentIndex,
                        onSelect: (i) => setState(() => _currentIndex = i),
                      ),
                      Container(
                          width: 1,
                          color: Colors.white.withValues(alpha: 0.05)),
                      Expanded(child: _screens[_currentIndex]),
                    ],
                  )
                : _screens[_currentIndex],
          ),

          if (!isWide && hasTrack && _currentIndex != 1)
            MiniPlayerBar(
              onTap: () => setState(() => _currentIndex = 1),
            ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              backgroundColor: const Color(0xFF0F0F0F),
              surfaceTintColor: Colors.transparent,
              indicatorColor: Colors.white10,
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) =>
                  setState(() => _currentIndex = i),
              labelBehavior:
                  NavigationDestinationLabelBehavior.alwaysHide,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined, size: 20),
                  selectedIcon:
                      Icon(Icons.library_music_rounded, size: 20),
                  label: 'Library',
                ),
                NavigationDestination(
                  icon: Icon(Icons.play_circle_outline, size: 20),
                  selectedIcon:
                      Icon(Icons.play_circle_rounded, size: 20),
                  label: 'Now Playing',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_outlined, size: 20),
                  selectedIcon: Icon(Icons.tune_rounded, size: 20),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }
}

class _CustomTitleBar extends StatelessWidget {
  final bool isMaximized;
  const _CustomTitleBar({required this.isMaximized});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          windowManager.unmaximize();
        } else {
          windowManager.maximize();
        }
      },
      child: Container(
        height: 38,
        color: const Color(0xFF080808),
        child: Row(
          children: [
            // Logo
            const SizedBox(width: 16),
            const Image(
              image: AssetImage('assets/icons/icon_32.png'),
              width: 20,
              height: 20,
            ),
            const SizedBox(width: 10),
            const Text(
              'AQLOSS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: Colors.white30,
                letterSpacing: 3,
              ),
            ),

            const Spacer(),

            // Window controls
            _TitleBarButton(
              icon: Icons.remove_rounded,
              tooltip: 'Minimize',
              onTap: windowManager.minimize,
            ),
            _TitleBarButton(
              icon: isMaximized
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              tooltip: isMaximized ? 'Restore' : 'Maximize',
              onTap: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
            ),
            _TitleBarButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onTap: windowManager.close,
              isClose: true,
            ),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isClose;

  const _TitleBarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isClose = false,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 42,
            height: 38,
            color: _hovered
                ? widget.isClose
                    ? const Color(0xFFE81123)
                    : Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            child: Icon(
              widget.icon,
              size: 14,
              color: _hovered && widget.isClose
                  ? Colors.white
                  : Colors.white38,
            ),
          ),
        ),
      ),
    );
  }
}

// Side Navigation
class _SideNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onSelect;

  const _SideNav({required this.currentIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: Column(
        children: [
          const SizedBox(height: 16),
          _NavIcon(
            icon: Icons.library_music_outlined,
            activeIcon: Icons.library_music_rounded,
            isActive: currentIndex == 0,
            tooltip: 'Library',
            onTap: () => onSelect(0),
          ),
          const SizedBox(height: 8),
          _NavIcon(
            icon: Icons.play_circle_outline,
            activeIcon: Icons.play_circle_rounded,
            isActive: currentIndex == 1,
            tooltip: 'Now Playing',
            onTap: () => onSelect(1),
          ),
          const Spacer(),
          _NavIcon(
            icon: Icons.tune_outlined,
            activeIcon: Icons.tune_rounded,
            isActive: currentIndex == 2,
            tooltip: 'Settings',
            onTap: () => onSelect(2),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final String tooltip;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? Colors.white10 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isActive ? activeIcon : icon,
            size: 18,
            color: isActive ? Colors.white : Colors.white30,
          ),
        ),
      ),
    );
  }
}
