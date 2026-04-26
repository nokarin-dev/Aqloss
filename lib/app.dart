import 'dart:io' show Platform;
import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter/material.dart' as theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'screens/home_screen.dart';

class AqlossApp extends ConsumerWidget {
  const AqlossApp({super.key});

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    final materialThemeMode = switch (settings.themeMode) {
      ThemeMode.dark => theme.ThemeMode.dark,
      ThemeMode.light => theme.ThemeMode.light,
      ThemeMode.system => theme.ThemeMode.system,
    };

    final home = _isDesktop
        ? ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: const HomeScreen(),
          )
        : const HomeScreen();

    return MaterialApp(
      title: 'Aqloss',
      debugShowCheckedModeBanner: false,
      themeMode: materialThemeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: _isDesktop
          ? ColoredBox(color: Colors.transparent, child: home)
          : home,
    );
  }
}

ThemeData _buildDarkTheme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1A1A1A),
    brightness: Brightness.dark,
    surface: const Color(0xFF0F0F0F),
    primary: Colors.white,
    onSurface: Colors.white,
  ),
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFF0A0A0A),
  cardColor: const Color(0xFF141414),
  dividerColor: Colors.white.withValues(alpha: 0.06),
  fontFamily: 'SF Pro Display',
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0A0A0A),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    titleTextStyle: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w300,
      color: Colors.white,
      letterSpacing: 1.5,
    ),
    iconTheme: IconThemeData(color: Colors.white54, size: 20),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: const Color(0xFF0F0F0F),
    surfaceTintColor: Colors.transparent,
    indicatorColor: Colors.white10,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(color: Colors.white, size: 20);
      }
      return const IconThemeData(color: Colors.white30, size: 20);
    }),
    labelTextStyle: WidgetStateProperty.all(
      const TextStyle(fontSize: 10, color: Colors.white38),
    ),
  ),
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
  ),
  sliderTheme: SliderThemeData(
    activeTrackColor: Colors.white70,
    inactiveTrackColor: Colors.white12,
    thumbColor: Colors.white,
    overlayColor: Colors.white10,
    trackHeight: 2,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.selected) ? Colors.black : Colors.white30,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.selected) ? Colors.white : Colors.white12,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: Colors.white54),
  ),
);

ThemeData _buildLightTheme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFE0E0E0),
    brightness: Brightness.light,
    surface: const Color(0xFFF5F5F5),
    primary: Colors.black,
    onSurface: Colors.black,
  ),
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFFF8F8F8),
  cardColor: Colors.white,
  fontFamily: 'SF Pro Display',
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFF8F8F8),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    titleTextStyle: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w300,
      color: Colors.black,
      letterSpacing: 1.5,
    ),
    iconTheme: IconThemeData(color: Colors.black54, size: 20),
  ),
  sliderTheme: SliderThemeData(
    activeTrackColor: Colors.black54,
    inactiveTrackColor: Colors.black12,
    thumbColor: Colors.black,
    overlayColor: Colors.black12,
    trackHeight: 2,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
  ),
);
