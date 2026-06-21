import 'dart:io' show Platform;

import 'package:aqloss/src/rust/frb_generated.dart';
import 'package:aqloss/util/logger.dart';
import 'package:aqloss/widgets/mini_player_window.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'providers/settings_provider.dart';
import 'services/audio_service.dart';
import 'services/discord_service.dart';
import 'services/notifier/media_control_windows.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Platform.isAndroid && !Platform.isIOS) {
    await windowManager.ensureInitialized();
  }

  final windowController = await WindowController.fromCurrentEngine();
  final argument = windowController.arguments;

  if (argument == 'mini_player') {
    runApp(const ProviderScope(child: MiniPlayerStandalone()));
    return;
  }

  // Main window
  if (Platform.isWindows) {
    await MediaControlPlatform.initialize();
  }

  // Main window
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      size: const Size(1280, 720),
      minimumSize: const Size(1280, 720),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: Platform.isMacOS ? false : null,
      skipTaskbar: false,
      title: 'Aqloss',
      backgroundColor: Platform.isLinux ? Colors.transparent : null,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  await AqlossCore.init();
  await Logger.init();

  runApp(const ProviderScope(child: AqlossApp()));

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (Platform.isAndroid) {
      await Future.delayed(const Duration(milliseconds: 800));
    }
    try {
      final (deviceId, exclusive, volume) = await _loadStartupPrefs();
      final prefs = await SharedPreferences.getInstance();
      final settings = await _loadSettingsState(prefs);
      await AudioService.init(
        deviceId: deviceId,
        exclusive: exclusive,
        volume: volume,
        settings: settings,
      );
      DiscordService.enabled = settings.discordRpc;
    } catch (e, st) {
      Logger.errorFrontend('[aqloss] main init error: $e\n$st');
    }
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
    gaplessPlayback: p.getBool('aqloss_gapless') ?? true,
    eqEnabled: p.getBool('aqloss_eq_enabled') ?? false,
    eqGains: () {
      final raw = p.getStringList('aqloss_eq_gains');
      return raw != null
          ? raw.map((s) => double.tryParse(s) ?? 0.0).take(10).toList()
          : List<double>.filled(10, 0.0);
    }(),
    stereoWidth: (p.getDouble('aqloss_stereo_width') ?? 1.0).clamp(0.0, 2.0),
    haasMs: (p.getDouble('aqloss_haas_ms') ?? 0.0).clamp(0.0, 25.0),
    discordRpc: p.getBool('aqloss_discord_rpc') ?? true,
  );
}
