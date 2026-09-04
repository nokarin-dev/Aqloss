import 'dart:convert';
import 'dart:io' show Platform;

import 'package:aqloss/services/gpu_pref.dart';
import 'package:aqloss/theme/ui_framework.dart';
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
  search,
  miniPlayer,
  navPlayer,
  navLibrary,
  navAlbums,
  navArtists,
  navHistory,
  navSettings,
  newPlaylist,
}

extension ShortcutActionX on ShortcutAction {
  String get label => const {
    ShortcutAction.playPause: 'Play / Pause',
    ShortcutAction.skipNext: 'Next track',
    ShortcutAction.skipPrevious: 'Previous track',
    ShortcutAction.volumeUp: 'Volume up 5%',
    ShortcutAction.volumeDown: 'Volume down 5%',
    ShortcutAction.toggleSidebar: 'Toggle sidebar',
    ShortcutAction.toggleQueue: 'Toggle queue panel',
    ShortcutAction.search: 'Open search',
    ShortcutAction.miniPlayer: 'Toggle mini player',
    ShortcutAction.navPlayer: 'Go to Now Playing',
    ShortcutAction.navLibrary: 'Go to Library',
    ShortcutAction.navAlbums: 'Go to Albums',
    ShortcutAction.navArtists: 'Go to Artists',
    ShortcutAction.navHistory: 'Go to History',
    ShortcutAction.navSettings: 'Go to Settings',
    ShortcutAction.newPlaylist: 'New playlist',
  }[this]!;

  String get defaultKey => const {
    ShortcutAction.playPause: 'Space',
    ShortcutAction.skipNext: 'Ctrl+ArrowRight',
    ShortcutAction.skipPrevious: 'Ctrl+ArrowLeft',
    ShortcutAction.volumeUp: 'Ctrl+ArrowUp',
    ShortcutAction.volumeDown: 'Ctrl+ArrowDown',
    ShortcutAction.toggleSidebar: 'Ctrl+B',
    ShortcutAction.toggleQueue: 'Ctrl+Q',
    ShortcutAction.search: 'Ctrl+F',
    ShortcutAction.miniPlayer: 'Ctrl+M',
    ShortcutAction.navPlayer: 'Ctrl+1',
    ShortcutAction.navLibrary: 'Ctrl+2',
    ShortcutAction.navAlbums: 'Ctrl+3',
    ShortcutAction.navArtists: 'Ctrl+4',
    ShortcutAction.navHistory: 'Ctrl+5',
    ShortcutAction.navSettings: 'Ctrl+6',
    ShortcutAction.newPlaylist: 'Ctrl+N',
  }[this]!;
}

enum AudioOutputMode { system, exclusive }

AudioOutputMode platformDefaultOutputMode({bool? windows}) {
  if (windows ?? Platform.isWindows) return AudioOutputMode.exclusive;
  return AudioOutputMode.system;
}

enum ThemeMode { dark, light, system }

enum AppStyle { legacy, islands }

enum AccentMode { off, auto, custom }

enum LibraryViewMode { detail, grid }

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
const _kTheme = 'aqloss_theme';
const _kUiFramework = 'aqloss_ui_framework';
const _kAppStyle = 'aqloss_app_style';
const _kLibraryViewMode = 'aqloss_library_view_mode';
const _kAlbumViewMode = 'aqloss_album_view_mode';
const _kShowBitDepth = 'aqloss_show_bit_depth';
const _kShowNowPlayingHeader = 'aqloss_show_now_playing_header';
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
const _kSpectrumEnabled = 'aqloss_spectrum';
const _kSpectrumStyle = 'aqloss_spectrum_style';
const _kAccentMode = 'aqloss_accent_mode';
const _kAccentColor = 'aqloss_accent_color';
const _kStereoWidth = 'aqloss_stereo_width';
const _kHaasMs = 'aqloss_haas_ms';
const _kDiscordRpc = 'aqloss_discord_rpc';
const _kMaterialYou = 'aqloss_material_you';
const _kHwAccel = 'aqloss_hw_accel';
const _kCloseToTray = 'aqloss_close_to_tray';
const _kReduceMotion = 'aqloss_reduce_motion';
const _kShowTileBar = 'aqloss_show_titlebar';


