import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AudioOutputMode { system, exclusive }

enum ThemeMode { dark, light, system }

enum ReplayGainMode { off, track, album, auto }

enum CrossfadeMode { off, short, medium, long }

enum StopAfterMode { off, track, album }

const _kOutputMode = 'aqloss_output_mode';
const _kSelectedDeviceId = 'aqloss_selected_device_id';
const _kReplayGain = 'aqloss_replay_gain';
const _kReplayGainPreamp = 'aqloss_replay_gain_preamp';
const _kGapless = 'aqloss_gapless';
const _kCrossfade = 'aqloss_crossfade';
const _kStopAfter = 'aqloss_stop_after';
const _kTheme = 'aqloss_theme';
const _kShowBitDepth = 'aqloss_show_bit_depth';
const _kScrobble = 'aqloss_scrobble';
const _kLastFmUser = 'aqloss_lastfm_user';
const _kEqEnabled = 'aqloss_eq_enabled';
const _kNotchFilter = 'aqloss_notch_filter';
const _kSkipSilence = 'aqloss_skip_silence';
const _kShowAlbumArtBg = 'aqloss_album_art_bg';
const _kSpectrumEnabled = 'aqloss_spectrum';
const _kSpectrumStyle = 'aqloss_spectrum_style';

class SettingsState {
  // Audio output
  final AudioOutputMode outputMode;
  final String? selectedDeviceId;

  // Volume
  final double volume;

  // Playback
  final bool gaplessPlayback;
  final CrossfadeMode crossfade;
  final ReplayGainMode replayGainMode;
  final double replayGainPreamp;
  final bool skipSilence;
  final StopAfterMode stopAfter;

  // EQ
  final bool eqEnabled;
  final bool notchFilter;

  // Display
  final ThemeMode themeMode;
  final bool showBitDepthInLibrary;
  final bool showAlbumArtBackground;
  final bool spectrumEnabled;
  final int spectrumStyle;

  // Last.fm
  final bool scrobbleLastFm;
  final String? lastFmUsername;

  final bool loaded;

  const SettingsState({
    this.outputMode = AudioOutputMode.exclusive,
    this.selectedDeviceId,
    this.volume = 1.0,
    this.gaplessPlayback = true,
    this.crossfade = CrossfadeMode.off,
    this.replayGainMode = ReplayGainMode.off,
    this.replayGainPreamp = 0.0,
    this.skipSilence = false,
    this.stopAfter = StopAfterMode.off,
    this.eqEnabled = false,
    this.notchFilter = true,
    this.themeMode = ThemeMode.dark,
    this.showBitDepthInLibrary = true,
    this.showAlbumArtBackground = true,
    this.spectrumEnabled = true,
    this.spectrumStyle = 0,
    this.scrobbleLastFm = false,
    this.lastFmUsername,
    this.loaded = false,
  });

  SettingsState copyWith({
    AudioOutputMode? outputMode,
    String? selectedDeviceId,
    bool clearDeviceId = false,
    double? volume,
    bool? gaplessPlayback,
    CrossfadeMode? crossfade,
    ReplayGainMode? replayGainMode,
    double? replayGainPreamp,
    bool? skipSilence,
    StopAfterMode? stopAfter,
    bool? eqEnabled,
    bool? notchFilter,
    ThemeMode? themeMode,
    bool? showBitDepthInLibrary,
    bool? showAlbumArtBackground,
    bool? spectrumEnabled,
    int? spectrumStyle,
    bool? scrobbleLastFm,
    String? lastFmUsername,
    bool? loaded,
  }) => SettingsState(
    outputMode: outputMode ?? this.outputMode,
    selectedDeviceId: clearDeviceId
        ? null
        : (selectedDeviceId ?? this.selectedDeviceId),
    volume: volume ?? this.volume,
    gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
    crossfade: crossfade ?? this.crossfade,
    replayGainMode: replayGainMode ?? this.replayGainMode,
    replayGainPreamp: replayGainPreamp ?? this.replayGainPreamp,
    skipSilence: skipSilence ?? this.skipSilence,
    stopAfter: stopAfter ?? this.stopAfter,
    eqEnabled: eqEnabled ?? this.eqEnabled,
    notchFilter: notchFilter ?? this.notchFilter,
    themeMode: themeMode ?? this.themeMode,
    showBitDepthInLibrary: showBitDepthInLibrary ?? this.showBitDepthInLibrary,
    showAlbumArtBackground:
        showAlbumArtBackground ?? this.showAlbumArtBackground,
    spectrumEnabled: spectrumEnabled ?? this.spectrumEnabled,
    spectrumStyle: spectrumStyle ?? this.spectrumStyle,
    scrobbleLastFm: scrobbleLastFm ?? this.scrobbleLastFm,
    lastFmUsername: lastFmUsername ?? this.lastFmUsername,
    loaded: loaded ?? this.loaded,
  );

