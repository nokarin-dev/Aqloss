import 'package:flutter_riverpod/legacy.dart';

enum AudioOutputMode { system, exclusive }

enum ThemeMode { dark, light, system }

class SettingsState {
  final AudioOutputMode outputMode;
  final double volume;
  final bool replayGainEnabled;
  final bool gaplessPlayback;
  final ThemeMode themeMode;
  final bool showBitDepthInLibrary;
  final bool scrobbleLastFm;
  final String? lastFmUsername;

  const SettingsState({
    this.outputMode = AudioOutputMode.exclusive,
    this.volume = 1.0,
    this.replayGainEnabled = false,
    this.gaplessPlayback = true,
    this.themeMode = ThemeMode.dark,
    this.showBitDepthInLibrary = true,
    this.scrobbleLastFm = false,
    this.lastFmUsername,
  });

  SettingsState copyWith({
    AudioOutputMode? outputMode,
    double? volume,
    bool? replayGainEnabled,
    bool? gaplessPlayback,
    ThemeMode? themeMode,
    bool? showBitDepthInLibrary,
    bool? scrobbleLastFm,
    String? lastFmUsername,
  }) => SettingsState(
    outputMode: outputMode ?? this.outputMode,
    volume: volume ?? this.volume,
    replayGainEnabled: replayGainEnabled ?? this.replayGainEnabled,
    gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
    themeMode: themeMode ?? this.themeMode,
    showBitDepthInLibrary: showBitDepthInLibrary ?? this.showBitDepthInLibrary,
    scrobbleLastFm: scrobbleLastFm ?? this.scrobbleLastFm,
    lastFmUsername: lastFmUsername ?? this.lastFmUsername,
  );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  void setOutputMode(AudioOutputMode mode) =>
      state = state.copyWith(outputMode: mode);

  void setVolume(double v) => state = state.copyWith(volume: v.clamp(0.0, 1.0));

  void toggleReplayGain() =>
      state = state.copyWith(replayGainEnabled: !state.replayGainEnabled);

  void toggleGapless() =>
      state = state.copyWith(gaplessPlayback: !state.gaplessPlayback);

  void setTheme(ThemeMode mode) => state = state.copyWith(themeMode: mode);

  void toggleBitDepthDisplay() => state = state.copyWith(
    showBitDepthInLibrary: !state.showBitDepthInLibrary,
  );

  void setLastFmUsername(String? username) =>
      state = state.copyWith(lastFmUsername: username);

  void toggleScrobble() =>
      state = state.copyWith(scrobbleLastFm: !state.scrobbleLastFm);
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
