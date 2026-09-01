import 'package:flutter/material.dart';

bool combineReduceMotion({required bool setting, required bool system}) =>
    setting || system;

Duration motionDuration(BuildContext context, Duration normal) {
  if (MediaQuery.disableAnimationsOf(context)) return Duration.zero;
  return normal;
}

class InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const InstantPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

ThemeData reduceMotionTheme(ThemeData theme) {
  return theme.copyWith(
    splashFactory: NoSplash.splashFactory,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const InstantPageTransitionsBuilder(),
      },
    ),
  );
}
