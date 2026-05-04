import 'package:aqloss/src/rust/frb_generated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform;
import 'app.dart';
import 'services/audio_service.dart';
import 'providers/settings_provider.dart';

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
    final (deviceId, exclusive, volume) = await _loadStartupPrefs();
    final prefs = await SharedPreferences.getInstance();
    final settings = await _loadSettingsState(prefs);
    await AudioService.init(
      deviceId: deviceId,
      exclusive: exclusive,
      volume: volume,
      settings: settings,
    );
  });
}

Future<(String?, bool, double)> _loadStartupPrefs() async {
  try {
    final p = await SharedPreferences.getInstance();
    final deviceId = p.getString('aqloss_selected_device_id');
    final modeIdx = p.getInt('aqloss_output_mode') ?? 1;
    final exclusive = modeIdx == 1;
    final volume = (p.getDouble('aqloss_volume') ?? 1.0).clamp(0.0, 1.0);
    return (deviceId, exclusive, volume);
  } catch (_) {
    return (null, true, 1.0);
  }
}

Future<SettingsState> _loadSettingsState(SharedPreferences p) async {
  return SettingsState(
    notchFilter: p.getBool('aqloss_notch_filter') ?? true,
    skipSilence: p.getBool('aqloss_skip_silence') ?? false,
    replayGainMode:
        ReplayGainMode.values[(p.getInt('aqloss_replay_gain') ?? 0).clamp(
          0,
          ReplayGainMode.values.length - 1,
        )],
    replayGainPreamp: (p.getDouble('aqloss_replay_gain_preamp') ?? 0.0).clamp(
      -12,
      12,
    ),
  );
}
