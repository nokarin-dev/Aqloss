import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/services/audio_service.dart';
import 'package:aqloss/services/scrobble_controller.dart';
import 'package:aqloss/services/lastfm_service.dart';
import 'package:aqloss/services/notifier/media_control_service.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

class SettingsWatcher extends ConsumerStatefulWidget {
  final Widget child;
  const SettingsWatcher({super.key, required this.child});

  @override
  ConsumerState<SettingsWatcher> createState() => _SettingsWatcherState();
}

class _SettingsWatcherState extends ConsumerState<SettingsWatcher> {
  SettingsState? _prev;
  PlayerState? _prevPlayer;
  bool _mediaInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initMediaControls());
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
  void dispose() {
    MediaControlService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final player = ref.watch(playerProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _apply(s);
      _applyMediaControls(player);
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

  Future<void> _apply(SettingsState s) async {
    if (!s.loaded) return;
    final prev = _prev;
    _prev = s;

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
        prev?.scrobbleLastFm != s.scrobbleLastFm) {
      if (s.scrobbleReady) {
        final creds = LastFmService.resolve(
          userApiKey: s.lastFmApiKey,
          userApiSecret: s.lastFmApiSecret,
        );
        ScrobbleController.instance.setSession(
          s.lastFmSessionKey,
          creds: creds,
        );
      } else {
        ScrobbleController.instance.setSession(null);
      }
    }
  }
}
