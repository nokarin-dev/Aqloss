import 'dart:async';
import 'dart:convert';

import 'package:aqloss/util/track_positions.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPositions = 'aqloss_track_positions';
const _kSession = 'aqloss_playback_session';

class PlaybackSession {
  final List<String> paths;
  final int index;
  final double positionSecs;
  final int loopMode;
  final bool shuffle;

  const PlaybackSession({
    required this.paths,
    required this.index,
    required this.positionSecs,
    required this.loopMode,
    required this.shuffle,
  });

  Map<String, dynamic> toJson() => {
    'paths': paths,
    'index': index,
    'position': positionSecs,
    'loop': loopMode,
    'shuffle': shuffle,
  };

  static PlaybackSession? fromJson(Map<String, dynamic> json) {
    final raw = json['paths'];
    if (raw is! List) return null;
    final paths = raw.whereType<String>().toList();
    if (paths.isEmpty) return null;
    return PlaybackSession(
      paths: paths,
      index: (json['index'] as num?)?.toInt() ?? 0,
      positionSecs: (json['position'] as num?)?.toDouble() ?? 0,
      loopMode: (json['loop'] as num?)?.toInt() ?? 0,
      shuffle: json['shuffle'] == true,
    );
  }
}

class PositionStore {
  PositionStore();
  static final PositionStore instance = PositionStore();

  Map<String, double> _positions = {};
  PlaybackSession? _session;
  Future<void>? _loading;
  bool _loaded = false;
  DateTime? _lastWrite;

  PlaybackSession? get session => _session;

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPositions);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _positions = {
            for (final e in decoded.entries)
              if (e.value is num) e.key.toString(): (e.value as num).toDouble(),
          };
        }
      }
      final sessionRaw = prefs.getString(_kSession);
      if (sessionRaw != null && sessionRaw.isNotEmpty) {
        final decoded = jsonDecode(sessionRaw);
        if (decoded is Map) {
          _session = PlaybackSession.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      }
    } catch (_) {}
    _loaded = true;
  }

  double? resumeSecs(String path, double duration) {
    final saved = _positions[path];
    if (saved == null) return null;
    return resumePositionSecs(saved, duration);
  }

  void remember(
    String path,
    double secs,
    double duration, {
    bool force = false,
  }) {
    if (!_loaded) return;
    if (!shouldSavePosition(secs, duration)) {
      if (_positions.remove(path) != null) unawaited(_flushPositions());
      return;
    }
    _positions = upsertPosition(_positions, path, secs);
    if (!force &&
        _lastWrite != null &&
        DateTime.now().difference(_lastWrite!) < const Duration(seconds: 5)) {
      return;
    }
    unawaited(_flushPositions());
  }

  void clearPath(String path) {
    if (_positions.remove(path) != null) unawaited(_flushPositions());
  }

  Future<void> saveSession(PlaybackSession session) async {
    _session = session;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSession, jsonEncode(session.toJson()));
    } catch (_) {}
  }

  Future<void> _flushPositions() async {
    _lastWrite = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPositions, jsonEncode(_positions));
    } catch (_) {}
  }
}
