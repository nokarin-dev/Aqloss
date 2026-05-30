import 'dart:convert';

import 'package:aqloss/models/track.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kHistoryKey = 'aqloss_play_history';
const _kLovedKey = 'aqloss_loved_tracks';
const _kMaxHistory = 500;

// Models
class HistoryEntry {
  final Track track;
  final DateTime playedAt;

  const HistoryEntry({required this.track, required this.playedAt});

  Map<String, dynamic> toJson() => {
    'track': track.toJson(),
    'playedAt': playedAt.toIso8601String(),
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    track: Track.fromJson(json['track'] as Map<String, dynamic>),
    playedAt: DateTime.parse(json['playedAt'] as String),
  );
}

// History state
class HistoryState {
  final List<HistoryEntry> entries;
  final Set<String> lovedPaths;
  final bool loaded;

  const HistoryState({
    this.entries = const [],
    this.lovedPaths = const {},
    this.loaded = false,
  });

  bool isLoved(Track t) => lovedPaths.contains(t.path);

  List<HistoryEntry> get today {
    final now = DateTime.now();
    return entries
        .where(
          (e) =>
              e.playedAt.year == now.year &&
              e.playedAt.month == now.month &&
              e.playedAt.day == now.day,
        )
        .toList();
  }

  List<HistoryEntry> get thisWeek {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return entries.where((e) => e.playedAt.isAfter(cutoff)).toList();
  }

  List<String> get lovedPathList => List.unmodifiable(lovedPaths.toList());

  // Play count for a track path
  int playCount(String path) =>
      entries.where((e) => e.track.path == path).length;

  // Top N tracks by play count
  List<MapEntry<String, int>> topTracks({int limit = 10}) {
    final counts = <String, int>{};
    for (final e in entries) {
      counts[e.track.path] = (counts[e.track.path] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  // Total unique tracks played
  int get uniqueTracksPlayed => entries.map((e) => e.track.path).toSet().length;

  // Total listening time from history
  Duration get totalListeningTime =>
      entries.fold(Duration.zero, (sum, e) => sum + e.track.duration);

  HistoryState copyWith({
    List<HistoryEntry>? entries,
    Set<String>? lovedPaths,
    bool? loaded,
  }) => HistoryState(
    entries: entries ?? this.entries,
    lovedPaths: lovedPaths ?? this.lovedPaths,
    loaded: loaded ?? this.loaded,
  );
}

// Notifier
class HistoryNotifier extends StateNotifier<HistoryState> {
  HistoryNotifier() : super(const HistoryState()) {
    _load();
  }

  // Persistence
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();

    // History
    final rawHistory = p.getStringList(_kHistoryKey) ?? [];
    final entries = rawHistory
        .map((s) {
          try {
            return HistoryEntry.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<HistoryEntry>()
        .toList();

    // Loved
    final rawLoved = p.getString(_kLovedKey);
    final lovedPaths = <String>{};
    if (rawLoved != null) {
      try {
        final list = jsonDecode(rawLoved) as List<dynamic>;
        lovedPaths.addAll(list.cast<String>());
      } catch (_) {}
    }

    state = state.copyWith(
      entries: entries,
      lovedPaths: lovedPaths,
      loaded: true,
    );
  }

  Future<void> _saveHistory() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _kHistoryKey,
      state.entries.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> _saveLoved() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLovedKey, jsonEncode(state.lovedPaths.toList()));
  }

  // History API
  Future<void> recordPlay(Track track) async {
    final entry = HistoryEntry(track: track, playedAt: DateTime.now());

    final updated = [entry, ...state.entries];
    if (updated.length > _kMaxHistory) {
      updated.removeRange(_kMaxHistory, updated.length);
    }

    state = state.copyWith(entries: updated);
    await _saveHistory();
  }

  Future<void> clearHistory() async {
    state = state.copyWith(entries: []);
    await _saveHistory();
  }

  // Loved API
  // Toggle love state
  Future<bool> toggleLove(Track track) async {
    final loved = Set<String>.from(state.lovedPaths);
    final wasLoved = loved.contains(track.path);
    if (wasLoved) {
      loved.remove(track.path);
    } else {
      loved.add(track.path);
    }
    state = state.copyWith(lovedPaths: loved);
    await _saveLoved();
    return !wasLoved;
  }

  Future<void> setLoved(Track track, {required bool loved}) async {
    final set = Set<String>.from(state.lovedPaths);
    if (loved) {
      set.add(track.path);
    } else {
      set.remove(track.path);
    }
    state = state.copyWith(lovedPaths: set);
    await _saveLoved();
  }

  // Bulk-import loved paths
  Future<void> importLoved(List<String> paths) async {
    final set = Set<String>.from(state.lovedPaths)..addAll(paths);
    state = state.copyWith(lovedPaths: set);
    await _saveLoved();
  }
}

// Provider
final historyProvider = StateNotifierProvider<HistoryNotifier, HistoryState>(
  (ref) => HistoryNotifier(),
);
