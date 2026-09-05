import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:aqloss/services/audio_service.dart';
import 'package:aqloss/services/scrobble_controller.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/src/rust/lib.dart' as backend show PlaybackPosition;
import 'package:aqloss/util/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/audio_device_provider.dart';
import 'package:aqloss/providers/history_provider.dart';
import 'package:aqloss/plugins/plugin_api.dart';
import 'package:aqloss/plugins/plugin_registry.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/services/discord_service.dart';
import 'package:aqloss/services/position_store.dart';
import 'package:aqloss/util/ab_loop.dart';
import 'package:aqloss/util/missing_files.dart';
import 'package:aqloss/util/playback.dart';
import 'package:aqloss/util/sleep_timer.dart';
import 'package:aqloss/util/track_positions.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kVolumeKey = 'aqloss_volume';

enum PlayerStatus { idle, playing, paused, loading, error }

enum LoopMode { off, track, album, playlist }

class PlayerState {
  final Track? currentTrack;
  final PlayerStatus status;
  final Duration position;
  final double volume;
  final LoopMode loopMode;
  final bool shuffle;
  final List<Track> queue;
  final int queueIndex;
  final SleepTimerMode sleepMode;
  final DateTime? sleepUntil;
  final double? loopASecs;
  final double? loopBSecs;

  const PlayerState({
    this.currentTrack,
    this.status = PlayerStatus.idle,
    this.position = Duration.zero,
    this.volume = 1.0,
    this.loopMode = LoopMode.off,
    this.shuffle = false,
    this.queue = const [],
    this.queueIndex = 0,
    this.sleepMode = SleepTimerMode.off,
    this.sleepUntil,
    this.loopASecs,
    this.loopBSecs,
  });

  bool get sleepActive => sleepMode != SleepTimerMode.off;

  AbLoopPhase get abLoop => abLoopPhase(loopASecs, loopBSecs);

  PlayerState copyWith({
    Track? currentTrack,
    PlayerStatus? status,
    Duration? position,
    double? volume,
    LoopMode? loopMode,
    bool? shuffle,
    List<Track>? queue,
    int? queueIndex,
    SleepTimerMode? sleepMode,
    DateTime? sleepUntil,
    bool clearSleepUntil = false,
    double? loopASecs,
    double? loopBSecs,
    bool clearLoopA = false,
    bool clearLoopB = false,
  }) => PlayerState(
    currentTrack: currentTrack ?? this.currentTrack,
    status: status ?? this.status,
    position: position ?? this.position,
    volume: volume ?? this.volume,
    loopMode: loopMode ?? this.loopMode,
    shuffle: shuffle ?? this.shuffle,
    queue: queue ?? this.queue,
    queueIndex: queueIndex ?? this.queueIndex,
    sleepMode: sleepMode ?? this.sleepMode,
    sleepUntil: clearSleepUntil ? null : (sleepUntil ?? this.sleepUntil),
    loopASecs: clearLoopA ? null : (loopASecs ?? this.loopASecs),
    loopBSecs: clearLoopB ? null : (loopBSecs ?? this.loopBSecs),
  );

  bool get hasPrevious => queueIndex > 0;
  bool get hasNext => queueIndex < queue.length - 1;
  Track? get previousTrack => hasPrevious ? queue[queueIndex - 1] : null;
  Track? get nextTrack => hasNext ? queue[queueIndex + 1] : null;
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  Timer? _positionTimer;
  Timer? _sleepTimer;
  bool _disposed = false;
  bool _handlingTrackEnd = false;
  bool _crossfadeQueued = false;
  bool _playPauseBusy = false;
  bool _seeking = false;
  Duration? _seekHoldPosition;
  DateTime? _seekHoldUntil;
  double _lastPollPositionSecs = 0;
  SettingsState Function()? _readSettings;
  HistoryNotifier? _historyNotifier;
  final _rng = math.Random();

  // Guards against concurrent device-change reinit
  bool _deviceReinitBusy = false;
  int _stallTicks = 0;
  double _lastAdvancingPositionSecs = 0;
  int _rememberTicks = 0;
  bool _sessionRestored = false;
  bool _sessionRestoreBusy = false;
  bool _needTrackStartOnPlay = false;

