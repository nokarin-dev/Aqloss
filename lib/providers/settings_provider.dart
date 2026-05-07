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
const _kLastFmApiKey = 'aqloss_lastfm_api_key';
const _kLastFmApiSecret = 'aqloss_lastfm_api_secret';
const _kLastFmSession = 'aqloss_lastfm_session';
const _kEqEnabled = 'aqloss_eq_enabled';
const _kEqGains = 'aqloss_eq_gains';
const _kNotchFilter = 'aqloss_notch_filter';
const _kSkipSilence = 'aqloss_skip_silence';
const _kShowAlbumArtBg = 'aqloss_album_art_bg';
const _kSpectrumEnabled = 'aqloss_spectrum';
const _kSpectrumStyle = 'aqloss_spectrum_style';

class SettingsState {
  final AudioOutputMode outputMode;
  final String? selectedDeviceId;
  final double volume;
  final bool gaplessPlayback;
  final CrossfadeMode crossfade;
  final ReplayGainMode replayGainMode;
  final double replayGainPreamp;
  final bool skipSilence;
  final StopAfterMode stopAfter;
  final bool eqEnabled;
  final List<double> eqGains;
  final bool notchFilter;
  final ThemeMode themeMode;
  final bool showBitDepthInLibrary;
  final bool showAlbumArtBackground;
  final bool spectrumEnabled;
  final int spectrumStyle;
  final bool scrobbleLastFm;
  final String? lastFmUsername;
  final String? lastFmApiKey;
  final String? lastFmApiSecret;
  final String? lastFmSessionKey;
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
    this.eqGains = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    this.notchFilter = true,
    this.themeMode = ThemeMode.dark,
    this.showBitDepthInLibrary = true,
    this.showAlbumArtBackground = true,
    this.spectrumEnabled = true,
    this.spectrumStyle = 0,
    this.scrobbleLastFm = false,
    this.lastFmUsername,
    this.lastFmApiKey,
    this.lastFmApiSecret,
    this.lastFmSessionKey,
    this.loaded = false,
  });

  bool get replayGainEnabled => replayGainMode != ReplayGainMode.off;
  bool get crossfadeEnabled => crossfade != CrossfadeMode.off;
  bool get scrobbleReady => scrobbleLastFm && lastFmSessionKey != null;

  // True if build-time key was injected via --dart-define
  bool get hasBuiltInKey => const String.fromEnvironment(
    'LASTFM_API_KEY',
    defaultValue: '',
  ).isNotEmpty;

  // True if user must provide their own API key
  bool get needsUserKey =>
      !hasBuiltInKey && (lastFmApiKey == null || lastFmApiKey!.isEmpty);

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
    List<double>? eqGains,
    bool? notchFilter,
    ThemeMode? themeMode,
    bool? showBitDepthInLibrary,
    bool? showAlbumArtBackground,
    bool? spectrumEnabled,
    int? spectrumStyle,
    bool? scrobbleLastFm,
    String? lastFmUsername,
    String? lastFmApiKey,
    String? lastFmApiSecret,
    String? lastFmSessionKey,
    bool clearSession = false,
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
    eqGains: eqGains ?? this.eqGains,
    notchFilter: notchFilter ?? this.notchFilter,
    themeMode: themeMode ?? this.themeMode,
    showBitDepthInLibrary: showBitDepthInLibrary ?? this.showBitDepthInLibrary,
    showAlbumArtBackground:
        showAlbumArtBackground ?? this.showAlbumArtBackground,
    spectrumEnabled: spectrumEnabled ?? this.spectrumEnabled,
    spectrumStyle: spectrumStyle ?? this.spectrumStyle,
    scrobbleLastFm: scrobbleLastFm ?? this.scrobbleLastFm,
    lastFmUsername: lastFmUsername ?? this.lastFmUsername,
    lastFmApiKey: lastFmApiKey ?? this.lastFmApiKey,
    lastFmApiSecret: lastFmApiSecret ?? this.lastFmApiSecret,
    lastFmSessionKey: clearSession
        ? null
        : (lastFmSessionKey ?? this.lastFmSessionKey),
    loaded: loaded ?? this.loaded,
  );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final rawGains = p.getStringList(_kEqGains);
    final eqGains = rawGains != null
        ? rawGains.map((s) => double.tryParse(s) ?? 0.0).take(10).toList()
        : List<double>.filled(10, 0.0);

    state = state.copyWith(
      outputMode:
          AudioOutputMode.values[(p.getInt(_kOutputMode) ??
                  AudioOutputMode.exclusive.index)
              .clamp(0, AudioOutputMode.values.length - 1)],
      selectedDeviceId: p.getString(_kSelectedDeviceId),
      gaplessPlayback: p.getBool(_kGapless) ?? true,
      crossfade: CrossfadeMode.values[(p.getInt(_kCrossfade) ?? 0).clamp(0, 3)],
      replayGainMode:
          ReplayGainMode.values[(p.getInt(_kReplayGain) ?? 0).clamp(0, 3)],
      replayGainPreamp: (p.getDouble(_kReplayGainPreamp) ?? 0.0).clamp(-12, 12),
      skipSilence: p.getBool(_kSkipSilence) ?? false,
      stopAfter: StopAfterMode.values[(p.getInt(_kStopAfter) ?? 0).clamp(0, 2)],
      eqEnabled: p.getBool(_kEqEnabled) ?? false,
      eqGains: eqGains,
      notchFilter: p.getBool(_kNotchFilter) ?? true,
      themeMode: ThemeMode.values[(p.getInt(_kTheme) ?? 0).clamp(0, 2)],
      showBitDepthInLibrary: p.getBool(_kShowBitDepth) ?? true,
      showAlbumArtBackground: p.getBool(_kShowAlbumArtBg) ?? true,
      spectrumEnabled: p.getBool(_kSpectrumEnabled) ?? true,
      spectrumStyle: (p.getInt(_kSpectrumStyle) ?? 0).clamp(0, 2),
      scrobbleLastFm: p.getBool(_kScrobble) ?? false,
      lastFmUsername: p.getString(_kLastFmUser),
      lastFmApiKey: p.getString(_kLastFmApiKey),
      lastFmApiSecret: p.getString(_kLastFmApiSecret),
      lastFmSessionKey: p.getString(_kLastFmSession),
      loaded: true,
    );
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setInt(_kOutputMode, state.outputMode.index),
      state.selectedDeviceId != null
          ? p.setString(_kSelectedDeviceId, state.selectedDeviceId!)
          : p.remove(_kSelectedDeviceId),
      p.setBool(_kGapless, state.gaplessPlayback),
      p.setInt(_kCrossfade, state.crossfade.index),
      p.setInt(_kReplayGain, state.replayGainMode.index),
      p.setDouble(_kReplayGainPreamp, state.replayGainPreamp),
      p.setBool(_kSkipSilence, state.skipSilence),
      p.setInt(_kStopAfter, state.stopAfter.index),
      p.setBool(_kEqEnabled, state.eqEnabled),
      p.setStringList(
        _kEqGains,
        state.eqGains.map((g) => g.toString()).toList(),
      ),
      p.setBool(_kNotchFilter, state.notchFilter),
      p.setInt(_kTheme, state.themeMode.index),
      p.setBool(_kShowBitDepth, state.showBitDepthInLibrary),
      p.setBool(_kShowAlbumArtBg, state.showAlbumArtBackground),
      p.setBool(_kSpectrumEnabled, state.spectrumEnabled),
      p.setInt(_kSpectrumStyle, state.spectrumStyle),
      p.setBool(_kScrobble, state.scrobbleLastFm),
      state.lastFmUsername != null
          ? p.setString(_kLastFmUser, state.lastFmUsername!)
          : p.remove(_kLastFmUser),
      state.lastFmApiKey != null
          ? p.setString(_kLastFmApiKey, state.lastFmApiKey!)
          : p.remove(_kLastFmApiKey),
      state.lastFmApiSecret != null
          ? p.setString(_kLastFmApiSecret, state.lastFmApiSecret!)
          : p.remove(_kLastFmApiSecret),
      state.lastFmSessionKey != null
          ? p.setString(_kLastFmSession, state.lastFmSessionKey!)
          : p.remove(_kLastFmSession),
    ]);
  }

  void setAudioDevice(String id, AudioOutputMode mode) {
    state = state.copyWith(selectedDeviceId: id, outputMode: mode);
    _save();
  }

  void setOutputMode(AudioOutputMode m) {
    state = state.copyWith(outputMode: m);
    _save();
  }

  void setVolume(double v) {
    state = state.copyWith(volume: v.clamp(0, 1));
  }

  void toggleGapless() {
    state = state.copyWith(gaplessPlayback: !state.gaplessPlayback);
    _save();
  }

  void setCrossfade(CrossfadeMode m) {
    state = state.copyWith(crossfade: m);
    _save();
  }

  void setReplayGainMode(ReplayGainMode m) {
    state = state.copyWith(replayGainMode: m);
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

  void setStopAfter(StopAfterMode m) {
    state = state.copyWith(stopAfter: m);
    _save();
  }

  void toggleEq() {
    state = state.copyWith(eqEnabled: !state.eqEnabled);
    _save();
  }

  void toggleNotchFilter() {
    state = state.copyWith(notchFilter: !state.notchFilter);
    _save();
  }

  void setTheme(ThemeMode m) {
    state = state.copyWith(themeMode: m);
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

  void setSpectrumStyle(int s) {
    state = state.copyWith(spectrumStyle: s.clamp(0, 2));
    _save();
  }

  void toggleScrobble() {
    state = state.copyWith(scrobbleLastFm: !state.scrobbleLastFm);
    _save();
  }

  void setLastFmUsername(String? u) {
    state = state.copyWith(lastFmUsername: u);
    _save();
  }

  void setLastFmApiKey(String? k) {
    state = state.copyWith(lastFmApiKey: k);
    _save();
  }

  void setLastFmApiSecret(String? s) {
    state = state.copyWith(lastFmApiSecret: s);
    _save();
  }

  void setLastFmSession(String? key) {
    state = state.copyWith(lastFmSessionKey: key);
    _save();
  }

  void clearLastFmSession() {
    state = state.copyWith(clearSession: true);
    _save();
  }

  void setEqBand(int band, double gainDb) {
    if (band < 0 || band >= 10) return;
    final gains = List<double>.from(state.eqGains);
    gains[band] = gainDb.clamp(-12.0, 12.0);
    state = state.copyWith(eqGains: gains);
    _save();
  }

  void resetEq() {
    state = state.copyWith(eqGains: List.filled(10, 0.0));
    _save();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
