import 'dart:io';
import 'package:aqloss/plugins/plugin_api.dart';
import 'package:aqloss/plugins/plugin_registry.dart';
import 'package:aqloss/services/file_open_service.dart';
import 'package:aqloss/theme/dynamic_scheme.dart';
import 'package:aqloss/theme/material3_theme.dart';
import 'package:aqloss/theme/standalone_theme.dart';
import 'package:aqloss/theme/ui_framework.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter/material.dart' as theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/providers/accent_provider.dart';
import 'package:aqloss/providers/window_chrome_provider.dart';
import 'package:aqloss/widgets/settings_watcher.dart';
import 'package:aqloss/widgets/mini_player_window.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/home_screen.dart';

bool get _isLinux => Platform.isLinux;

class AqlossApp extends ConsumerStatefulWidget {
  const AqlossApp({super.key});

  @override
  ConsumerState<AqlossApp> createState() => _AqlossAppState();
}

class _AqlossAppState extends ConsumerState<AqlossApp>
    with WindowListener, WidgetsBindingObserver {
  bool _isMaximize = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isLinux) {
      windowManager.addListener(this);
      bindWindowChromeChannel((flush) {
        if (!mounted) return;
        if (ref.read(windowFlushProvider) == flush) return;
        ref.read(windowFlushProvider.notifier).state = flush;
      });
      _checkMaximize();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isLinux) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PluginRegistry.instance.dispatchAppForeground(const AppForegroundEvent());
    }
  }

  Future<void> _checkMaximize() async {
    if (!_isLinux) return;
    try {
      final fs = await windowManager.isMaximized();
      if (mounted) setState(() => _isMaximize = fs);
    } catch (_) {}
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximize = true);
    ref.read(windowFlushProvider.notifier).state = true;
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximize = false);
  }

  @override
  void onWindowEnterFullScreen() {
    ref.read(windowFlushProvider.notifier).state = true;
  }

  @override
  void onWindowFocus() {
    PluginRegistry.instance.dispatchAppForeground(const AppForegroundEvent());
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final navKey = FileOpenService.instance.navigatorKey;

    final linuxFlush =
        _isLinux && (ref.watch(windowFlushProvider) || _isMaximize);
    final isWindowedLinux = _isLinux && !linuxFlush;

    Color? accent;
    if (settings.accentMode != AccentMode.off) {
      accent = ref.watch(accentColorProvider);
    }

    final useM3 = settings.uiFramework == UiFramework.material3;
    final useDynamic = useM3 && settings.materialYou;

    final app = _AqlossMaterialApp(
      settings: settings,
      accent: accent,
      navKey: navKey,
      isWindowedLinux: isWindowedLinux,
    );

    if (!useDynamic) return app;

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return _AqlossMaterialApp(
          settings: settings,
          accent: accent,
          navKey: navKey,
          isWindowedLinux: isWindowedLinux,
          lightDynamic: toFlutterColorScheme(lightDynamic),
          darkDynamic: toFlutterColorScheme(darkDynamic),
        );
      },
    );
  }
}

class _AqlossMaterialApp extends StatelessWidget {
  final SettingsState settings;
  final Color? accent;
  final GlobalKey<NavigatorState> navKey;
  final bool isWindowedLinux;
  final ColorScheme? lightDynamic;
  final ColorScheme? darkDynamic;

  const _AqlossMaterialApp({
    required this.settings,
    required this.accent,
    required this.navKey,
    required this.isWindowedLinux,
    this.lightDynamic,
    this.darkDynamic,
  });

  @override
  Widget build(BuildContext context) {
    final materialThemeMode = switch (settings.themeMode) {
      ThemeMode.dark => theme.ThemeMode.dark,
      ThemeMode.light => theme.ThemeMode.light,
      ThemeMode.system => theme.ThemeMode.system,
    };

    final useM3 = settings.uiFramework == UiFramework.material3;
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final compactDesktop = useM3 && isDesktop;

    final lightTheme = useM3
        ? buildMaterial3Theme(
            brightness: Brightness.light,
            dynamicScheme: settings.materialYou ? lightDynamic : null,
            accent: accent,
            compactDesktop: compactDesktop,
          )
        : buildStandaloneTheme(brightness: Brightness.light, accent: accent);

    final darkTheme = useM3
        ? buildMaterial3Theme(
            brightness: Brightness.dark,
            dynamicScheme: settings.materialYou ? darkDynamic : null,
            accent: accent,
            compactDesktop: compactDesktop,
          )
        : buildStandaloneTheme(brightness: Brightness.dark, accent: accent);

    return MaterialApp(
      color: Colors.transparent,
      title: 'Aqloss',
      debugShowCheckedModeBanner: false,
      themeMode: materialThemeMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      navigatorKey: navKey,
      builder: (context, child) {
        final radius = isWindowedLinux
            ? BorderRadius.circular(14.0)
            : BorderRadius.zero;

        if (isWindowedLinux) {
          return Container(
            padding: const EdgeInsets.all(14.0),
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 14.0,
                    spreadRadius: 1.0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Material(color: Colors.transparent, child: child),
              ),
            ),
          );
        }

        return ClipRRect(
          borderRadius: radius,
          child: Material(color: Colors.transparent, child: child),
        );
      },
      home: const MiniPlayerOverlay(
        child: SettingsWatcher(child: HomeScreen()),
      ),
    );
  }
}