  PlayerNotifier() : super(const PlayerState()) {
    _restoreVolume();
    unawaited(PositionStore.instance.ensureLoaded());

    // Freeze recovery
    AudioService.onFreezeDetected = () async {
      final track = state.currentTrack;
      if (track == null) return;
      Logger.warnPlayerProvider(
        'freeze recovery - reloading ${track.displayTitle}',
      );
      await _recoverAfterOutputRouteChange(null);
    };

    AudioService.onDeviceChanged = _recoverAfterOutputRouteChange;
  }

  AudioDeviceNotifier? _deviceNotifier;

  void injectSettingsReader(SettingsState Function() r) {
    _readSettings = r;
  }

  void injectHistoryNotifier(HistoryNotifier n) {
    _historyNotifier = n;
  }

  void injectDeviceNotifier(AudioDeviceNotifier n) {
    _deviceNotifier = n;
  }

  Future<void> persistPlayback() async {
    final t = state.currentTrack;
    if (t != null) {
      PositionStore.instance.remember(
        t.path,
        state.position.inMilliseconds / 1000.0,
        t.durationSecs,
        force: true,
      );
    }
    if (state.queue.isEmpty) return;
    final win = sessionQueueWindow(
      length: state.queue.length,
      index: state.queueIndex,
    );
    final paths = [
      for (var i = win.start; i < win.end; i++) state.queue[i].path,
    ];
    await PositionStore.instance.saveSession(
      PlaybackSession(
        paths: paths,
        index: win.index,
        positionSecs: state.position.inMilliseconds / 1000.0,
        loopMode: state.loopMode.index,
        shuffle: state.shuffle,
      ),
    );
  }

  Future<void> restoreSession(List<Track> library) async {
    if (_sessionRestored || _sessionRestoreBusy || library.isEmpty) return;
    if (state.currentTrack != null) {
      _sessionRestored = true;
      return;
    }
    _sessionRestoreBusy = true;
    try {
      await PositionStore.instance.ensureLoaded();
      final snap = PositionStore.instance.session;
      if (snap == null || snap.paths.isEmpty) {
        _sessionRestored = true;
        return;
      }
      if (!AudioService.engineReady) {
        for (var i = 0; i < 50; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (!mounted) return;
          if (AudioService.engineReady) break;
        }
      }
      if (!AudioService.engineReady || !mounted) {
        _sessionRestored = true;
        return;
      }
      if (state.currentTrack != null) {
        _sessionRestored = true;
        return;
      }
      final byPath = {for (final t in library) t.path: t};
      final queue = <Track>[
        for (final p in snap.paths)
          if (byPath[p] != null) byPath[p]!,
      ];
      if (queue.isEmpty) {
        _sessionRestored = true;
        return;
      }
      var idx = 0;
      if (snap.index >= 0 && snap.index < snap.paths.length) {
        final want = snap.paths[snap.index];
        final found = queue.indexWhere((t) => t.path == want);
        if (found >= 0) idx = found;
      }
      var loop = LoopMode.off;
      if (snap.loopMode >= 0 && snap.loopMode < LoopMode.values.length) {
        loop = LoopMode.values[snap.loopMode];
      }
      _sessionRestored = true;
      state = state.copyWith(
        queue: queue,
        queueIndex: idx,
        loopMode: loop,
        shuffle: snap.shuffle,
      );
      await _loadAndPlay(
        queue[idx],
        autoplay: false,
        resume: true,
        resumeSecsOverride: snap.positionSecs,
      );
    } finally {
      _sessionRestoreBusy = false;
    }
  }

