import 'package:flutter/material.dart';

class M3PageScaffold extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? toolbar;
  final Widget body;
  final List<Widget>? actions;
  final EdgeInsetsGeometry bodyPadding;

  const M3PageScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.toolbar,
    required this.body,
    this.actions,
    this.bodyPadding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isWide = MediaQuery.sizeOf(context).width > 700;

    return Material(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || toolbar != null || actions != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                isWide ? 20 : 16,
                isWide ? 16 : 12,
                isWide ? 20 : 16,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title!,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (actions != null) ...?actions,
                      ],
                    ),
                  if (toolbar != null) ...[
                    if (title != null) const SizedBox(height: 12),
                    toolbar!,
                  ],
                ],
              ),
            ),
          Expanded(
            child: Padding(padding: bodyPadding, child: body),
          ),
        ],
      ),
    );
  }
}
