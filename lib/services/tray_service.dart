import 'dart:io';

import 'package:aqloss/util/logger.dart';
import 'package:aqloss/util/tray.dart';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener {
  TrayService._();
  static final TrayService instance = TrayService._();

  bool _ready = false;
  bool _quitting = false;
  Future<void>? _starting;
  VoidCallback? onShow;
  VoidCallback? onPlayPause;
  VoidCallback? onNext;
  VoidCallback? onPrevious;
  VoidCallback? onQuit;

  bool get isQuitting => _quitting;

  Future<void> init() async {
    if (_ready) return;
    if (_starting != null) {
      await _starting;
      return;
    }
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }
    final start = _doInit();
    _starting = start;
    try {
      await start;
    } finally {
      _starting = null;
    }
  }

  Future<void> _doInit() async {
    try {
      trayManager.addListener(this);
      await trayManager.setIcon(_iconPath());
      // Linux AppIndicator shows an empty dbusmenu until this runs
      await _setMenu(playing: false);
      await _setTooltip('Aqloss');
      _ready = true;
    } catch (e, st) {
      Logger.errorFrontend('Tray init failed: $e\n$st');
      try {
        trayManager.removeListener(this);
        await trayManager.destroy();
      } catch (_) {}
    }
  }

  Future<void> sync({
    required bool playing,
    String? title,
    String? artist,
  }) async {
    await init();
    if (!_ready) return;
    try {
      await _setTooltip(trayTooltip(title: title, artist: artist));
      await _setMenu(playing: playing);
    } catch (_) {}
  }

  Future<void> _setTooltip(String text) async {
    // tray_manager has no Linux setToolTip; it would abort init
    if (Platform.isLinux) return;
    try {
      await trayManager.setToolTip(text);
    } catch (_) {}
  }

  Future<void> _setMenu({required bool playing}) async {
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: 'Show Aqloss'),
          MenuItem.separator(),
          MenuItem(key: 'play_pause', label: trayPlayPauseLabel(playing)),
          MenuItem(key: 'next', label: 'Next'),
          MenuItem(key: 'previous', label: 'Previous'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit'),
        ],
      ),
    );
  }

  Future<void> destroy() async {
    if (_starting != null) await _starting;
    if (!_ready) return;
    _ready = false;
    trayManager.removeListener(this);
    try {
      await trayManager.destroy();
    } catch (_) {}
  }

  Future<void> showWindow() async {
    try {
      await windowManager.setSkipTaskbar(false);
    } catch (_) {}
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hideToTray() async {
    await windowManager.hide();
    try {
      await windowManager.setSkipTaskbar(true);
    } catch (_) {}
  }

  Future<void> quitApp() async {
    _quitting = true;
    await destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onTrayIconMouseDown() {
    if (Platform.isMacOS) {
      trayManager.popUpContextMenu();
      return;
    }
    onShow?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    // Linux AppIndicator / StatusNotifier shows the menu itself
    if (Platform.isLinux) return;
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        onShow?.call();
      case 'play_pause':
        onPlayPause?.call();
      case 'next':
        onNext?.call();
      case 'previous':
        onPrevious?.call();
      case 'quit':
        onQuit?.call();
    }
  }

  String _iconPath() {
    if (Platform.isLinux && Platform.environment.containsKey('FLATPAK_ID')) {
      return 'xyz.nokarin.aqloss';
    }
    if (Platform.isWindows) return 'assets/icons/app_icon.ico';
    return 'assets/icons/icon_32.png';
  }
}
