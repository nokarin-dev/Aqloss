import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:flutter/material.dart';

ThemeData buildStandaloneTheme({
  required Brightness brightness,
  Color? accent,
}) {
  final tokens = brightness == Brightness.dark
      ? AqlossTokens.dark
      : AqlossTokens.light;
  final primary = accent ?? tokens.primary;
  final onPrimary = accent != null ? Colors.white : tokens.onSurface;

  final scheme =
      ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(
        primary: primary,
        onPrimary: onPrimary,
        secondary: primary,
        onSecondary: onPrimary,
        surface: tokens.surface,
        onSurface: tokens.onSurface,
        onSurfaceVariant: tokens.onSurfaceMuted,
        surfaceContainerLowest: tokens.surface,
        surfaceContainerLow: tokens.surface,
        surfaceContainer: tokens.surfaceVariant,
        surfaceContainerHigh: tokens.card,
        surfaceContainerHighest: tokens.surfaceVariant,
        outline: tokens.border,
        outlineVariant: tokens.border,
        secondaryContainer: tokens.indicator,
        onSecondaryContainer: tokens.onSurface,
        error: const Color(0xFFCF6679),
        onError: Colors.white,
      );

  final textTheme =
      (brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light())
          .textTheme
          .apply(
            bodyColor: tokens.onSurface,
            displayColor: tokens.onSurface,
            decoration: TextDecoration.none,
            decorationColor: Colors.transparent,
          );

  return ThemeData(
    useMaterial3: false,
    brightness: brightness,
    scaffoldBackgroundColor: tokens.surface,
    cardColor: tokens.card,
    dividerColor: tokens.border,
    extensions: [tokens.copyWith(primary: primary)],
    colorScheme: scheme,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.surface,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w300,
        color: tokens.onSurface,
        letterSpacing: 2,
      ),
      iconTheme: IconThemeData(color: tokens.onSurfaceMuted, size: 20),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: tokens.onSurface.withValues(alpha: 0.8),
      inactiveTrackColor: tokens.onSurface.withValues(alpha: 0.09),
      thumbColor: tokens.onSurface,
      overlayColor: tokens.onSurface.withValues(alpha: 0.08),
      trackHeight: 2,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Colors.black
            : tokens.onSurface.withValues(alpha: 0.25),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? tokens.onSurface
            : tokens.onSurface.withValues(alpha: 0.09),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tokens.onSurface.withValues(alpha: 0.5),
        enabledMouseCursor: SystemMouseCursors.click,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(enabledMouseCursor: SystemMouseCursors.click),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: tokens.card),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: tokens.card,
      contentTextStyle: TextStyle(color: tokens.onSurface, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(2.5),
      radius: const Radius.circular(99),
      crossAxisMargin: 4,
      mainAxisMargin: 4,
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.dragged) ||
            states.contains(WidgetState.hovered)) {
          return tokens.onSurface.withValues(alpha: 0.31);
        }
        return tokens.onSurface.withValues(alpha: 0.12);
      }),
      trackColor: WidgetStateProperty.all(Colors.transparent),
      trackBorderColor: WidgetStateProperty.all(Colors.transparent),
      interactive: true,
    ),
  );
}
