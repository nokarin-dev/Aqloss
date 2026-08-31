import 'package:aqloss/app_version.dart';
import 'package:aqloss/providers/accent_provider.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/services/audio_service.dart';
import 'package:aqloss/services/lastfm_service.dart';
import 'package:aqloss/services/loved_sync.dart';
import 'package:aqloss/services/notifier/media_control_service.dart';
import 'package:aqloss/services/scrobble_controller.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/util/notices.dart';
import 'package:aqloss/util/update_check.dart';
import 'package:aqloss/widgets/q_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsWatcher extends ConsumerStatefulWidget {
  final Widget child;
  const SettingsWatcher({super.key, required this.child});

  @override
  ConsumerState<SettingsWatcher> createState() => _SettingsWatcherState();
}

class _SettingsWatcherState extends ConsumerState<SettingsWatcher> {
  SettingsState? _prev;
  PlayerState? _prevPlayer;
  PlayerStatus? _prevPlayerStatus;
  bool _mediaInitialized = false;
  bool _lovedPullStarted = false;
  AccentMode? _prevAccentMode;
  int? _prevAccentColor;
  String? _prevAccentPath;
  LibraryStatus? _prevLibraryStatus;
  bool _updateCheckStarted = false;

  static const _kUpdateNotified = 'aqloss_update_notified';