  void setSleepTimer(SleepTimerMode mode) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (mode == SleepTimerMode.off) {
      state = state.copyWith(
        sleepMode: SleepTimerMode.off,
        clearSleepUntil: true,
      );
      return;
    }
    if (mode == SleepTimerMode.endOfTrack) {
      state = state.copyWith(sleepMode: mode, clearSleepUntil: true);
      return;
    }
    final d = sleepTimerDuration(mode)!;
    final until = DateTime.now().add(d);
    _sleepTimer = Timer(d, _onSleepFired);
    state = state.copyWith(sleepMode: mode, sleepUntil: until);
  }

  void tapAbLoop() {
    if (state.currentTrack == null) return;
    final next = abLoopTap(
      state.position.inMilliseconds / 1000.0,
      state.loopASecs,
      state.loopBSecs,
    );
    state = state.copyWith(
      loopASecs: next.a,
      loopBSecs: next.b,
      clearLoopA: next.a == null,
      clearLoopB: next.b == null,
    );
  }

  Future<void> _onSleepFired() async {
    _sleepTimer = null;
    if (!mounted) return;
    state = state.copyWith(
      sleepMode: SleepTimerMode.off,
      clearSleepUntil: true,
    );
    await pause();
  }

  Future<void> _recoverAfterOutputRouteChange([
    String? newDefaultDeviceId,
  ]) async {
    if (!mounted || _deviceReinitBusy) return;

    _deviceNotifier?.refreshAfterDeviceChange(newDefaultDeviceId);

    final settings = _readSettings?.call();
    final pinned = settings?.selectedDeviceId;
    if (pinned != null &&
        newDefaultDeviceId != null &&
        pinned != newDefaultDeviceId) {
      Logger.debugPlayerProvider(
        'output route changed → $newDefaultDeviceId (ignored, pinned $pinned)',
      );
      return;
    }

    _deviceReinitBusy = true;
    _stallTicks = 0;

    final wasPlaying = state.status == PlayerStatus.playing;
    final track = state.currentTrack;
    final posSecs = state.position.inMilliseconds / 1000.0;

    _stopTimer();
    if (mounted) {
      state = state.copyWith(status: PlayerStatus.paused);
    }

    Logger.warnPlayerProvider(
      'output route changed → $newDefaultDeviceId  wasPlaying=$wasPlaying',
    );

    try {
      final exclusive =
          !Platform.isAndroid &&
          !Platform.isIOS &&
          settings?.outputMode == AudioOutputMode.exclusive;

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      final ok = await AudioService.reinitToDevice(
        deviceId: pinned ?? newDefaultDeviceId ?? 'default',
        exclusive: exclusive,
      );

      if (!mounted) return;
      if (!ok) {
        state = state.copyWith(status: PlayerStatus.error);
        return;
      }

      if (wasPlaying && track != null) {
        state = state.copyWith(status: PlayerStatus.loading);
        await AudioService.loadTrack(track.path);
        if (!mounted) return;
        if (posSecs > 0.5) await AudioService.seek(posSecs);
        await AudioService.play();
        if (mounted) {
          _lastAdvancingPositionSecs = posSecs;
          state = state.copyWith(status: PlayerStatus.playing);
          _startTimer();
        }
      }
    } catch (e) {
      Logger.errorPlayerProvider('output route recovery failed: $e');
      if (mounted) state = state.copyWith(status: PlayerStatus.error);
    } finally {
      _deviceReinitBusy = false;
    }
  }

  @override
  bool get mounted => !_disposed;

  Future<void> _restoreVolume() async {
    final p = await SharedPreferences.getInstance();
    final v = (p.getDouble(_kVolumeKey) ?? 1.0).clamp(0.0, 1.0);
    if (mounted) state = state.copyWith(volume: v);
  }

  Future<void> _saveVolume(double v) async =>
      (await SharedPreferences.getInstance()).setDouble(_kVolumeKey, v);

  Future<void> loadWithQueue(
    Track track,
    List<Track> queue, {
    int? atIndex,
  }) async {
    final pick = playableQueue(
      preferred: track,
      queue: queue,
      exists: (p) => File(p).existsSync(),
      atIndex: atIndex,
    );
    if (pick == null) {
      if (mounted) state = state.copyWith(status: PlayerStatus.error);
      return;
    }
    var q = List<Track>.from(pick.queue);
    var idx = pick.index;
    if (state.shuffle) q = _shuffleUpcoming(q, idx);
    state = state.copyWith(queue: q, queueIndex: idx);
    await _loadAndPlay(pick.track);
  }

  Future<void> load(Track track) async {
    if (state.queue.isEmpty) {
      await _loadAndPlay(track);
      return;
    }
    final idx = state.queue.indexWhere((t) => t.path == track.path);
    if (idx >= 0) state = state.copyWith(queueIndex: idx);
    await _loadAndPlay(track);
  }

  Future<void> _loadAndPlay(
    Track track, {
    bool stopFirst = true,
    bool autoplay = true,
    bool resume = false,
    double? resumeSecsOverride,
  }) async {
    final prev = state.currentTrack;
    if (prev != null && prev.path != track.path) {
      PositionStore.instance.remember(
        prev.path,
        state.position.inMilliseconds / 1000.0,
        prev.durationSecs,
        force: true,
      );
    }
    _stopTimer();
    _handlingTrackEnd = false;
    if (stopFirst) _crossfadeQueued = false;
    _lastPollPositionSecs = 0;
    _stallTicks = 0;
    _lastAdvancingPositionSecs = 0;
    _rememberTicks = 0;
    ScrobbleController.instance.onTrackStop();
    PluginRegistry.instance.dispatchTrackStop(
      TrackStopEvent(state.currentTrack),
    );
    state = state.copyWith(
      status: PlayerStatus.loading,
      currentTrack: track,
      position: Duration.zero,
      clearLoopA: true,
      clearLoopB: true,
    );
    try {
      if (stopFirst) await AudioService.stop();
      if (!File(track.path).existsSync()) {
        if (mounted) state = state.copyWith(status: PlayerStatus.error);
        return;
      }
      await AudioService.loadTrack(track.path);
      if (!mounted) return;
      final s = _readSettings?.call();
      if (s != null && s.replayGainEnabled) {
        await AudioService.applyReplayGainForTrack(
          mode: s.replayGainMode,
          preampDb: s.replayGainPreamp,
          trackGainDb: track.replayGainTrack,
          albumGainDb: track.replayGainAlbum,
          isPlayingInOrder: _isAlbumInOrder(),
        );
      }
      await PositionStore.instance.ensureLoaded();
      double start = 0;
      if (resume) {
        start = playbackStartSecs(
          resumeOnOpen: true,
          duration: track.durationSecs,
          reopenSecs: resumeSecsOverride,
          storedSecs: PositionStore.instance.resumeSecs(
            track.path,
            track.durationSecs,
          ),
        );
        if (start > 0) await AudioService.seek(start);
      } else {
        PositionStore.instance.clearPath(track.path);
      }
      final startPos = Duration(milliseconds: (start * 1000).round());
      if (!autoplay) {
        _needTrackStartOnPlay = true;
        if (!mounted) return;
        state = state.copyWith(status: PlayerStatus.paused, position: startPos);
        DiscordService.update(state, positionSecs: start);
        return;
      }
      _needTrackStartOnPlay = false;
      await AudioService.play();
      if (!mounted) return;
      state = state.copyWith(status: PlayerStatus.playing, position: startPos);
      DiscordService.update(state, positionSecs: start);
      ScrobbleController.instance.onTrackStart(track);
      PluginRegistry.instance.dispatchTrackStart(TrackStartEvent(track));
      _historyNotifier?.recordPlay(track);
      _startTimer();
    } catch (e) {
      Logger.errorPlayerProvider('load failed: $e');
      if (mounted) state = state.copyWith(status: PlayerStatus.error);
    }
  }

  bool _isAlbumInOrder() {
    final q = state.queue;
    final idx = state.queueIndex;
    if (q.isEmpty || idx == 0) return false;
    return q[idx - 1].album == q[idx].album &&
        q[idx - 1].albumArtist == q[idx].albumArtist;
  }

  Future<void> play() async {
    if (_playPauseBusy) return;
    _playPauseBusy = true;
    try {
      try {
        await AudioService.play();
      } catch (e) {
        Logger.warnPlayerProvider('play() failed ($e) - attempting reinit');
        if (!mounted) return;
        final settings = _readSettings?.call();
        final deviceId = settings?.selectedDeviceId;
        final exclusive = settings?.outputMode == AudioOutputMode.exclusive;
        final ok = await AudioService.reinitToDevice(
          deviceId: deviceId,
          exclusive: exclusive,
        );
        if (!ok || !mounted) {
          state = state.copyWith(status: PlayerStatus.error);
          return;
        }
        final track = state.currentTrack;
        if (track != null) {
          final posSecs = state.position.inMilliseconds / 1000.0;
          state = state.copyWith(status: PlayerStatus.loading);
          try {
            await AudioService.loadTrack(track.path);
            if (!mounted) return;
            if (posSecs > 0.5) await AudioService.seek(posSecs);
            await AudioService.play();
          } catch (e2) {
            Logger.errorPlayerProvider(
              'play() reload after reinit failed: $e2',
            );
            if (mounted) state = state.copyWith(status: PlayerStatus.error);
            return;
          }
        } else {
          return;
        }
      }

      if (!mounted) return;
      double pos = state.position.inMilliseconds / 1000.0;
      try {
        pos = (await backend.getPosition()).positionSecs;
      } catch (_) {}
      final track = state.currentTrack;
      if (_needTrackStartOnPlay && track != null) {
        _needTrackStartOnPlay = false;
        ScrobbleController.instance.onTrackStart(track);
        PluginRegistry.instance.dispatchTrackStart(TrackStartEvent(track));
        _historyNotifier?.recordPlay(track);
      }
      state = state.copyWith(status: PlayerStatus.playing);
      DiscordService.update(state, positionSecs: pos);
      PluginRegistry.instance.dispatchPlayPause(
        PlayPauseEvent(isPlaying: true, position: state.position),
      );
      _startTimer();
    } finally {
      _playPauseBusy = false;
    }
  }

  Future<void> pause() async {
    if (_playPauseBusy) return;
    _playPauseBusy = true;
    try {
      await AudioService.pause();
      var pos = state.position;
      try {
        final p = await backend.getPosition();
        pos = Duration(milliseconds: (p.positionSecs * 1000).round());
      } catch (_) {}
      if (!mounted) return;
      state = state.copyWith(status: PlayerStatus.paused, position: pos);
      DiscordService.update(state);
      PluginRegistry.instance.dispatchPlayPause(
        PlayPauseEvent(isPlaying: false, position: state.position),
      );
      _stopTimer();
      unawaited(persistPlayback());
    } finally {
      _playPauseBusy = false;
    }
  }

  void _lockSeek(
    Duration position, {
    Duration hold = const Duration(seconds: 8),
  }) {
    _seeking = true;
    _seekHoldPosition = position;
    _seekHoldUntil = DateTime.now().add(hold);
  }

  void _unlockSeek() {
    _seeking = false;
    _seekHoldPosition = null;
    _seekHoldUntil = null;
  }

  void _releaseSeekIfCaughtUp(Duration enginePos) {
    if (!_seeking) return;
    final target = _seekHoldPosition;
    final until = _seekHoldUntil;
    final close =
        target != null &&
        (enginePos.inMilliseconds - target.inMilliseconds).abs() < 400;
    final expired = until != null && !DateTime.now().isBefore(until);
    if (close || expired) _unlockSeek();
  }

  Future<void> seek(Duration position) async {
    final sec = position.inMilliseconds / 1000.0;
    _lockSeek(position);
    try {
      await AudioService.seek(sec);
      if (!mounted) return;
      state = state.copyWith(position: position);
      if (state.status == PlayerStatus.playing) {
        DiscordService.updateAfterSeek(state, sec);
      }
      _seekHoldUntil = DateTime.now().add(const Duration(milliseconds: 1200));
      final t = state.currentTrack;
      if (t != null) {
        PositionStore.instance.remember(
          t.path,
          sec,
          t.durationSecs,
          force: true,
        );
      }
    } catch (_) {
      _unlockSeek();
    }
  }

  void seekPreview(Duration position) {
    _lockSeek(position);
    state = state.copyWith(position: position);
  }

  Future<void> seekCommit(Duration position) async {
    final sec = position.inMilliseconds / 1000.0;
    _lockSeek(position);
    try {
      await AudioService.seek(sec);
      if (!mounted) return;
      state = state.copyWith(position: position);
      if (state.status == PlayerStatus.playing) {
        DiscordService.updateAfterSeek(state, sec);
      }
      _seekHoldUntil = DateTime.now().add(const Duration(milliseconds: 1200));
      final t = state.currentTrack;
      if (t != null) {
        PositionStore.instance.remember(
          t.path,
          sec,
          t.durationSecs,
          force: true,
        );
      }
    } catch (_) {
      _unlockSeek();
    }
  }

  Future<void> setVolume(double volume) async {
    if (backend.isExclusiveMode()) return;
    final v = volume.clamp(0.0, 1.0);
    await AudioService.setVolume(v);
    state = state.copyWith(volume: v);
    _saveVolume(v);
  }

  Future<void> next() => skipNext();
  Future<void> previous() => skipPrevious();

  Future<void> skipNext() async {
    final s = state;
    if (s.queue.isEmpty) return;
    int idx;
    var q = s.queue;
    if (s.hasNext) {
      idx = s.queueIndex + 1;
    } else if (s.loopMode == LoopMode.playlist) {
      idx = 0;
      if (s.shuffle) q = _shuffleUpcoming(s.queue, 0);
    } else {
      return;
    }
    state = state.copyWith(queue: q, queueIndex: idx);
    await _loadAndPlay(q[idx], stopFirst: !_handlingTrackEnd);
  }

  Future<void> skipPrevious() async {
    final s = state;
    if (s.queue.isEmpty) return;
    if (s.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    int idx;
    if (s.hasPrevious) {
      idx = s.queueIndex - 1;
    } else if (s.loopMode == LoopMode.playlist) {
      idx = s.queue.length - 1;
    } else {
      await seek(Duration.zero);
      return;
    }
    state = state.copyWith(queueIndex: idx);
    await _loadAndPlay(s.queue[idx]);
  }

  // Queue mutation
  void addToQueueNext(Track track) {
    addAllToQueueNext([track]);
  }

  void addToQueueLast(Track track) {
    addAllToQueueLast([track]);
  }

  void addAllToQueueNext(List<Track> tracks) {
    final playable = keepExistingTracks(tracks, (p) => File(p).existsSync());
    if (playable.isEmpty) return;
    final q = List<Track>.from(state.queue);
    var insertAt = (state.queueIndex + 1).clamp(0, q.length);
    for (final track in playable) {
      q.insert(insertAt, track);
      insertAt++;
    }
    state = state.copyWith(queue: q);
  }

  void addAllToQueueLast(List<Track> tracks) {
    final playable = keepExistingTracks(tracks, (p) => File(p).existsSync());
    if (playable.isEmpty) return;
    state = state.copyWith(queue: [...state.queue, ...playable]);
  }

  Future<void> playNext(Track track) => playAllNext([track]);

  Future<void> playAllNext(List<Track> tracks) async {
    final playable = keepExistingTracks(tracks, (p) => File(p).existsSync());
    if (playable.isEmpty) return;
    if (state.currentTrack == null) {
      await loadWithQueue(playable.first, playable);
      return;
    }
    addAllToQueueNext(playable);
  }

  void removeFromQueue(int index) {
    final q = List<Track>.from(state.queue);
    if (index < 0 || index >= q.length) return;
    q.removeAt(index);
    int newIdx = state.queueIndex;
    if (index < newIdx) newIdx -= 1;
    newIdx = newIdx.clamp(0, q.isEmpty ? 0 : q.length - 1);
    state = state.copyWith(queue: q, queueIndex: newIdx);
  }

  // Reorder the queue
  void reorderQueue(int oldIndex, int newIndex) {
    final q = List<Track>.from(state.queue);
    final cur = state.queueIndex;
    if (oldIndex < newIndex) newIndex -= 1;
    final track = q.removeAt(oldIndex);
    q.insert(newIndex, track);

    int newCurrent = cur;
    if (oldIndex == cur) {
      newCurrent = newIndex;
    } else if (oldIndex < cur && newIndex >= cur) {
      newCurrent = cur - 1;
    } else if (oldIndex > cur && newIndex < cur) {
      newCurrent = cur + 1;
    }

    state = state.copyWith(queue: q, queueIndex: newCurrent);
  }

  Future<void> jumpToQueue(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    final track = state.queue[index];
    state = state.copyWith(queueIndex: index);
    await _loadAndPlay(track);
  }

  Future<void> playKeepingQueue(Track track) async {
    final q = state.queue;
    final existing = q.indexWhere((t) => t.path == track.path);
    if (existing >= 0) {
      await jumpToQueue(existing);
      return;
    }
    if (q.isEmpty || state.currentTrack == null) {
      await loadWithQueue(track, [track]);
      return;
    }
    addAllToQueueNext([track]);
    await jumpToQueue(state.queueIndex + 1);
  }

  void cycleLoopMode() {
    state = state.copyWith(
      loopMode:
          LoopMode.values[(state.loopMode.index + 1) % LoopMode.values.length],
    );
  }

  void setLoopMode(LoopMode m) => state = state.copyWith(loopMode: m);

  void toggleShuffle() {
    if (state.shuffle) {
      state = state.copyWith(shuffle: false);
      return;
    }
    state = state.copyWith(
      shuffle: true,
      queue: _shuffleUpcoming(state.queue, state.queueIndex),
    );
  }
    void setShuffle(bool enabled) {
    if (state.shuffle == enabled) return;

    if (enabled) {
      state = state.copyWith(
        shuffle: true,
        queue: _shuffleUpcoming(state.queue, state.queueIndex),
      );
    } else {
      state = state.copyWith(shuffle: false);
    }
  }


  List<Track> _shuffleUpcoming(List<Track> queue, int index) {
    if (queue.length <= 1 || index < 0 || index >= queue.length - 1) {
      return List<Track>.from(queue);
    }
    final head = queue.sublist(0, index + 1);
    final rest = queue.sublist(index + 1)..shuffle(_rng);
    return [...head, ...rest];
  }

  void _startTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _poll(),
    );
  }

  void _stopTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  Future<void> _poll() async {
    if (state.currentTrack == null || state.status == PlayerStatus.loading) {
      return;
    }
    try {
      final pos = await backend.getPosition();
      if (!mounted || state.status == PlayerStatus.loading) return;
      final newPos = Duration(milliseconds: (pos.positionSecs * 1000).round());
      final dur = Duration(milliseconds: (pos.durationSecs * 1000).round());
      final effDur = dur.inMilliseconds > 0
          ? dur
          : (state.currentTrack?.duration ?? Duration.zero);

      ScrobbleController.instance.onPositionUpdate(newPos);
      PluginRegistry.instance.dispatchPositionUpdate(
        PositionUpdateEvent(position: newPos, duration: effDur),
      );

      if (state.status == PlayerStatus.playing &&
          !_seeking &&
          !_handlingTrackEnd &&
          !_deviceReinitBusy &&
          !_playPauseBusy) {
        final posSecs = pos.positionSecs;
        if ((posSecs - _lastAdvancingPositionSecs).abs() < 0.08) {
          _stallTicks++;
          if (_stallTicks >= 6) {
            _stallTicks = 0;
            Logger.warnPlayerProvider('playback stall at ${posSecs}s');
            await _recoverAfterOutputRouteChange(null);
            return;
          }
        } else {
          _stallTicks = 0;
          _lastAdvancingPositionSecs = posSecs;
        }
      }

      if (state.status == PlayerStatus.playing &&
          !_seeking &&
          !_handlingTrackEnd &&
          abLoopShouldWrap(
            positionSecs: pos.positionSecs,
            aSecs: state.loopASecs,
            bSecs: state.loopBSecs,
          )) {
        final a = state.loopASecs ?? 0;
        await seek(Duration(milliseconds: (a * 1000).round()));
        return;
      }

      final trackEnded = _shouldHandleTrackEnd(pos);
      if (trackEnded) {
        if (_handlingTrackEnd) return;
        _handlingTrackEnd = true;
        _stopTimer();
        final completed = state.currentTrack;
        if (completed != null) {
          PluginRegistry.instance.dispatchTrackComplete(
            TrackCompleteEvent(completed),
          );
        }
        await _onTrackEnd();
        _handlingTrackEnd = false;
        return;
      }
      _lastPollPositionSecs = pos.positionSecs;
      _releaseSeekIfCaughtUp(newPos);
      if (_seeking) {
        if (effDur != state.currentTrack?.duration) {
          state = state.copyWith(
            currentTrack: state.currentTrack?.copyWithDuration(effDur),
          );
        }
        return;
      }
      state = state.copyWith(
        position: newPos,
        currentTrack: effDur != state.currentTrack?.duration
            ? state.currentTrack?.copyWithDuration(effDur)
            : state.currentTrack,
      );
      _rememberTicks++;
      if (_rememberTicks >= 10) {
        _rememberTicks = 0;
        unawaited(persistPlayback());
      }
    } catch (_) {}
  }

  Future<void> _onTrackEnd() async {
    final s = state;
    final stopAfter = _readSettings?.call().stopAfter ?? StopAfterMode.off;
    ScrobbleController.instance.onTrackStop();
    PluginRegistry.instance.dispatchTrackStop(TrackStopEvent(s.currentTrack));
    if (s.currentTrack != null) {
      PositionStore.instance.clearPath(s.currentTrack!.path);
    }

    if (s.sleepMode == SleepTimerMode.endOfTrack) {
      _sleepTimer?.cancel();
      _sleepTimer = null;
      _crossfadeQueued = false;
      state = state.copyWith(
        status: PlayerStatus.paused,
        position: s.currentTrack?.duration ?? Duration.zero,
        sleepMode: SleepTimerMode.off,
        clearSleepUntil: true,
      );
      DiscordService.update(state);
      unawaited(persistPlayback());
      return;
    }

    if (stopAfter == StopAfterMode.track) {
      _crossfadeQueued = false;
      state = state.copyWith(
        status: PlayerStatus.paused,
        position: s.currentTrack?.duration ?? Duration.zero,
      );
      DiscordService.update(state);
      return;
    }
    if (stopAfter == StopAfterMode.album) {
      final next = s.queueIndex + 1 < s.queue.length
          ? s.queue[s.queueIndex + 1]
          : null;
      if (next == null ||
          next.album != s.currentTrack?.album ||
          next.albumArtist != s.currentTrack?.albumArtist) {
        state = state.copyWith(
          status: PlayerStatus.paused,
          position: s.currentTrack?.duration ?? Duration.zero,
        );
        DiscordService.update(state);
        _crossfadeQueued = false;
        return;
      }
    }

    // Loop mode
    switch (s.loopMode) {
      case LoopMode.track:
        final track = s.currentTrack;
        if (track != null) {
          await _loadAndPlay(track, resume: false);
        }
      case LoopMode.album:
        final album = s.queue
            .where((t) => t.album == s.currentTrack?.album)
            .toList();
        final idx = album.indexWhere((t) => t.path == s.currentTrack?.path);
        final next = idx >= 0 && idx < album.length - 1
            ? album[idx + 1]
            : album.first;
        final qIdx = s.queue.indexWhere((t) => t.path == next.path);
        state = state.copyWith(queueIndex: qIdx >= 0 ? qIdx : 0);
        await _loadAndPlay(next, stopFirst: false);
      case LoopMode.playlist:
        await skipNext();
      case LoopMode.off:
        if (s.hasNext) {
          await skipNext();
        } else {
          _crossfadeQueued = false;
          state = state.copyWith(
            status: PlayerStatus.paused,
            position: s.currentTrack?.duration ?? Duration.zero,
          );
          DiscordService.update(state);
        }
    }
  }

  double _trackEndLead() {
    final s = _readSettings?.call();
    return trackEndLeadSecs(
      crossfadeSecs: s?.crossfadeSecs ?? 0,
      exclusive: s?.outputMode == AudioOutputMode.exclusive,
      hasSuccessor:
          state.loopMode != LoopMode.track &&
          (state.hasNext || state.loopMode == LoopMode.playlist),
      stopAfter:
          (s != null && s.stopAfter != StopAfterMode.off) ||
          state.sleepMode == SleepTimerMode.endOfTrack,
    );
  }

  bool _shouldHandleTrackEnd(backend.PlaybackPosition pos) {
    if (pos.durationSecs <= 0) return false;

    final lead = _trackEndLead();
    if (_crossfadeQueued) {
      if (pos.positionSecs + lead + 0.5 < pos.durationSecs) {
        _crossfadeQueued = false;
      }
      return false;
    }

    final nearEnd = pos.positionSecs >= pos.durationSecs - lead;
    if (nearEnd) {
      if (lead > 0.15) _crossfadeQueued = true;
      return true;
    }

    final backendStopped =
        state.status == PlayerStatus.playing &&
        !backend.isPlaying() &&
        !_seeking &&
        !_playPauseBusy;
    if (!backendStopped) return false;

    return pos.positionSecs >= pos.durationSecs - 1.5 ||
        _lastPollPositionSecs >= pos.durationSecs - 1.5;
  }

  @override
  void dispose() {
    _disposed = true;
    _sleepTimer?.cancel();
    unawaited(persistPlayback());
    _stopTimer();
    AudioService.stopWatchdog();
    ScrobbleController.instance.dispose();
    DiscordService.dispose();
    super.dispose();
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((
  ref,
) {
  final n = PlayerNotifier();
  n.injectSettingsReader(() => ref.read(settingsProvider));
  n.injectHistoryNotifier(ref.read(historyProvider.notifier));
  Future.microtask(() {
    if (ref.exists(audioDeviceProvider)) {
      final devState = ref.read(audioDeviceProvider);
      devState.whenData((_) {
        n.injectDeviceNotifier(ref.read(audioDeviceProvider.notifier));
      });
    }
  });
  return n;
});
