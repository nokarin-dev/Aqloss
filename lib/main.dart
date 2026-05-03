import 'package:aqloss/src/rust/frb_generated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform;
import 'app.dart';
import 'services/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Platform.isAndroid && !Platform.isIOS) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1100, 700),
        minimumSize: Size(1100, 700),
        center: true,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
        skipTaskbar: false,
        title: 'Aqloss',
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  await AqlossCore.init();
  runApp(const ProviderScope(child: AqlossApp()));

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final (deviceId, exclusive) = await _loadAudioPrefs();
    await AudioService.init(deviceId: deviceId, exclusive: exclusive);
  });
}

Future<(String?, bool)> _loadAudioPrefs() async {
  try {
    final p = await SharedPreferences.getInstance();
    final deviceId = p.getString('aqloss_selected_device_id');
    final modeIdx = p.getInt('aqloss_output_mode') ?? 1;
    final exclusive = modeIdx == 1;
    return (deviceId, exclusive);
  } catch (_) {
    return (null, true);
  }
}
