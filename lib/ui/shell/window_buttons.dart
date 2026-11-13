import 'dart:io';

import 'package:aqloss/l10n/l10n.dart';
import 'package:aqloss/ui/shell/glass.dart';
import 'package:aqloss/util/window_controls.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowButtons extends StatelessWidget {
  final bool compact;

  const WindowButtons({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final desktop = !Platform.isAndroid && !Platform.isIOS;
    final set = windowControlSet(
      desktop: desktop,
      platform: Platform.operatingSystem,
      env: Platform.environment,
    );
    final size = compact ? 20.0 : 30.0;
    final buttons = <Widget>[
      if (set.minimize)
        _Button(
          tooltip: tr('window.minimize'),
          icon: CupertinoIcons.minus,
          size: size,
          iconSize: compact ? 11 : 14,
          onPressed: windowManager.minimize,
        ),
      if (set.maximize)
        _Button(
          tooltip: tr('window.maximize'),
          icon: CupertinoIcons.square,
          size: size,
          iconSize: compact ? 11 : 14,
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
      if (set.close)
        _Button(
          tooltip: tr('window.close'),
          icon: CupertinoIcons.xmark,
          size: size,
          iconSize: compact ? 11 : 14,
          onPressed: windowManager.close,
        ),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return ShellLens(
      radius: compact ? 10 : 999,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 2)
          : const EdgeInsets.all(3),
      child: Row(mainAxisSize: MainAxisSize.min, children: buttons),
    );
  }
}

class _Button extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback onPressed;

  const _Button({
    required this.tooltip,
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      icon: Icon(icon, size: iconSize, color: Colors.white),
    );
  }
}