  @override
  void initState() {
    super.initState();
    ScrobbleController.instance.onFailed = (msg) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notice(msg);
      });
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _initMediaControls());
  }

  @override
  void dispose() {
    ScrobbleController.instance.onFailed = null;
    MediaControlService.dispose();
    super.dispose();
  }

  Future<void> _initMediaControls() async {
    if (_mediaInitialized) return;
    _mediaInitialized = true;

    final notifier = ref.read(playerProvider.notifier);
    await MediaControlService.init(
      onPlay: () => notifier.play(),
      onPause: () => notifier.pause(),
      onNext: () => notifier.skipNext(),
      onPrevious: () => notifier.skipPrevious(),
      onSeek: (pos) => notifier.seekCommit(pos),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final player = ref.watch(playerProvider);
    final library = ref.watch(libraryProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _apply(s);
      _applyMediaControls(player);
      _applyAccent(s, player);
      _pullLoved(s, library.tracks.isNotEmpty);
      _showPlaybackError(player);
      _restoreSession(library);
      _showLibraryScan(library);
      _checkUpdateToast(s);
    });

    return widget.child;
  }

  void _applyMediaControls(PlayerState player) {
    final prev = _prevPlayer;
    _prevPlayer = player;

    final trackChanged = player.currentTrack?.path != prev?.currentTrack?.path;
    final statusChanged = player.status != prev?.status;
    final positionChanged =
        player.position.inSeconds != prev?.position.inSeconds;

    if (trackChanged || statusChanged || positionChanged) {
      MediaControlService.update(player);
    }
  }

  void _applyAccent(SettingsState s, PlayerState player) {
    final mode = s.accentMode;
    final custom = s.accentColor;
    final path = player.currentTrack?.path;

    if (mode == AccentMode.off) {
      if (_prevAccentMode != AccentMode.off) {
        ref.read(accentColorProvider.notifier).state = null;
      }
      _prevAccentMode = mode;
      _prevAccentColor = null;
      _prevAccentPath = null;
      return;
    }

    if (mode == AccentMode.custom) {
      if (_prevAccentMode != AccentMode.custom || _prevAccentColor != custom) {
        ref.read(accentColorProvider.notifier).state = custom != null
            ? Color(custom)
            : null;
      }
      _prevAccentMode = mode;
      _prevAccentColor = custom;
      _prevAccentPath = null;
      return;
    }

    final modeChanged = _prevAccentMode != AccentMode.auto;
    final pathChanged = path != _prevAccentPath;
    if (!modeChanged && !pathChanged) return;

    _prevAccentMode = mode;
    _prevAccentPath = path;

    resolveAccentColor(mode: mode, customArgb: custom, trackPath: path).then((
      color,
    ) {
      if (mounted) {
        ref.read(accentColorProvider.notifier).state = color;
      }
    });
  }

  Future<void> _apply(SettingsState s) async {
    if (!s.loaded) return;
    final prev = _prev;
    _prev = s;
    _configureLoved(s);

    if (prev?.notchFilter != s.notchFilter) {
      await backend.setSoftClip(enabled: s.notchFilter).catchError((_) {});
    }

    if (prev?.skipSilence != s.skipSilence) {
      await backend.setSkipSilence(enabled: s.skipSilence).catchError((_) {});
    }

    if (prev?.gaplessPlayback != s.gaplessPlayback) {
      await backend.setGapless(enabled: s.gaplessPlayback).catchError((_) {});
    }

    if (prev?.crossfade != s.crossfade) {
      await backend.setCrossfadeSecs(secs: s.crossfadeSecs).catchError((_) {});
    }

    if (prev?.eqEnabled != s.eqEnabled) {
      await backend.setEqEnabled(enabled: s.eqEnabled).catchError((_) {});
    }

    if (prev == null || prev.eqGains.toString() != s.eqGains.toString()) {
      await backend
          .setEqGains(gains: s.eqGains.map((g) => g.toDouble()).toList())
          .catchError((_) {});
    }

    if (prev?.replayGainMode != s.replayGainMode ||
        prev?.replayGainPreamp != s.replayGainPreamp) {
      final track = ref.read(playerProvider).currentTrack;
      if (track != null && s.replayGainEnabled) {
        await AudioService.applyReplayGainForTrack(
          mode: s.replayGainMode,
          preampDb: s.replayGainPreamp,
          trackGainDb: track.replayGainTrack,
          albumGainDb: track.replayGainAlbum,
        );
      } else if (!s.replayGainEnabled) {
        await backend.setReplayGain(linearGain: 1.0).catchError((_) {});
      }
    }

    if (prev?.lastFmSessionKey != s.lastFmSessionKey ||
        prev?.lastFmApiKey != s.lastFmApiKey ||
        prev?.lastFmApiSecret != s.lastFmApiSecret ||
        prev?.scrobbleLastFm != s.scrobbleLastFm ||
        prev?.listenBrainzToken != s.listenBrainzToken ||
        prev?.scrobbleListenBrainz != s.scrobbleListenBrainz) {
      LastFmCredentials? creds;
      if (s.scrobbleReady) {
        creds = LastFmService.resolve(
          userApiKey: s.lastFmApiKey,
          userApiSecret: s.lastFmApiSecret,
        );
      }
      ScrobbleController.instance.configure(
        lastFmSessionKey: s.scrobbleReady ? s.lastFmSessionKey : null,
        lastFmCreds: creds,
        listenBrainzToken: s.listenBrainzReady ? s.listenBrainzToken : null,
      );
    }
  }

  void _configureLoved(SettingsState s) {
    LastFmCredentials? creds;
    if (s.scrobbleReady) {
      creds = LastFmService.resolve(
        userApiKey: s.lastFmApiKey,
        userApiSecret: s.lastFmApiSecret,
      );
    }
    LovedSync.configure(
      lastFmCreds: creds,
      lastFmSession: s.scrobbleReady ? s.lastFmSessionKey : null,
      lastFmUser: s.scrobbleReady ? s.lastFmUsername : null,
      listenBrainzToken: s.listenBrainzReady ? s.listenBrainzToken : null,
      listenBrainzUser: s.listenBrainzReady ? s.listenBrainzUsername : null,
    );
  }

  void _pullLoved(SettingsState s, bool hasLibrary) {
    if (_lovedPullStarted || !hasLibrary || !s.loaded) return;
    if (!s.scrobbleReady && !s.listenBrainzReady) return;
    _lovedPullStarted = true;
    _configureLoved(s);
    LovedSync.importInto(ref);
  }

  void _showPlaybackError(PlayerState player) {
    final prev = _prevPlayerStatus;
    _prevPlayerStatus = player.status;
    if (player.status != PlayerStatus.error || prev == PlayerStatus.error) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(const SnackBar(content: Text('Playback failed')));
  }

  void _restoreSession(LibraryState library) {
    if (library.tracks.isEmpty) return;
    ref.read(playerProvider.notifier).restoreSession(library.tracks);
  }

  void _notice(String message) {
    if (!mounted) return;
    if (Overlay.maybeOf(context) == null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    QToast.show(context, message, duration: const Duration(seconds: 3));
  }

  void _showLibraryScan(LibraryState library) {
    final prev = _prevLibraryStatus;
    _prevLibraryStatus = library.status;
    if (prev != LibraryStatus.scanning) return;
    if (library.status == LibraryStatus.done) {
      _notice(libraryScanFinishedMessage(library.tracks.length));
    } else if (library.status == LibraryStatus.error) {
      _notice(kLibraryScanFailedMessage);
    }
  }

  void _checkUpdateToast(SettingsState s) {
    if (_updateCheckStarted || !s.loaded) return;
    _updateCheckStarted = true;
    checkGithubLatest(currentVersion: kAppVersion).then((result) async {
      if (!mounted || result.status != UpdateCheckStatus.available) return;
      final ver = result.latestVersion;
      if (ver == null || ver.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_kUpdateNotified) == ver) return;
      await prefs.setString(_kUpdateNotified, ver);
      if (mounted) _notice(updateAvailableMessage(ver));
    });
  }
}
