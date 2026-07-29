import 'dart:async';
import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:flutter/material.dart';

class QToast {
  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _timer?.cancel();
    _current?.remove();

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(builder: (_) => _QToastWidget(message: message));

    _current = entry;
    overlay.insert(entry);

    _timer = Timer(duration, () {
      entry.remove();
      if (_current == entry) _current = null;
    });
  }
}

class _QToastWidget extends StatefulWidget {
  final String message;
  const _QToastWidget({required this.message});
  @override
  State<_QToastWidget> createState() => _QToastWidgetState();
}

class _QToastWidgetState extends State<_QToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(0, 1.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final bg = isM3 ? cs.inverseSurface : aq.onSurface.withValues(alpha: 0.88);
    final fg = isM3 ? cs.onInverseSurface : aq.surface;

    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _slide,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.message,
                style: TextStyle(
                  fontSize: 12,
                  color: fg,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
