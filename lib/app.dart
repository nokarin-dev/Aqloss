import 'dart:async';
import 'dart:io';
import 'package:aqloss/plugins/plugin_api.dart';
import 'package:aqloss/plugins/plugin_registry.dart';
import 'package:aqloss/services/file_open_service.dart';
import 'package:aqloss/services/tray_service.dart';
import 'package:aqloss/theme/standalone_theme.dart';
import 'package:aqloss/util/reduce_motion.dart';
import 'package:aqloss/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/window_chrome_provider.dart';
import 'package:aqloss/app/settings_watcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aqloss/ui/shell/app_shell.dart';

bool get _isLinux => Platform.isLinux;
bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

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
    if (_isDesktop) {
      windowManager.addListener(this);
    }
    if (_isLinux) {
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
    if (_isDesktop) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PluginRegistry.instance.dispatchAppForeground(const AppForegroundEvent());
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(playerProvider.notifier).persistPlayback();
    }
  }

  @override
  void onWindowClose() {
    unawaited(_handleWindowClose());
  }

  Future<void> _handleWindowClose() async {
    ref.read(playerProvider.notifier).persistPlayback();
    if (!_isDesktop) return;
    if (TrayService.instance.isQuitting) return;
    if (ref.read(settingsProvider).closeToTray) {
      await TrayService.instance.hideToTray();
      return;
    }
    await TrayService.instance.quitApp();
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
    final catalog =
        ref.watch(l10nCatalogProvider).asData?.value ?? L10nCatalog.empty;
    final language = resolveLanguage(
      preference: settings.language,
      systemCode: View.of(context).platformDispatcher.locale.languageCode,
      available: catalog.codes,
    );
    final english = catalog.tableFor('en');
    AppCopy.apply(
      catalog.tableFor(language),
      english: english.isEmpty ? null : english,
    );
    final navKey = FileOpenService.instance.navigatorKey;

    final linuxFlush =
        _isLinux && (ref.watch(windowFlushProvider) || _isMaximize);
    final isWindowedLinux = _isLinux && !linuxFlush;

    return _AqlossMaterialApp(
      settings: settings,
      navKey: navKey,
      isWindowedLinux: isWindowedLinux,
      language: language,
    );
  }
}

class _AqlossMaterialApp extends StatelessWidget {
  final SettingsState settings;
  final GlobalKey<NavigatorState> navKey;
  final bool isWindowedLinux;
  final String language;

  const _AqlossMaterialApp({
    required this.settings,
    required this.navKey,
    required this.isWindowedLinux,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final darkTheme = buildStandaloneTheme(brightness: Brightness.dark);

    return MaterialApp(
      color: Colors.transparent,
      title: 'Aqloss',
      debugShowCheckedModeBanner: false,
      locale: _materialLocale(language),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: ThemeMode.dark,
      theme: darkTheme,
      darkTheme: darkTheme,
      navigatorKey: navKey,
      builder: (context, child) {
        final reduce = combineReduceMotion(
          setting: settings.reduceMotion,
          system: MediaQuery.disableAnimationsOf(context),
        );
        Widget content = child ?? const SizedBox.shrink();
        if (reduce) {
          content = MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Theme(
              data: reduceMotionTheme(Theme.of(context)),
              child: content,
            ),
          );
        }

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
                child: Material(color: Colors.transparent, child: content),
              ),
            ),
          );
        }

        return ClipRRect(
          borderRadius: radius,
          child: Material(color: Colors.transparent, child: content),
        );
      },
      home: const SettingsWatcher(child: AppShell()),
    );
  }
}

Locale _materialLocale(String language) {
  final supported =
      kMaterialSupportedLanguages.contains(language) &&
      kCupertinoSupportedLanguages.contains(language) &&
      kWidgetsSupportedLanguages.contains(language);
  if (supported) return Locale(language);
  return const Locale('en');
}
