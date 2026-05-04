import 'dart:async';
import 'dart:math' as math;
import 'package:aqloss/services/audio_service.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:flutter_riverpod/legacy.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/services/discord_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:aqloss/providers/settings_provider.dart'
    show ReplayGainMode, StopAfterMode;

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

  SettingsState Function()? _readSettings;

  PlayerNotifier() : super(const PlayerState()) {
    _restoreVolume();
  }

  void injectSettingsReader(SettingsState Function() reader) {
    _readSettings = reader;
  }

  @override
  bool get mounted => !_disposed;

  // Volume
  Future<void> _restoreVolume() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = (prefs.getDouble(_kVolumeKey) ?? 1.0).clamp(0.0, 1.0);
    if (mounted) state = state.copyWith(volume: saved);
  }

  Future<void> _saveVolume(double v) async {
    (await SharedPreferences.getInstance()).setDouble(_kVolumeKey, v);
  }

  // Queue
  Future<void> loadWithQueue(Track track, List<Track> queue) async {
    final idx = queue.indexWhere((t) => t.path == track.path);
    state = state.copyWith(queue: queue, queueIndex: idx < 0 ? 0 : idx);
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

  Future<void> _loadAndPlay(Track track) async {
    _stopTimer();
    _handlingTrackEnd = false;
    state = state.copyWith(
      status: PlayerStatus.loading,
      currentTrack: track,
      position: Duration.zero,
    );
    try {
      await AudioService.loadTrack(track.path);
      if (!mounted) return;

      final s = _readSettings?.call();
      if (s != null && s.replayGainEnabled) {
        final isInOrder = _isPlayingAlbumInOrder();
        await AudioService.applyReplayGainForTrack(
          mode: s.replayGainMode,
          preampDb: s.replayGainPreamp,
          trackGainDb: track.replayGainTrack,
          albumGainDb: track.replayGainAlbum,
          isPlayingInOrder: isInOrder,
        );
      }

      await AudioService.play();
      if (!mounted) return;
      state = state.copyWith(status: PlayerStatus.playing);
      DiscordService.update(state, positionSecs: 0.0);
      _startTimer();
    } catch (e) {
      if (mounted) state = state.copyWith(status: PlayerStatus.error);
    }
  }

  bool _isPlayingAlbumInOrder() {
    final q = state.queue;
    final idx = state.queueIndex;
    if (q.isEmpty || idx == 0) return false;
    final prev = q[idx - 1];
    final curr = q[idx];
    return prev.album == curr.album && prev.albumArtist == curr.albumArtist;
  }

  // Transport
  Future<void> play() async {
    await AudioService.play();
    if (!mounted) return;
    double pos = state.position.inMilliseconds / 1000.0;
    try {
      pos = (await backend.getPosition()).positionSecs;
    } catch (_) {}
    state = state.copyWith(status: PlayerStatus.playing);
    DiscordService.update(state, positionSecs: pos);
    _startTimer();
  }

  Future<void> pause() async {
    await AudioService.pause();
    state = state.copyWith(status: PlayerStatus.paused);
    DiscordService.update(state);
    _stopTimer();
  }

  Future<void> seek(Duration position) async {
    final posSec = position.inMilliseconds / 1000.0;
    await AudioService.seek(posSec);
    state = state.copyWith(position: position);
    if (state.status == PlayerStatus.playing) {
      DiscordService.updateAfterSeek(state, posSec);
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

    int nextIdx;
    if (s.shuffle) {
      nextIdx = _randomIndex(s.queue.length, exclude: s.queueIndex);
    } else if (s.hasNext) {
      nextIdx = s.queueIndex + 1;
    } else if (s.loopMode == LoopMode.playlist) {
      nextIdx = 0;
    } else {
      return;
    }

    state = state.copyWith(queueIndex: nextIdx);
    await _loadAndPlay(s.queue[nextIdx]);
  }

  Future<void> skipPrevious() async {
    final s = state;
    if (s.queue.isEmpty) return;

    if (s.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    int prevIdx;
    if (s.hasPrevious) {
      prevIdx = s.queueIndex - 1;
    } else if (s.loopMode == LoopMode.playlist) {
      prevIdx = s.queue.length - 1;
    } else {
      await seek(Duration.zero);
      return;
    }

    state = state.copyWith(queueIndex: prevIdx);
    await _loadAndPlay(s.queue[prevIdx]);
  }

  // Loop & Shuffle
  void cycleLoopMode() {
    final next =
        LoopMode.values[(state.loopMode.index + 1) % LoopMode.values.length];
    state = state.copyWith(loopMode: next);
  }

  void setLoopMode(LoopMode mode) => state = state.copyWith(loopMode: mode);
  void toggleShuffle() => state = state.copyWith(shuffle: !state.shuffle);

  // Position poll
  void _startTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _pollPosition(),
    );
  }

  void _stopTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  Future<void> _pollPosition() async {
    if (state.currentTrack == null) return;
    if (state.status == PlayerStatus.loading) return;
    try {
      final pos = await backend.getPosition();
      if (!mounted || state.status == PlayerStatus.loading) return;

      final newPos = Duration(milliseconds: (pos.positionSecs * 1000).round());
      final backendDur = Duration(
        milliseconds: (pos.durationSecs * 1000).round(),
      );
      final effectiveDur = backendDur.inMilliseconds > 0
          ? backendDur
          : (state.currentTrack?.duration ?? Duration.zero);

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
        currentTrack: effectiveDur != state.currentTrack?.duration
            ? state.currentTrack?.copyWithDuration(effectiveDur)
            : state.currentTrack,
      );
    } catch (_) {}
  }

  // Track end
  Future<void> _onTrackEnd() async {
    final s = state;

    // Stop after
    final stopAfter = _readSettings?.call().stopAfter ?? StopAfterMode.off;

    if (stopAfter == StopAfterMode.track) {
      state = state.copyWith(
        status: PlayerStatus.paused,
        position: s.currentTrack?.duration ?? Duration.zero,
      );
      DiscordService.update(state);
      return;
    }

    if (stopAfter == StopAfterMode.album) {
      final nextIdx = s.queueIndex + 1;
      final nextTrack = (nextIdx < s.queue.length) ? s.queue[nextIdx] : null;
      final sameAlbum =
          nextTrack != null &&
          nextTrack.album == s.currentTrack?.album &&
          nextTrack.albumArtist == s.currentTrack?.albumArtist;
      if (!sameAlbum) {
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
        final albumTracks = s.queue
            .where((t) => t.album == s.currentTrack?.album)
            .toList();
        final idx = albumTracks.indexWhere(
          (t) => t.path == s.currentTrack?.path,
        );
        if (idx >= 0 && idx < albumTracks.length - 1) {
          final next = albumTracks[idx + 1];
          final qIdx = s.queue.indexWhere((t) => t.path == next.path);
          state = state.copyWith(queueIndex: qIdx >= 0 ? qIdx : s.queueIndex);
          await _loadAndPlay(next);
        } else if (albumTracks.isNotEmpty) {
          final first = albumTracks.first;
          final qIdx = s.queue.indexWhere((t) => t.path == first.path);
          state = state.copyWith(queueIndex: qIdx >= 0 ? qIdx : 0);
          await _loadAndPlay(first);
        }

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

  // Helpers
  int _randomIndex(int length, {required int exclude}) {
    if (length <= 1) return 0;
    final rng = math.Random();
    int idx;
    do {
      idx = rng.nextInt(length);
    } while (idx == exclude);
    return idx;
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimer();
    DiscordService.dispose();
    super.dispose();
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((
  ref,
) {
  final notifier = PlayerNotifier();
  notifier.injectSettingsReader(() => ref.read(settingsProvider));
  return notifier;
});
