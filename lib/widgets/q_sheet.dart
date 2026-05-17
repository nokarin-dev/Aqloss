import 'package:flutter/material.dart';

Future<void> showQSheet({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return Navigator.of(context).push<void>(_QSheetRoute(builder: builder));
}

class _QSheetRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;

  _QSheetRoute({required this.builder});

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.45);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _QSheetWrapper(animation: animation, child: builder(context));
  }
}

class _QSheetWrapper extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _QSheetWrapper({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );

    return Align(
      alignment: Alignment.bottomCenter,
      child: SlideTransition(
        position: slide,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border(
              top: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.07),
              ),
            ),
          ),
          child: SafeArea(top: false, child: child),
        ),
      ),
    );
  }
}
