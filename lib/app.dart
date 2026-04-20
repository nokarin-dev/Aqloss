import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';

class AqlossApp extends ConsumerWidget {
  const AqlossApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Aqloss',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
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
        fontFamily: 'SF Pro Display', // falls back to system sans-serif
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
          thumbColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? Colors.black
                  : Colors.white30),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? Colors.white
                  : Colors.white12),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.white54),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
