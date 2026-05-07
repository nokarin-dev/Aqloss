import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter/material.dart' as theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/widgets/settings_watcher.dart';
import 'screens/home_screen.dart';

class AqlossApp extends ConsumerWidget {
  const AqlossApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final materialThemeMode = switch (settings.themeMode) {
      ThemeMode.dark => theme.ThemeMode.dark,
      ThemeMode.light => theme.ThemeMode.light,
      ThemeMode.system => theme.ThemeMode.system,
    };
    return MaterialApp(
      title: 'Aqloss',
      debugShowCheckedModeBanner: false,
      themeMode: materialThemeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: const SettingsWatcher(child: HomeScreen()),
    );
  }
}

ThemeData _buildDarkTheme() {
  const surface = Color(0xFF080808);
  const surfaceVariant = Color(0xFF0E0E0E);
  const card = Color(0xFF111111);
  const onSurface = Colors.white;
  const border = Color(0x12FFFFFF);
  const indicator = Color(0x14FFFFFF);

  return ThemeData(
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: onSurface,
      onPrimary: surface,
      secondary: onSurface,
      onSecondary: surface,
      secondaryContainer: indicator,
      onSecondaryContainer: onSurface,
      error: Color(0xFFCF6679),
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceVariant,
      outline: border,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: surface,
    cardColor: card,
    dividerColor: border,
    fontFamily: 'SF Pro Display',
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w300,
        color: onSurface,
        letterSpacing: 2,
      ),
      iconTheme: IconThemeData(color: Color(0x70FFFFFF), size: 20),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surfaceVariant,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      elevation: 0,
      height: 56,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: onSurface, size: 22);
        }
        return const IconThemeData(color: Color(0x38FFFFFF), size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          );
        }
        return const TextStyle(fontSize: 10, color: Color(0x40FFFFFF));
      }),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      minLeadingWidth: 0,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Color(0xCCFFFFFF),
      inactiveTrackColor: Color(0x16FFFFFF),
      thumbColor: onSurface,
      overlayColor: Color(0x14FFFFFF),
      trackHeight: 2,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Colors.black
            : const Color(0x40FFFFFF),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? onSurface
            : const Color(0x18FFFFFF),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: const Color(0x80FFFFFF)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: card,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

ThemeData _buildLightTheme() {
  const surface = Color(0xFFF5F5F5);
  const surfaceVariant = Color(0xFFECECEC);
  const card = Colors.white;
  const onSurface = Colors.black;
  const border = Color(0x12000000);
  const indicator = Color(0x10000000);

  return ThemeData(
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: onSurface,
      onPrimary: surface,
      secondary: onSurface,
      onSecondary: surface,
      secondaryContainer: indicator,
      onSecondaryContainer: onSurface,
      error: Color(0xFFB00020),
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceVariant,
      outline: border,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: surface,
    cardColor: card,
    dividerColor: border,
    fontFamily: 'SF Pro Display',
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w300,
        color: onSurface,
        letterSpacing: 2,
      ),
      iconTheme: IconThemeData(color: Color(0x70000000), size: 20),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surfaceVariant,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      elevation: 0,
      height: 56,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: onSurface, size: 22);
        }
        return const IconThemeData(color: Color(0x38000000), size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 10,
            color: Colors.black,
            fontWeight: FontWeight.w500,
          );
        }
        return const TextStyle(fontSize: 10, color: Color(0x40000000));
      }),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      minLeadingWidth: 0,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Color(0x99000000),
      inactiveTrackColor: Color(0x14000000),
      thumbColor: onSurface,
      overlayColor: Color(0x14000000),
      trackHeight: 2,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Colors.white
            : const Color(0x40000000),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? onSurface
            : const Color(0x18000000),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: const Color(0x80000000)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: card,
      contentTextStyle: const TextStyle(color: Colors.black, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
