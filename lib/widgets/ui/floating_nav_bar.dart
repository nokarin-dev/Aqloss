import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:flutter/material.dart';

class FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const _destinations = [
    (
      Icons.play_circle_outline_rounded,
      Icons.play_circle_rounded,
      'Now Playing',
    ),
    (Icons.library_music_outlined, Icons.library_music_rounded, 'Library'),
    (Icons.album_outlined, Icons.album_rounded, 'Albums'),
    (Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
    (Icons.more_horiz_rounded, Icons.more_horiz_rounded, 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;

    final bg = isM3 ? cs.surfaceContainerHigh : aq.surfaceVariant;
    final shadow = isM3
        ? cs.shadow.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.35);
    final indicator = isM3
        ? cs.secondaryContainer.withValues(alpha: 0.72)
        : aq.onSurface.withValues(alpha: 0.10);
    final selected = isM3 ? cs.onSecondaryContainer : aq.onSurface;
    final unselected = isM3
        ? cs.onSurfaceVariant
        : aq.onSurface.withValues(alpha: 0.32);

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, 10 + bottom),
      child: Material(
        elevation: 6,
        shadowColor: shadow,
        color: bg,
        surfaceTintColor: isM3 ? cs.surfaceTint : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.transparent,
              elevation: 0,
              height: 58,
              indicatorColor: indicator,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
              iconTheme: WidgetStateProperty.resolveWith((states) {
                return IconThemeData(
                  size: 22,
                  color: states.contains(WidgetState.selected)
                      ? selected
                      : unselected,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.$1),
                    selectedIcon: Icon(d.$2),
                    label: d.$3,
                    tooltip: d.$3,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
