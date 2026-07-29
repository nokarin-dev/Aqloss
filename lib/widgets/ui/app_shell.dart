import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:flutter/material.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final Color? color;

  const AppShell({super.key, required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    final bg =
        color ??
        (context.isMaterial3Ui
            ? Theme.of(context).colorScheme.surface
            : context.aq.surface);

    return Material(color: bg, child: child);
  }
}
