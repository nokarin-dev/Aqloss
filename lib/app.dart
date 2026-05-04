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

// Theme
ThemeData _buildDarkTheme() {
  const surface = Color(0xFF0A0A0A);
  const surfaceVariant = Color(0xFF0D0D0D);
  const card = Color(0xFF141414);
  const onSurface = Colors.white;
  const border = Color(0x0FFFFFFF);
  const indicator = Color(0x1AFFFFFF);

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
        fontSize: 15,
        fontWeight: FontWeight.w300,
        color: onSurface,
        letterSpacing: 1.5,
      ),
      iconTheme: IconThemeData(color: Color(0x8AFFFFFF), size: 20),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surfaceVariant,
      surfaceTintColor: Colors.transparent,
      indicatorColor: indicator,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: onSurface, size: 20);
        }
        return const IconThemeData(color: Color(0x4DFFFFFF), size: 20);
      }),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 10, color: Color(0x61FFFFFF)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Color(0xB3FFFFFF),
      inactiveTrackColor: Color(0x1FFFFFFF),
      thumbColor: onSurface,
      overlayColor: Color(0x1AFFFFFF),
      trackHeight: 2,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Colors.black
            : const Color(0x4DFFFFFF),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? onSurface
            : const Color(0x1FFFFFFF),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: const Color(0x8AFFFFFF)),
    ),
  );
}

ThemeData _buildLightTheme() {
  const surface = Color(0xFFF8F8F8);
  const surfaceVariant = Color(0xFFEFEFEF);
  const card = Colors.white;
  const onSurface = Colors.black;
  const border = Color(0x1A000000);
  const indicator = Color(0x1A000000);

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
        fontSize: 15,
        fontWeight: FontWeight.w300,
        color: onSurface,
        letterSpacing: 1.5,
      ),
      iconTheme: IconThemeData(color: Color(0x8A000000), size: 20),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surfaceVariant,
      surfaceTintColor: Colors.transparent,
      indicatorColor: indicator,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: onSurface, size: 20);
        }
        return const IconThemeData(color: Color(0x4D000000), size: 20);
      }),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 10, color: Color(0x61000000)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Color(0x8A000000),
      inactiveTrackColor: Color(0x1F000000),
      thumbColor: onSurface,
      overlayColor: Color(0x1F000000),
      trackHeight: 2,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Colors.white
            : const Color(0x4D000000),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? onSurface
            : const Color(0x1F000000),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: const Color(0x8A000000)),
    ),
  );
}
