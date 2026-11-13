import 'dart:convert';
import 'dart:io' show Platform;

import 'package:aqloss/l10n/l10n.dart';
import 'package:aqloss/services/gpu_pref.dart';
import 'package:aqloss/util/eq_presets.dart';
import 'package:aqloss/util/playback_speed.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ShortcutAction {
  playPause,
  skipNext,
  skipPrevious,
  volumeUp,
  volumeDown,
  toggleSidebar,
  toggleQueue,
  navPlayer,
  navLibrary,
  navAlbums,
  navArtists,
  navHistory,
  navSettings,
  newPlaylist,
}

extension ShortcutActionX on ShortcutAction {
  String get label => switch (this) {
    ShortcutAction.playPause => tr('player.play_pause'),
    ShortcutAction.skipNext => tr('player.next_track'),
    ShortcutAction.skipPrevious => tr('player.previous_track'),
    ShortcutAction.volumeUp => tr('player.volume_up'),
    ShortcutAction.volumeDown => tr('player.volume_down'),
    ShortcutAction.toggleSidebar => tr('sidebar.toggle'),
    ShortcutAction.toggleQueue => tr('queue.toggle'),
    ShortcutAction.navPlayer => tr('sidebar.go_now_playing'),
    ShortcutAction.navLibrary => tr('sidebar.go_library'),
    ShortcutAction.navAlbums => tr('sidebar.go_albums'),
    ShortcutAction.navArtists => tr('sidebar.go_artists'),
    ShortcutAction.navHistory => tr('sidebar.go_history'),
    ShortcutAction.navSettings => tr('sidebar.go_settings'),
    ShortcutAction.newPlaylist => tr('playlists.new'),
  };

  String get defaultKey => const {
    ShortcutAction.playPause: 'Space',
    ShortcutAction.skipNext: 'Ctrl+ArrowRight',
    ShortcutAction.skipPrevious: 'Ctrl+ArrowLeft',
    ShortcutAction.volumeUp: 'Ctrl+ArrowUp',
    ShortcutAction.volumeDown: 'Ctrl+ArrowDown',
    ShortcutAction.toggleSidebar: 'Ctrl+B',
    ShortcutAction.toggleQueue: 'Ctrl+Q',
    ShortcutAction.navPlayer: 'Ctrl+1',
    ShortcutAction.navLibrary: 'Ctrl+2',
    ShortcutAction.navAlbums: 'Ctrl+3',
    ShortcutAction.navArtists: 'Ctrl+4',
    ShortcutAction.navHistory: 'Ctrl+5',
    ShortcutAction.navSettings: 'Ctrl+6',
    ShortcutAction.newPlaylist: 'Ctrl+N',
  }[this]!;
}

// Old saves kept search at 7 and the mini player at 8.
Map<ShortcutAction, String> decodeStoredShortcuts(Map<dynamic, dynamic> map) {
  final result = <ShortcutAction, String>{};
  final numeric =
      map.isNotEmpty && map.keys.every((key) => int.tryParse('$key') != null);
  if (numeric) {
    for (final entry in map.entries) {
      final idx = int.tryParse('${entry.key}');
      final value = entry.value;
      if (idx == null || value is! String || value.isEmpty) continue;
      if (idx == 7 || idx == 8) continue;
      final mapped = idx > 8 ? idx - 2 : idx;
      if (mapped < 0 || mapped >= ShortcutAction.values.length) continue;
      result[ShortcutAction.values[mapped]] = value;
    }
    return result;
  }
  for (final entry in map.entries) {
    final value = entry.value;
    if (value is! String || value.isEmpty) continue;
    for (final action in ShortcutAction.values) {
      if (action.name != entry.key) continue;
      result[action] = value;
      break;
    }
  }
  return result;
}

enum AudioOutputMode { system, exclusive }

AudioOutputMode platformDefaultOutputMode({bool? windows}) {
  if (windows ?? Platform.isWindows) return AudioOutputMode.exclusive;
  return AudioOutputMode.system;
}

