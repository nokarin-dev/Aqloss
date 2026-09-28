import 'package:aqloss/plugins/plugin_theme.dart';
import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class CustomTitleBar extends StatelessWidget {
  final bool isMaximized;
  const CustomTitleBar({super.key, required this.isMaximized});

  @override
  Widget build(BuildContext context) {
    final aq = context.aq;
    return ValueListenableBuilder<Color?>(
      valueListenable: PluginTheme.appBarColor,
      builder: (context, override, _) {
        final defaultBar = context.isMaterial3Ui
            ? Theme.of(context).colorScheme.surface
            : aq.surfaceVariant;
        final bar = override ?? defaultBar;
        final onBar = override == null
            ? aq.onSurface
            : (bar.computeLuminance() > 0.5
                  ? const Color(0xFF1A1A1A)
                  : Colors.white);
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
            height: 32,
            color: bar,
            child: Row(
              children: [
                const Spacer(),
                _TitleBarBtn(
                  icon: Icons.remove_rounded,
                  onTap: windowManager.minimize,
                  onBar: onBar,
                ),
                _TitleBarBtn(
                  icon: isMaximized
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  onTap: () async {
                    if (await windowManager.isMaximized()) {
                      windowManager.unmaximize();
                    } else {
                      windowManager.maximize();
                    }
                  },
                  onBar: onBar,
                ),
                _TitleBarBtn(
                  icon: Icons.close_rounded,
                  onTap: windowManager.close,
                  isClose: true,
                  onBar: onBar,
                ),
                const SizedBox(width: 2),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TitleBarBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isClose;
  final Color onBar;
  const _TitleBarBtn({
    required this.icon,
    required this.onTap,
    required this.onBar,
    this.isClose = false,
  });

  @override
  State<_TitleBarBtn> createState() => _TitleBarBtnState();
}

class _TitleBarBtnState extends State<_TitleBarBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 36,
          height: 32,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _hovered
                    ? widget.isClose
                          ? const Color(0xFFE81123)
                          : widget.onBar.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                widget.icon,
                size: 12,
                color: _hovered && widget.isClose
                    ? Colors.white
                    : widget.onBar.withValues(alpha: 0.42),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
