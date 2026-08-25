import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

/// Press scale, hover, and haptic used across Material 3 screens.
class M3Pressable extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final String? semanticLabel;
  final bool enabled;
  final bool ink;

  const M3Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
    this.semanticLabel,
    this.enabled = true,
    this.ink = true,
  });

  @override
  Widget build(BuildContext context) {
    return M3ETappable(
      onTap: onTap,
      onLongPress: onLongPress,
      enabled: enabled && (onTap != null || onLongPress != null),
      pressedScale: pressedScale,
      haptic: M3EHapticFeedback.light,
      mouseCursor: SystemMouseCursors.click,
      semanticLabel: semanticLabel,
      materialInk: ink,
      builder: (context, state) => child,
    );
  }
}
