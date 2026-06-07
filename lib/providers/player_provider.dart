import 'dart:async';
import 'dart:math' as math;
import 'package:aqloss/services/audio_service.dart';
import 'package:aqloss/services/scrobble_controller.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/util/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/audio_device_provider.dart';
import 'package:aqloss/providers/history_provider.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/services/discord_service.dart';
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

  const PlayerState({
    this.currentTrack,
    this.status = PlayerStatus.idle,
    this.position = Duration.zero,
    this.volume = 1.0,
    this.loopMode = LoopMode.off,
    this.shuffle = false,
    this.queue = const [],
    this.queueIndex = 0,
  });

  PlayerState copyWith({
    Track? currentTrack,
    PlayerStatus? status,
    Duration? position,
    double? volume,
    LoopMode? loopMode,
    bool? shuffle,
    List<Track>? queue,
    int? queueIndex,
  }) => PlayerState(
    currentTrack: currentTrack ?? this.currentTrack,
    status: status ?? this.status,
    position: position ?? this.position,
    volume: volume ?? this.volume,
    loopMode: loopMode ?? this.loopMode,
    shuffle: shuffle ?? this.shuffle,
    queue: queue ?? this.queue,
    queueIndex: queueIndex ?? this.queueIndex,
  );

  bool get hasPrevious => queueIndex > 0;
  bool get hasNext => queueIndex < queue.length - 1;
  Track? get previousTrack => hasPrevious ? queue[queueIndex - 1] : null;
  Track? get nextTrack => hasNext ? queue[queueIndex + 1] : null;
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  Timer? _positionTimer;
  bool _disposed = false;
  bool _handlingTrackEnd = false;
  bool _playPauseBusy = false;
  SettingsState Function()? _readSettings;
  HistoryNotifier? _historyNotifier;

  // Guards against concurrent device-change reinit
  bool _deviceReinitBusy = false;

  PlayerNotifier() : super(const PlayerState()) {
    _restoreVolume();

    // Freeze recovery
    AudioService.onFreezeDetected = () async {
      final track = state.currentTrack;
      if (track == null) return;
      Logger.warnPlayerProvider(
        'freeze recovery - reloading ${track.displayTitle}',
      );
      final posSecs = state.position.inMilliseconds / 1000.0;
      try {
        await AudioService.loadTrack(track.path);
        if (posSecs > 1.0) await AudioService.seek(posSecs);
        await AudioService.play();
        if (mounted) state = state.copyWith(status: PlayerStatus.playing);
        _startTimer();
      } catch (e) {
        Logger.errorPlayerProvider('freeze recovery failed: $e');
        if (mounted) state = state.copyWith(status: PlayerStatus.error);
      }
    };

    // Audio device changed
    AudioService.onDeviceChanged = (String? newDefaultDeviceId) async {
      if (!mounted || _deviceReinitBusy) return;
      _deviceReinitBusy = true;

      final wasPlaying = state.status == PlayerStatus.playing;
      final track = state.currentTrack;
      final posSecs = state.position.inMilliseconds / 1000.0;

      _stopTimer();
      if (mounted) {
        state = state.copyWith(status: PlayerStatus.paused);
      }

      Logger.warnPlayerProvider(
        'device changed → $newDefaultDeviceId  wasPlaying=$wasPlaying',
      );
      _deviceNotifier?.refreshAfterDeviceChange(newDefaultDeviceId);

      try {
        final settings = _readSettings?.call();
        final exclusive = settings?.outputMode == AudioOutputMode.exclusive;

        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;

        final ok = await AudioService.reinitToDevice(
          deviceId: newDefaultDeviceId,
          exclusive: exclusive,
        );

        if (!mounted) return;
        if (!ok) {
          state = state.copyWith(status: PlayerStatus.error);
          _deviceReinitBusy = false;
          return;
        }

        if (wasPlaying && track != null) {
          try {
            state = state.copyWith(status: PlayerStatus.loading);
            await AudioService.loadTrack(track.path);
            if (!mounted) return;
            if (posSecs > 0.5) await AudioService.seek(posSecs);
            await AudioService.play();
            if (mounted) {
              state = state.copyWith(status: PlayerStatus.playing);
              _startTimer();
            }
          } catch (e) {
            Logger.errorPlayerProvider('device-change reload failed: $e');
            if (mounted) state = state.copyWith(status: PlayerStatus.error);
          }
        }
      } finally {
        _deviceReinitBusy = false;
      }
    };
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
    int idx;
    if (atIndex != null && atIndex >= 0 && atIndex < queue.length) {
      idx = atIndex;
    } else {
      idx = queue.indexWhere((t) => t.path == track.path);
      if (idx < 0) idx = 0;
    }
    state = state.copyWith(queue: queue, queueIndex: idx);
    await _loadAndPlay(track);
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

  Future<void> _loadAndPlay(Track track, {bool stopFirst = true}) async {
    _stopTimer();
    _handlingTrackEnd = false;
    ScrobbleController.instance.onTrackStop();
    state = state.copyWith(
      status: PlayerStatus.loading,
      currentTrack: track,
      position: Duration.zero,
    );
    try {
      if (stopFirst) await AudioService.stop();
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
      await AudioService.play();
      if (!mounted) return;
      state = state.copyWith(status: PlayerStatus.playing);
      DiscordService.update(state, positionSecs: 0.0);
      ScrobbleController.instance.onTrackStart(track);
      _historyNotifier?.recordPlay(track);
      _startTimer();
    } catch (e) {
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
        Logger.warnPlayerProvider('play() failed ($e) — attempting reinit');
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
      state = state.copyWith(status: PlayerStatus.playing);
      DiscordService.update(state, positionSecs: pos);
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
      state = state.copyWith(status: PlayerStatus.paused);
      DiscordService.update(state);
      _stopTimer();
    } finally {
      _playPauseBusy = false;
    }
  }

  Future<void> seek(Duration position) async {
    final sec = position.inMilliseconds / 1000.0;
    await AudioService.seek(sec);
    state = state.copyWith(position: position);
    if (state.status == PlayerStatus.playing) {
      DiscordService.updateAfterSeek(state, sec);
    }
  }

  void seekPreview(Duration position) {
    state = state.copyWith(position: position);
  }

  Future<void> seekCommit(Duration position) async {
    final sec = position.inMilliseconds / 1000.0;
    await AudioService.seek(sec);
    state = state.copyWith(position: position);
    if (state.status == PlayerStatus.playing) {
      DiscordService.updateAfterSeek(state, sec);
    }
  }

  Future<void> setVolume(double volume) async {
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
    if (s.shuffle) {
      idx = _rand(s.queue.length, exclude: s.queueIndex);
    } else if (s.hasNext) {
      idx = s.queueIndex + 1;
    } else if (s.loopMode == LoopMode.playlist) {
      idx = 0;
    } else {
      return;
    }
    state = state.copyWith(queueIndex: idx);
    await _loadAndPlay(s.queue[idx], stopFirst: !_handlingTrackEnd);
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
    final q = List<Track>.from(state.queue);
    final idx = state.queueIndex;
    final insertAt = (idx + 1).clamp(0, q.length);
    q.insert(insertAt, track);
    state = state.copyWith(queue: q);
  }

  void addToQueueLast(Track track) {
    final q = List<Track>.from(state.queue)..add(track);
    state = state.copyWith(queue: q);
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

  void cycleLoopMode() {
    state = state.copyWith(
      loopMode:
          LoopMode.values[(state.loopMode.index + 1) % LoopMode.values.length],
    );
  }

  void setLoopMode(LoopMode m) => state = state.copyWith(loopMode: m);
  void toggleShuffle() => state = state.copyWith(shuffle: !state.shuffle);

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

      if (pos.durationSecs > 0 && pos.positionSecs >= pos.durationSecs - 0.1) {
        if (_handlingTrackEnd) return;
        _handlingTrackEnd = true;
        _stopTimer();
        await _onTrackEnd();
        _handlingTrackEnd = false;
        return;
      }
      state = state.copyWith(
        position: newPos,
        currentTrack: effDur != state.currentTrack?.duration
            ? state.currentTrack?.copyWithDuration(effDur)
            : state.currentTrack,
      );
    } catch (_) {}
  }

  Future<void> _onTrackEnd() async {
    final s = state;
    final stopAfter = _readSettings?.call().stopAfter ?? StopAfterMode.off;
    ScrobbleController.instance.onTrackStop();

    if (stopAfter == StopAfterMode.track) {
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
        return;
      }
    }

    // Loop mode
    switch (s.loopMode) {
      case LoopMode.track:
        await seek(Duration.zero);
        await play();
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
          state = state.copyWith(
            status: PlayerStatus.paused,
            position: s.currentTrack?.duration ?? Duration.zero,
          );
          DiscordService.update(state);
        }
    }
  }

  int _rand(int length, {required int exclude}) {
    if (length <= 1) return 0;
    int i;
    do {
      i = math.Random().nextInt(length);
    } while (i == exclude);
    return i;
  }

  @override
  void dispose() {
    _disposed = true;
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
