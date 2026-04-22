import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AudioOutputMode { system, exclusive }

enum ThemeMode { dark, light, system }

const _kOutputMode = 'aqloss_output_mode';
const _kReplayGain = 'aqloss_replay_gain';
const _kGapless = 'aqloss_gapless';
const _kTheme = 'aqloss_theme';
const _kShowBitDepth = 'aqloss_show_bit_depth';
const _kScrobble = 'aqloss_scrobble';
const _kLastFmUser = 'aqloss_lastfm_user';
const _kEqEnabled = 'aqloss_eq_enabled';

class SettingsState {
  final AudioOutputMode outputMode;
  final double volume;
  final bool replayGainEnabled;
  final bool gaplessPlayback;
  final ThemeMode themeMode;
  final bool showBitDepthInLibrary;
  final bool scrobbleLastFm;
  final String? lastFmUsername;
  final bool eqEnabled;
  final bool loaded;

  const SettingsState({
    this.outputMode = AudioOutputMode.exclusive,
    this.volume = 1.0,
    this.replayGainEnabled = false,
    this.gaplessPlayback = true,
    this.themeMode = ThemeMode.dark,
    this.showBitDepthInLibrary = true,
    this.scrobbleLastFm = false,
    this.lastFmUsername,
    this.eqEnabled = false,
    this.loaded = false,
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
    bool? eqEnabled,
    bool? loaded,
  }) => SettingsState(
    outputMode: outputMode ?? this.outputMode,
    volume: volume ?? this.volume,
    replayGainEnabled: replayGainEnabled ?? this.replayGainEnabled,
    gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
    themeMode: themeMode ?? this.themeMode,
    showBitDepthInLibrary: showBitDepthInLibrary ?? this.showBitDepthInLibrary,
    scrobbleLastFm: scrobbleLastFm ?? this.scrobbleLastFm,
    lastFmUsername: lastFmUsername ?? this.lastFmUsername,
    eqEnabled: eqEnabled ?? this.eqEnabled,
    loaded: loaded ?? this.loaded,
  );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  // Persistence
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final outputIdx = p.getInt(_kOutputMode) ?? AudioOutputMode.exclusive.index;
    final themeIdx = p.getInt(_kTheme) ?? ThemeMode.dark.index;
    state = state.copyWith(
      outputMode: AudioOutputMode
          .values[outputIdx.clamp(0, AudioOutputMode.values.length - 1)],
      replayGainEnabled: p.getBool(_kReplayGain) ?? false,
      gaplessPlayback: p.getBool(_kGapless) ?? true,
      themeMode:
          ThemeMode.values[themeIdx.clamp(0, ThemeMode.values.length - 1)],
      showBitDepthInLibrary: p.getBool(_kShowBitDepth) ?? true,
      scrobbleLastFm: p.getBool(_kScrobble) ?? false,
      lastFmUsername: p.getString(_kLastFmUser),
      eqEnabled: p.getBool(_kEqEnabled) ?? false,
      loaded: true,
    );
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kOutputMode, state.outputMode.index);
    await p.setBool(_kReplayGain, state.replayGainEnabled);
    await p.setBool(_kGapless, state.gaplessPlayback);
    await p.setInt(_kTheme, state.themeMode.index);
    await p.setBool(_kShowBitDepth, state.showBitDepthInLibrary);
    await p.setBool(_kScrobble, state.scrobbleLastFm);
    if (state.lastFmUsername != null) {
      await p.setString(_kLastFmUser, state.lastFmUsername!);
    } else {
      await p.remove(_kLastFmUser);
    }
    await p.setBool(_kEqEnabled, state.eqEnabled);
  }

  // Setters
  void setOutputMode(AudioOutputMode mode) {
    state = state.copyWith(outputMode: mode);
    _save();
  }

  void setVolume(double v) => state = state.copyWith(volume: v.clamp(0.0, 1.0));

  void toggleReplayGain() {
    state = state.copyWith(replayGainEnabled: !state.replayGainEnabled);
    _save();
  }

  void toggleGapless() {
    state = state.copyWith(gaplessPlayback: !state.gaplessPlayback);
    _save();
  }

  void setTheme(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _save();
  }

  void toggleBitDepthDisplay() {
    state = state.copyWith(showBitDepthInLibrary: !state.showBitDepthInLibrary);
    _save();
  }

  void setLastFmUsername(String? username) {
    state = state.copyWith(lastFmUsername: username);
    _save();
  }

  void toggleScrobble() {
    state = state.copyWith(scrobbleLastFm: !state.scrobbleLastFm);
    _save();
  }

  void toggleEq() {
    state = state.copyWith(eqEnabled: !state.eqEnabled);
    _save();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
