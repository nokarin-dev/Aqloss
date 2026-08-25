import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/ui/m3/m3_pressable.dart';
import 'package:flutter/material.dart';

class UiPage extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  const UiPage({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg =
        backgroundColor ??
        (context.isMaterial3Ui
            ? Theme.of(context).colorScheme.surface
            : context.aq.surface);

    if (context.isMaterial3Ui) {
      return Scaffold(
        backgroundColor: bg,
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
      );
    }

    return Material(
      color: bg,
      child: Column(
        children: [
          ?appBar,
          Expanded(child: body),
          ?bottomNavigationBar,
        ],
      ),
    );
  }
}

class UiSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final BorderRadius? borderRadius;
  final BoxBorder? border;

  const UiSurface({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.borderRadius,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isMaterial3Ui) {
      return Card(
        margin: EdgeInsets.zero,
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      );
    }

    final aq = context.aq;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? aq.card,
        borderRadius: borderRadius ?? BorderRadius.circular(10),
        border: border ?? Border.all(color: aq.border),
      ),
      child: child,
    );
  }
}

class UiDivider extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry? margin;

  const UiDivider({super.key, this.height = 1, this.margin});

  @override
  Widget build(BuildContext context) {
    if (context.isMaterial3Ui) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: Divider(height: height),
      );
    }

    return Container(height: height, margin: margin, color: context.aq.border);
  }
}

class UiListTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  const UiListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isMaterial3Ui) {
      return M3Pressable(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ListTile(
          leading: leading,
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle!) : null,
          trailing: trailing,
          selected: selected,
        ),
      );
    }

    final aq = context.aq;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: aq.onSurface.withValues(
                          alpha: selected ? 0.95 : 0.88,
                        ),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: aq.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class UiSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const UiSectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    if (context.isMaterial3Ui) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ?trailing,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500,
                color: context.aq.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

Future<T?> showUiDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  List<Widget>? actions,
}) {
  if (context.isMaterial3Ui) {
    return showDialog<T>(
      context: context,
      builder: (ctx) =>
          AlertDialog(title: Text(title), content: content, actions: actions),
    );
  }

  final aq = context.aq;
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: aq.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: aq.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            content,
            if (actions != null) ...[
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
            ],
          ],
        ),
      ),
    ),
  );
}