  // Helpers
  bool get replayGainEnabled => replayGainMode != ReplayGainMode.off;
  bool get crossfadeEnabled => crossfade != CrossfadeMode.off;
  double get crossfadeSecs {
    switch (crossfade) {
      case CrossfadeMode.short:
        return 2.0;
      case CrossfadeMode.medium:
        return 4.0;
      case CrossfadeMode.long:
        return 8.0;
      case CrossfadeMode.off:
        return 0.0;
    }
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = state.copyWith(
      outputMode:
          AudioOutputMode.values[(p.getInt(_kOutputMode) ??
                  AudioOutputMode.exclusive.index)
              .clamp(0, AudioOutputMode.values.length - 1)],
      selectedDeviceId: p.getString(_kSelectedDeviceId),
      gaplessPlayback: p.getBool(_kGapless) ?? true,
      crossfade:
          CrossfadeMode.values[(p.getInt(_kCrossfade) ?? 0).clamp(
            0,
            CrossfadeMode.values.length - 1,
          )],
      replayGainMode:
          ReplayGainMode.values[(p.getInt(_kReplayGain) ?? 0).clamp(
            0,
            ReplayGainMode.values.length - 1,
          )],
      replayGainPreamp: (p.getDouble(_kReplayGainPreamp) ?? 0.0).clamp(-12, 12),
      skipSilence: p.getBool(_kSkipSilence) ?? false,
      stopAfter:
          StopAfterMode.values[(p.getInt(_kStopAfter) ?? 0).clamp(
            0,
            StopAfterMode.values.length - 1,
          )],
      eqEnabled: p.getBool(_kEqEnabled) ?? false,
      notchFilter: p.getBool(_kNotchFilter) ?? true,
      themeMode:
          ThemeMode.values[(p.getInt(_kTheme) ?? 0).clamp(
            0,
            ThemeMode.values.length - 1,
          )],
      showBitDepthInLibrary: p.getBool(_kShowBitDepth) ?? true,
      showAlbumArtBackground: p.getBool(_kShowAlbumArtBg) ?? true,
      spectrumEnabled: p.getBool(_kSpectrumEnabled) ?? true,
      spectrumStyle: (p.getInt(_kSpectrumStyle) ?? 0).clamp(0, 2),
      scrobbleLastFm: p.getBool(_kScrobble) ?? false,
      lastFmUsername: p.getString(_kLastFmUser),
      loaded: true,
    );
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setInt(_kOutputMode, state.outputMode.index),
      if (state.selectedDeviceId != null)
        p.setString(_kSelectedDeviceId, state.selectedDeviceId!)
      else
        p.remove(_kSelectedDeviceId),
      p.setBool(_kGapless, state.gaplessPlayback),
      p.setInt(_kCrossfade, state.crossfade.index),
      p.setInt(_kReplayGain, state.replayGainMode.index),
      p.setDouble(_kReplayGainPreamp, state.replayGainPreamp),
      p.setBool(_kSkipSilence, state.skipSilence),
      p.setInt(_kStopAfter, state.stopAfter.index),
      p.setBool(_kEqEnabled, state.eqEnabled),
      p.setBool(_kNotchFilter, state.notchFilter),
      p.setInt(_kTheme, state.themeMode.index),
      p.setBool(_kShowBitDepth, state.showBitDepthInLibrary),
      p.setBool(_kShowAlbumArtBg, state.showAlbumArtBackground),
      p.setBool(_kSpectrumEnabled, state.spectrumEnabled),
      p.setInt(_kSpectrumStyle, state.spectrumStyle),
      p.setBool(_kScrobble, state.scrobbleLastFm),
      if (state.lastFmUsername != null)
        p.setString(_kLastFmUser, state.lastFmUsername!)
      else
        p.remove(_kLastFmUser),
    ]);
  }

  // Audio output
  void setAudioDevice(String deviceId, AudioOutputMode mode) {
    state = state.copyWith(selectedDeviceId: deviceId, outputMode: mode);
    _save();
  }

  void setOutputMode(AudioOutputMode mode) {
    state = state.copyWith(outputMode: mode);
    _save();
  }

  // Playback
  void setVolume(double v) => state = state.copyWith(volume: v.clamp(0.0, 1.0));

  void toggleGapless() {
    state = state.copyWith(gaplessPlayback: !state.gaplessPlayback);
    _save();
  }

  void setCrossfade(CrossfadeMode mode) {
    state = state.copyWith(crossfade: mode);
    _save();
  }

  void setReplayGainMode(ReplayGainMode mode) {
    state = state.copyWith(replayGainMode: mode);
    _save();
  }

  void setReplayGainPreamp(double db) {
    state = state.copyWith(replayGainPreamp: db.clamp(-12, 12));
    _save();
  }

  void toggleSkipSilence() {
    state = state.copyWith(skipSilence: !state.skipSilence);
    _save();
  }

  void setStopAfter(StopAfterMode mode) {
    state = state.copyWith(stopAfter: mode);
    _save();
  }

  // EQ / DSP
  void toggleEq() {
    state = state.copyWith(eqEnabled: !state.eqEnabled);
    _save();
  }

  void toggleNotchFilter() {
    state = state.copyWith(notchFilter: !state.notchFilter);
    _save();
  }

  // Display
  void setTheme(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _save();
  }

  void toggleBitDepthDisplay() {
    state = state.copyWith(showBitDepthInLibrary: !state.showBitDepthInLibrary);
    _save();
  }

  void toggleAlbumArtBackground() {
    state = state.copyWith(
      showAlbumArtBackground: !state.showAlbumArtBackground,
    );
    _save();
  }

  void toggleSpectrum() {
    state = state.copyWith(spectrumEnabled: !state.spectrumEnabled);
    _save();
  }

  void setSpectrumStyle(int style) {
    state = state.copyWith(spectrumStyle: style.clamp(0, 2));
    _save();
  }

  // Last.fm
  void toggleScrobble() {
    state = state.copyWith(scrobbleLastFm: !state.scrobbleLastFm);
    _save();
  }

  void setLastFmUsername(String? username) {
    state = state.copyWith(lastFmUsername: username);
    _save();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