class SettingsState {
  final AudioOutputMode outputMode;
  final String? selectedDeviceId;
  final double volume;
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
  final ThemeMode themeMode;
  final AppStyle appStyle;
  final UiFramework uiFramework;
  final LibraryViewMode libraryViewMode;
  final LibraryViewMode albumViewMode;
  final bool showBitDepthInLibrary;
  final bool showNowPlayingHeader;
  final Map<ShortcutAction, String> shortcuts;
  final bool showAlbumArtBackground;
  final bool spectrumEnabled;
  final int spectrumStyle;
  final bool scrobbleLastFm;
  final String? lastFmUsername;
  final String? lastFmApiKey;
  final String? lastFmApiSecret;
  final String? lastFmSessionKey;
  final bool scrobbleListenBrainz;
  final String? listenBrainzToken;
  final String? listenBrainzUsername;
  final AccentMode accentMode;
  final int? accentColor;
  final double stereoWidth;
  final double haasMs;
  final bool discordRpc;
  final bool materialYou;
  final bool hardwareAcceleration;
  final bool closeToTray;
  final bool reduceMotion;
  final bool showTitleBar;
  final bool loaded;

  const SettingsState({
    this.outputMode = AudioOutputMode.system,
    this.selectedDeviceId,
    this.volume = 1.0,
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
    this.themeMode = ThemeMode.dark,
    this.appStyle = AppStyle.legacy,
    this.uiFramework = UiFramework.standalone,
    this.libraryViewMode = LibraryViewMode.detail,
    this.albumViewMode = LibraryViewMode.detail,
    this.showBitDepthInLibrary = true,
    this.showNowPlayingHeader = false,
    this.shortcuts = const {},
    this.showAlbumArtBackground = true,
    this.spectrumEnabled = true,
    this.spectrumStyle = 0,
    this.scrobbleLastFm = false,
    this.lastFmUsername,
    this.lastFmApiKey,
    this.lastFmApiSecret,
    this.lastFmSessionKey,
    this.scrobbleListenBrainz = false,
    this.listenBrainzToken,
    this.listenBrainzUsername,
    this.accentMode = AccentMode.off,
    this.accentColor,
    this.stereoWidth = 1.0,
    this.haasMs = 0.0,
    this.discordRpc = true,
    this.materialYou = false,
    this.hardwareAcceleration = true,
    this.closeToTray = true,
    this.reduceMotion = false,
    this.showTitleBar = true,
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
    double? volume,
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
    ThemeMode? themeMode,
    AppStyle? appStyle,
    UiFramework? uiFramework,
    LibraryViewMode? libraryViewMode,
    LibraryViewMode? albumViewMode,
    bool? showBitDepthInLibrary,
    bool? showNowPlayingHeader,
    Map<ShortcutAction, String>? shortcuts,
    bool? showAlbumArtBackground,
    bool? spectrumEnabled,
    int? spectrumStyle,
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
    AccentMode? accentMode,
    int? accentColor,
    bool clearAccentColor = false,
    double? stereoWidth,
    double? haasMs,
    bool? discordRpc,
    bool? materialYou,
    bool? hardwareAcceleration,
    bool? closeToTray,
    bool? reduceMotion,
    bool? showTitleBar,
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
    playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    stopAfter: stopAfter ?? this.stopAfter,
    eqEnabled: eqEnabled ?? this.eqEnabled,
    eqGains: eqGains ?? this.eqGains,
    eqUserPresets: eqUserPresets ?? this.eqUserPresets,
    notchFilter: notchFilter ?? this.notchFilter,
    themeMode: themeMode ?? this.themeMode,
    appStyle: appStyle ?? this.appStyle,
    uiFramework: uiFramework ?? this.uiFramework,
    libraryViewMode: libraryViewMode ?? this.libraryViewMode,
    albumViewMode: albumViewMode ?? this.albumViewMode,
    showBitDepthInLibrary: showBitDepthInLibrary ?? this.showBitDepthInLibrary,
    showNowPlayingHeader: showNowPlayingHeader ?? this.showNowPlayingHeader,
    shortcuts: shortcuts ?? this.shortcuts,
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
    scrobbleListenBrainz: scrobbleListenBrainz ?? this.scrobbleListenBrainz,
    listenBrainzToken: clearListenBrainz
        ? null
        : (listenBrainzToken ?? this.listenBrainzToken),
    listenBrainzUsername: clearListenBrainz
        ? null
        : (listenBrainzUsername ?? this.listenBrainzUsername),
    accentMode: accentMode ?? this.accentMode,
    accentColor: clearAccentColor ? null : (accentColor ?? this.accentColor),
    stereoWidth: stereoWidth ?? this.stereoWidth,
    haasMs: haasMs ?? this.haasMs,
    discordRpc: discordRpc ?? this.discordRpc,
    materialYou: materialYou ?? this.materialYou,
    hardwareAcceleration: hardwareAcceleration ?? this.hardwareAcceleration,
    closeToTray: closeToTray ?? this.closeToTray,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    showTitleBar: showTitleBar ?? this.showTitleBar,
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
      themeMode: ThemeMode.values[(p.getInt(_kTheme) ?? 0).clamp(0, 2)],
      appStyle:
          AppStyle.values[(p.getInt(_kAppStyle) ?? 0).clamp(
            0,
            AppStyle.values.length - 1,
          )],
      uiFramework: () {
        final stored = p.getInt(_kUiFramework);
        if (stored != null) {
          return UiFramework.values[stored.clamp(
            0,
            UiFramework.values.length - 1,
          )];
        }
        if (p.getBool(_kMaterialYou) == true) {
          return UiFramework.material3;
        }
        return UiFramework.standalone;
      }(),
      libraryViewMode: LibraryViewMode
          .values[(p.getInt(_kLibraryViewMode) ?? 0).clamp(0, 1)],
      albumViewMode:
          LibraryViewMode.values[(p.getInt(_kAlbumViewMode) ?? 0).clamp(0, 1)],
      showBitDepthInLibrary: p.getBool(_kShowBitDepth) ?? true,
      showNowPlayingHeader: p.getBool(_kShowNowPlayingHeader) ?? false,
      shortcuts: _loadShortcuts(p),
      showAlbumArtBackground: p.getBool(_kShowAlbumArtBg) ?? true,
      spectrumEnabled: p.getBool(_kSpectrumEnabled) ?? true,
      spectrumStyle: (p.getInt(_kSpectrumStyle) ?? 0).clamp(0, 3),
      scrobbleLastFm: p.getBool(_kScrobble) ?? false,
      lastFmUsername: p.getString(_kLastFmUser),
      lastFmApiKey: p.getString(_kLastFmApiKey),
      lastFmApiSecret: p.getString(_kLastFmApiSecret),
      lastFmSessionKey: p.getString(_kLastFmSession),
      scrobbleListenBrainz: p.getBool(_kScrobbleListenBrainz) ?? false,
      listenBrainzToken: p.getString(_kListenBrainzToken),
      listenBrainzUsername: p.getString(_kListenBrainzUser),
      accentMode: AccentMode.values[(p.getInt(_kAccentMode) ?? 0).clamp(0, 2)],
      accentColor: p.getInt(_kAccentColor),
      stereoWidth: (p.getDouble(_kStereoWidth) ?? 1.0).clamp(0.0, 2.0),
      haasMs: (p.getDouble(_kHaasMs) ?? 0.0).clamp(0.0, 25.0),
      discordRpc: p.getBool(_kDiscordRpc) ?? true,
      materialYou: p.getBool(_kMaterialYou) ?? false,
      hardwareAcceleration: p.getBool(_kHwAccel) ?? true,
      closeToTray: p.getBool(_kCloseToTray) ?? true,
      reduceMotion: p.getBool(_kReduceMotion) ?? false,
      showTitleBar: p.getBool(_kShowTileBar) ?? false,
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
      p.setInt(_kTheme, state.themeMode.index),
      p.setInt(_kAppStyle, state.appStyle.index),
      p.setInt(_kUiFramework, state.uiFramework.index),
      p.setInt(_kLibraryViewMode, state.libraryViewMode.index),
      p.setInt(_kAlbumViewMode, state.albumViewMode.index),
      p.setBool(_kShowBitDepth, state.showBitDepthInLibrary),
      p.setBool(_kShowNowPlayingHeader, state.showNowPlayingHeader),
      _saveShortcuts(p, state.shortcuts),
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
      p.setBool(_kScrobbleListenBrainz, state.scrobbleListenBrainz),
      state.listenBrainzToken != null
          ? p.setString(_kListenBrainzToken, state.listenBrainzToken!)
          : p.remove(_kListenBrainzToken),
      state.listenBrainzUsername != null
          ? p.setString(_kListenBrainzUser, state.listenBrainzUsername!)
          : p.remove(_kListenBrainzUser),
      p.setInt(_kAccentMode, state.accentMode.index),
      state.accentColor != null
          ? p.setInt(_kAccentColor, state.accentColor!)
          : p.remove(_kAccentColor),
      p.setDouble(_kStereoWidth, state.stereoWidth),
      p.setDouble(_kHaasMs, state.haasMs),
      p.setBool(_kDiscordRpc, state.discordRpc),
      p.setBool(_kMaterialYou, state.materialYou),
      p.setBool(_kHwAccel, state.hardwareAcceleration),
      p.setBool(_kCloseToTray, state.closeToTray),
      p.setBool(_kReduceMotion, state.reduceMotion),
      p.setBool(_kShowTileBar, state.showTitleBar),
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
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final result = <ShortcutAction, String>{};
      for (final entry in map.entries) {
        final idx = int.tryParse(entry.key);
        if (idx != null && idx < ShortcutAction.values.length) {
          result[ShortcutAction.values[idx]] = entry.value as String;
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveShortcuts(
    SharedPreferences p,
    Map<ShortcutAction, String> shortcuts,
  ) async {
    final raw = jsonEncode({
      for (final e in shortcuts.entries) '${e.key.index}': e.value,
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

  void setTheme(ThemeMode m) {
    state = state.copyWith(themeMode: m);
    _save();
  }

  void setAppStyle(AppStyle s) {
    state = state.copyWith(appStyle: s);
    _save();
  }

  void setUiFramework(UiFramework f) {
    state = state.copyWith(uiFramework: f);
    _save();
  }

  void setLibraryViewMode(LibraryViewMode m) {
    state = state.copyWith(libraryViewMode: m);
    _save();
  }

  void setAlbumViewMode(LibraryViewMode m) {
    state = state.copyWith(albumViewMode: m);
    _save();
  }

  void toggleBitDepthDisplay() {
    state = state.copyWith(showBitDepthInLibrary: !state.showBitDepthInLibrary);
    _save();
  }

  void toggleNowPlayingHeader() {
    state = state.copyWith(showNowPlayingHeader: !state.showNowPlayingHeader);
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
    state = state.copyWith(spectrumStyle: s.clamp(0, 3));
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

  void setAccentMode(AccentMode m) {
    state = state.copyWith(accentMode: m);
    _save();
  }

  void setAccentColor(int argb) {
    state = state.copyWith(accentColor: argb, accentMode: AccentMode.custom);
    _save();
  }

  void clearAccentColor() {
    state = state.copyWith(clearAccentColor: true, accentMode: AccentMode.off);
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

  void toggleMaterialYou() {
    if (state.uiFramework != UiFramework.material3) return;
    state = state.copyWith(materialYou: !state.materialYou);
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

  void toggleShowTitleBar() {
    state = state.copyWith(showTitleBar: !state.showTitleBar);
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
