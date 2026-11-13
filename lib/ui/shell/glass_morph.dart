import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'glass.dart';

// Open a morphing menu from a screen point
Future<void> showShellMorph({
  required BuildContext context,
  required Offset origin,
  required WidgetBuilder menu,
  LiquidGlassMorphMotion motion = LiquidGlassMorphMotion.anchoredPop,
}) async {
  final themes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(context, rootNavigator: true).context,
  );
  final capture = ShellCapture.read(context);
  capture?.startRealtimeCapture();
  try {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x00000000),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: Duration.zero,
      pageBuilder: (routeContext, _, _) {
        return themes.wrap(
          _MorphField(origin: origin, motion: motion, menu: menu(routeContext)),
        );
      },
      transitionBuilder: (_, _, _, child) => child,
    );
  } finally {
    capture?.stopRealtimeCapture();
  }
}

class MorphSwap extends InheritedWidget {
  final ValueChanged<Widget> replace;

  const MorphSwap({super.key, required this.replace, required super.child});

  static MorphSwap of(BuildContext context) {
    final swap = context.getInheritedWidgetOfExactType<MorphSwap>();
    assert(swap != null, 'MorphSwap is missing');
    return swap!;
  }

  @override
  bool updateShouldNotify(MorphSwap oldWidget) => replace != oldWidget.replace;
}

class ShellMenu extends StatelessWidget {
  final List<Widget> children;

  const ShellMenu({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class ShellMenuRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool selected;

  const ShellMenuRow({
    super.key,
    this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.selected = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? const Color(0xFFFF453A)
        : (selected ? Colors.white : const Color(0xFFA3A3A3));
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MorphField extends StatefulWidget {
  final Offset origin;
  final LiquidGlassMorphMotion motion;
  final Widget menu;

  const _MorphField({
    required this.origin,
    required this.motion,
    required this.menu,
  });

  @override
  State<_MorphField> createState() => _MorphFieldState();
}

class _MorphFieldState extends State<_MorphField> {
  static const _seed = SizedBox(key: ValueKey('seed'), width: 28, height: 28);

  // No button to return to. 28px with this radius rests as a circle.
  static const _gone = SizedBox(key: ValueKey('gone'), width: 0, height: 0);

  Widget _page = _seed;
  bool _closing = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _closing) return;
      setState(() => _page = widget.menu);
    });
  }

  void _replace(Widget next) {
    if (_closing) return;
    setState(() => _page = next);
  }

  // The route has to stay up. Popping it removes the morph before it can shrink.
  void _close() {
    if (_closing) return;
    setState(() {
      _closing = true;
      _page = _gone;
    });
  }

  void _onEnd() {
    if (!_closing || _allowPop || !mounted) return;
    final route = ModalRoute.of(context);
    if (route == null) return;
    final navigator = Navigator.of(context);
    setState(() => _allowPop = true);
    // removeRoute, not pop: a row may have opened another route on top.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!route.isActive) return;
      navigator.removeRoute(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _close();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screen = Size(constraints.maxWidth, constraints.maxHeight);
          final field = _field(widget.origin, screen);
          return Stack(
            children: [
              Positioned.fromRect(
                rect: field,
                child: MorphSwap(
                  replace: _replace,
                  child: LiquidGlassMorph(
                    alignment: _hold(widget.origin, screen),
                    motion: widget.motion,
                    smoothness: 28,
                    onEnd: _onEnd,
                    // Frost only. A tint or the shell capture paints black over the page.
                    style: shellGlass.copyWith(
                      shape: shellShape(18),
                      color: const Color(0x00000000),
                      liteGlass: true,
                    ),
                    child: KeyedSubtree(key: _page.key, child: _page),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

bool _growLeft(Offset origin, Size screen) {
  return screen.width - origin.dx < 280 && origin.dx > screen.width - origin.dx;
}

bool _growUp(Offset origin, Size screen) {
  return screen.height - origin.dy < 360 &&
      origin.dy > screen.height - origin.dy;
}

Rect _field(Offset origin, Size screen) {
  final left = _growLeft(origin, screen);
  final up = _growUp(origin, screen);
  final l = left ? 8.0 : origin.dx;
  final t = up ? 8.0 : origin.dy;
  final r = left ? origin.dx : screen.width - 8;
  final b = up ? origin.dy : screen.height - 8;
  return Rect.fromLTRB(l, t, math.max(l + 36, r), math.max(t + 36, b));
}

Alignment _hold(Offset origin, Size screen) {
  return Alignment(
    _growLeft(origin, screen) ? 1 : -1,
    _growUp(origin, screen) ? 1 : -1,
  );
}