bool platformDefaultDiscordRpc({bool? desktop}) {
  final isDesktop =
      desktop ?? (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  return isDesktop;
}

enum ReplayGainMode { off, track, album, auto }

enum CrossfadeMode { off, short, medium, long }

enum StopAfterMode { off, track, album }

const _kOutputMode = 'aqloss_output_mode';
const _kSelectedDeviceId = 'aqloss_selected_device_id';
const _kReplayGain = 'aqloss_replay_gain';
const _kShortcuts = 'aqloss_shortcuts';
const _kReplayGainPreamp = 'aqloss_replay_gain_preamp';
const _kGapless = 'aqloss_gapless';
const _kCrossfade = 'aqloss_crossfade';
const _kStopAfter = 'aqloss_stop_after';
const _kScrobble = 'aqloss_scrobble';
const _kLastFmUser = 'aqloss_lastfm_user';
const _kLastFmApiKey = 'aqloss_lastfm_api_key';
const _kLastFmApiSecret = 'aqloss_lastfm_api_secret';
const _kLastFmSession = 'aqloss_lastfm_session';
const _kScrobbleListenBrainz = 'aqloss_scrobble_listenbrainz';
const _kListenBrainzToken = 'aqloss_listenbrainz_token';
const _kListenBrainzUser = 'aqloss_listenbrainz_user';
const _kEqEnabled = 'aqloss_eq_enabled';
const _kEqGains = 'aqloss_eq_gains';
const _kEqUserPresets = 'aqloss_eq_user_presets';
const _kNotchFilter = 'aqloss_notch_filter';
const _kSkipSilence = 'aqloss_skip_silence';
const _kPlaybackSpeed = 'aqloss_playback_speed';
const _kShowAlbumArtBg = 'aqloss_album_art_bg';
const _kStereoWidth = 'aqloss_stereo_width';
const _kHaasMs = 'aqloss_haas_ms';
const _kDiscordRpc = 'aqloss_discord_rpc';
const _kHwAccel = 'aqloss_hw_accel';
const _kCloseToTray = 'aqloss_close_to_tray';
const _kReduceMotion = 'aqloss_reduce_motion';
const _kLanguage = 'aqloss_language';

class SettingsState {
  final AudioOutputMode outputMode;
  final String? selectedDeviceId;
  final bool gaplessPlayback;
  final CrossfadeMode crossfade;
  final ReplayGainMode replayGainMode;
  final double replayGainPreamp;
  final bool skipSilence;
  final double playbackSpeed;
  final StopAfterMode stopAfter;
  final bool eqEnabled;
  final List<double> eqGains;
  final List<EqPreset> eqUserPresets;
  final bool notchFilter;
  final Map<ShortcutAction, String> shortcuts;
  final bool showAlbumArtBackground;
  final bool scrobbleLastFm;
  final String? lastFmUsername;
  final String? lastFmApiKey;
  final String? lastFmApiSecret;
  final String? lastFmSessionKey;
  final bool scrobbleListenBrainz;
  final String? listenBrainzToken;
  final String? listenBrainzUsername;
  final double stereoWidth;
  final double haasMs;
  final bool discordRpc;
  final bool hardwareAcceleration;
  final bool closeToTray;
  final bool reduceMotion;
  final String language;
  final bool loaded;

  const SettingsState({
    this.outputMode = AudioOutputMode.system,
    this.selectedDeviceId,
    this.gaplessPlayback = true,
    this.crossfade = CrossfadeMode.off,
    this.replayGainMode = ReplayGainMode.off,
    this.replayGainPreamp = 0.0,
    this.skipSilence = false,
    this.playbackSpeed = 1.0,
    this.stopAfter = StopAfterMode.off,
    this.eqEnabled = false,
    this.eqGains = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    this.eqUserPresets = const [],
    this.notchFilter = true,
    this.shortcuts = const {},
    this.showAlbumArtBackground = true,
    this.scrobbleLastFm = false,
    this.lastFmUsername,
    this.lastFmApiKey,
    this.lastFmApiSecret,
    this.lastFmSessionKey,
    this.scrobbleListenBrainz = false,
    this.listenBrainzToken,
    this.listenBrainzUsername,
    this.stereoWidth = 1.0,
    this.haasMs = 0.0,
    this.discordRpc = true,
    this.hardwareAcceleration = true,
    this.closeToTray = true,
    this.reduceMotion = false,
    this.language = '',
    this.loaded = false,
  });

  bool get replayGainEnabled => replayGainMode != ReplayGainMode.off;
  bool get crossfadeEnabled => crossfade != CrossfadeMode.off;
  String binding(ShortcutAction a) => shortcuts[a] ?? a.defaultKey;

  bool get scrobbleReady => scrobbleLastFm && lastFmSessionKey != null;

  bool get listenBrainzReady =>
      scrobbleListenBrainz &&
      listenBrainzToken != null &&
      listenBrainzToken!.trim().isNotEmpty;

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
    bool? gaplessPlayback,
    CrossfadeMode? crossfade,
    ReplayGainMode? replayGainMode,
    double? replayGainPreamp,
    bool? skipSilence,
    double? playbackSpeed,
    StopAfterMode? stopAfter,
    bool? eqEnabled,
    List<double>? eqGains,
    List<EqPreset>? eqUserPresets,
    bool? notchFilter,
    Map<ShortcutAction, String>? shortcuts,
    bool? showAlbumArtBackground,
    bool? scrobbleLastFm,
    String? lastFmUsername,
    String? lastFmApiKey,
    String? lastFmApiSecret,
    String? lastFmSessionKey,
    bool clearSession = false,
    bool? scrobbleListenBrainz,
    String? listenBrainzToken,
    String? listenBrainzUsername,
    bool clearListenBrainz = false,
    double? stereoWidth,
    double? haasMs,
    bool? discordRpc,
    bool? hardwareAcceleration,
    bool? closeToTray,
    bool? reduceMotion,
    String? language,
    bool? loaded,
  }) => SettingsState(
    outputMode: outputMode ?? this.outputMode,
    selectedDeviceId: clearDeviceId
        ? null
        : (selectedDeviceId ?? this.selectedDeviceId),
    gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
    crossfade: crossfade ?? this.crossfade,
    replayGainMode: replayGainMode ?? this.replayGainMode,
    replayGainPreamp: replayGainPreamp ?? this.replayGainPreamp,
    skipSilence: skipSilence ?? this.skipSilence,
    playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    stopAfter: stopAfter ?? this.stopAfter,
    eqEnabled: eqEnabled ?? this.eqEnabled,
    eqGains: eqGains ?? this.eqGains,
    eqUserPresets: eqUserPresets ?? this.eqUserPresets,
    notchFilter: notchFilter ?? this.notchFilter,
    shortcuts: shortcuts ?? this.shortcuts,
    showAlbumArtBackground:
        showAlbumArtBackground ?? this.showAlbumArtBackground,
    scrobbleLastFm: scrobbleLastFm ?? this.scrobbleLastFm,
    lastFmUsername: lastFmUsername ?? this.lastFmUsername,
    lastFmApiKey: lastFmApiKey ?? this.lastFmApiKey,
    lastFmApiSecret: lastFmApiSecret ?? this.lastFmApiSecret,
    lastFmSessionKey: clearSession
        ? null
        : (lastFmSessionKey ?? this.lastFmSessionKey),
    scrobbleListenBrainz: scrobbleListenBrainz ?? this.scrobbleListenBrainz,
    listenBrainzToken: clearListenBrainz
        ? null
        : (listenBrainzToken ?? this.listenBrainzToken),
    listenBrainzUsername: clearListenBrainz
        ? null
        : (listenBrainzUsername ?? this.listenBrainzUsername),
    stereoWidth: stereoWidth ?? this.stereoWidth,
    haasMs: haasMs ?? this.haasMs,
    discordRpc: discordRpc ?? this.discordRpc,
    hardwareAcceleration: hardwareAcceleration ?? this.hardwareAcceleration,
    closeToTray: closeToTray ?? this.closeToTray,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    language: language ?? this.language,
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
                  platformDefaultOutputMode().index)
              .clamp(0, AudioOutputMode.values.length - 1)],
      selectedDeviceId: p.getString(_kSelectedDeviceId),
      gaplessPlayback: p.getBool(_kGapless) ?? true,
      crossfade: CrossfadeMode.values[(p.getInt(_kCrossfade) ?? 0).clamp(0, 3)],
      replayGainMode:
          ReplayGainMode.values[(p.getInt(_kReplayGain) ?? 0).clamp(0, 3)],
      replayGainPreamp: (p.getDouble(_kReplayGainPreamp) ?? 0.0).clamp(-12, 12),
      skipSilence: p.getBool(_kSkipSilence) ?? false,
      playbackSpeed: clampPlaybackSpeed(p.getDouble(_kPlaybackSpeed) ?? 1.0),
      stopAfter: StopAfterMode.values[(p.getInt(_kStopAfter) ?? 0).clamp(0, 2)],
      eqEnabled: p.getBool(_kEqEnabled) ?? false,
      eqGains: normalizeEqGains(eqGains),
      eqUserPresets: decodeEqUserPresets(p.getString(_kEqUserPresets)),
      notchFilter: p.getBool(_kNotchFilter) ?? true,
      shortcuts: _loadShortcuts(p),
      showAlbumArtBackground: p.getBool(_kShowAlbumArtBg) ?? true,
      scrobbleLastFm: p.getBool(_kScrobble) ?? false,
      lastFmUsername: p.getString(_kLastFmUser),
      lastFmApiKey: p.getString(_kLastFmApiKey),
      lastFmApiSecret: p.getString(_kLastFmApiSecret),
      lastFmSessionKey: p.getString(_kLastFmSession),
      scrobbleListenBrainz: p.getBool(_kScrobbleListenBrainz) ?? false,
      listenBrainzToken: p.getString(_kListenBrainzToken),
      listenBrainzUsername: p.getString(_kListenBrainzUser),
      stereoWidth: (p.getDouble(_kStereoWidth) ?? 1.0).clamp(0.0, 2.0),
      haasMs: (p.getDouble(_kHaasMs) ?? 0.0).clamp(0.0, 25.0),
      discordRpc: p.getBool(_kDiscordRpc) ?? platformDefaultDiscordRpc(),
      hardwareAcceleration: p.getBool(_kHwAccel) ?? true,
      closeToTray: p.getBool(_kCloseToTray) ?? true,
      reduceMotion: p.getBool(_kReduceMotion) ?? false,
      language: p.getString(_kLanguage) ?? '',
      loaded: true,
    );
    GpuPref.write(state.hardwareAcceleration);
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
      p.setDouble(_kPlaybackSpeed, state.playbackSpeed),
      p.setInt(_kStopAfter, state.stopAfter.index),
      p.setBool(_kEqEnabled, state.eqEnabled),
      p.setStringList(
        _kEqGains,
        state.eqGains.map((g) => g.toString()).toList(),
      ),
      p.setString(_kEqUserPresets, encodeEqUserPresets(state.eqUserPresets)),
      p.setBool(_kNotchFilter, state.notchFilter),
      _saveShortcuts(p, state.shortcuts),
      p.setBool(_kShowAlbumArtBg, state.showAlbumArtBackground),
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
      p.setBool(_kScrobbleListenBrainz, state.scrobbleListenBrainz),
      state.listenBrainzToken != null
          ? p.setString(_kListenBrainzToken, state.listenBrainzToken!)
          : p.remove(_kListenBrainzToken),
      state.listenBrainzUsername != null
          ? p.setString(_kListenBrainzUser, state.listenBrainzUsername!)
          : p.remove(_kListenBrainzUser),
      p.setDouble(_kStereoWidth, state.stereoWidth),
      p.setDouble(_kHaasMs, state.haasMs),
      p.setBool(_kDiscordRpc, state.discordRpc),
      p.setBool(_kHwAccel, state.hardwareAcceleration),
      p.setBool(_kCloseToTray, state.closeToTray),
      p.setBool(_kReduceMotion, state.reduceMotion),
      p.setString(_kLanguage, state.language),
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

  void setPlaybackSpeed(double v) {
    state = state.copyWith(playbackSpeed: clampPlaybackSpeed(v));
    _save();
  }

  void setShortcut(ShortcutAction action, String key) {
    final updated = Map<ShortcutAction, String>.from(state.shortcuts);
    updated[action] = key;
    state = state.copyWith(shortcuts: updated);
    _save();
  }

  void resetShortcut(ShortcutAction action) {
    final updated = Map<ShortcutAction, String>.from(state.shortcuts)
      ..remove(action);
    state = state.copyWith(shortcuts: updated);
    _save();
  }

  void resetAllShortcuts() {
    state = state.copyWith(shortcuts: const {});
    _save();
  }

  static Map<ShortcutAction, String> _loadShortcuts(SharedPreferences p) {
    final raw = p.getString(_kShortcuts);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decodeStoredShortcuts(decoded);
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveShortcuts(
    SharedPreferences p,
    Map<ShortcutAction, String> shortcuts,
  ) async {
    final raw = jsonEncode({
      for (final e in shortcuts.entries) e.key.name: e.value,
    });
    await p.setString(_kShortcuts, raw);
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

  void setLanguage(String code) {
    state = state.copyWith(language: code);
    _save();
  }

  void toggleAlbumArtBackground() {
    state = state.copyWith(
      showAlbumArtBackground: !state.showAlbumArtBackground,
    );
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

  void toggleScrobbleListenBrainz() {
    state = state.copyWith(scrobbleListenBrainz: !state.scrobbleListenBrainz);
    _save();
  }

  void setListenBrainzToken(String? token, {String? username}) {
    state = state.copyWith(
      listenBrainzToken: token,
      listenBrainzUsername: username,
    );
    _save();
  }

  void clearListenBrainz() {
    state = state.copyWith(clearListenBrainz: true);
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

  void applyEqPreset(EqPreset preset) {
    state = state.copyWith(
      eqGains: normalizeEqGains(preset.gains),
      eqEnabled: true,
    );
    _save();
  }

  EqPresetSaveResult saveEqPreset(String rawName) {
    final name = sanitizeEqPresetName(rawName);
    if (name == null) return EqPresetSaveResult.emptyName;
    if (isBuiltInEqPresetName(name)) return EqPresetSaveResult.builtInName;
    final next = upsertEqUserPreset(
      state.eqUserPresets,
      name: name,
      gains: state.eqGains,
    );
    if (next == null) return EqPresetSaveResult.full;
    state = state.copyWith(eqUserPresets: next);
    _save();
    return EqPresetSaveResult.ok;
  }

  void deleteEqUserPreset(String name) {
    final next = [
      for (final p in state.eqUserPresets)
        if (p.name.toLowerCase() != name.toLowerCase()) p,
    ];
    if (next.length == state.eqUserPresets.length) return;
    state = state.copyWith(eqUserPresets: next);
    _save();
  }

  void setStereoWidth(double v) {
    state = state.copyWith(stereoWidth: v.clamp(0.0, 2.0));
    _save();
  }

  void setHaasMs(double v) {
    state = state.copyWith(haasMs: v.clamp(0.0, 25.0));
    _save();
  }

  void toggleDiscordRpc() {
    state = state.copyWith(discordRpc: !state.discordRpc);
    _save();
  }

  void toggleHardwareAcceleration() {
    state = state.copyWith(hardwareAcceleration: !state.hardwareAcceleration);
    _save();
    GpuPref.write(state.hardwareAcceleration);
  }

  void toggleCloseToTray() {
    state = state.copyWith(closeToTray: !state.closeToTray);
    _save();
  }

  void toggleReduceMotion() {
    state = state.copyWith(reduceMotion: !state.reduceMotion);
    _save();
  }

  Future<void> applyBackup(SettingsState next) async {
    state = next.copyWith(loaded: true);
    await _save();
    GpuPref.write(state.hardwareAcceleration);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
