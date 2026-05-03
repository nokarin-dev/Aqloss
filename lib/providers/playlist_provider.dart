import 'dart:convert';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';
import '../models/track.dart';

const _kPlaylistsKey = 'aqloss_playlists';

class PlaylistNotifier extends StateNotifier<List<Playlist>> {
  PlaylistNotifier() : super([]) {
    _load();
  }

  // Persistence
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kPlaylistsKey) ?? [];
    final playlists = raw
        .map((s) {
          try {
            return Playlist.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<Playlist>()
        .toList();
    state = playlists;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kPlaylistsKey,
      state.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  // CRUD
  Future<Playlist> create(String name) async {
    final pl = Playlist.create(name);
    state = [...state, pl];
    await _save();
    return pl;
  }

  Future<void> rename(String id, String newName) async {
    state = state
        .map((p) => p.id == id ? p.copyWith(name: newName) : p)
        .toList();
    await _save();
  }

  Future<void> delete(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _save();
  }

  Future<void> addTrack(String playlistId, Track track) async {
    state = state.map((p) {
      if (p.id != playlistId) return p;

      // Avoid duplicates
      if (p.tracks.any((t) => t.path == track.path)) return p;
      return p.addTrack(track);
    }).toList();
    await _save();
  }

  Future<void> addTracks(String playlistId, List<Track> tracks) async {
    state = state.map((p) {
      if (p.id != playlistId) return p;
      final existing = p.tracks.map((t) => t.path).toSet();
      final newTracks = tracks
          .where((t) => !existing.contains(t.path))
          .toList();
      return p.copyWith(tracks: [...p.tracks, ...newTracks]);
    }).toList();
    await _save();
  }

  Future<void> removeTrack(String playlistId, int index) async {
    state = state.map((p) {
      if (p.id != playlistId) return p;
      return p.removeTrackAt(index);
    }).toList();
    await _save();
  }

  Future<void> reorderTrack(String playlistId, int oldIdx, int newIdx) async {
    state = state.map((p) {
      if (p.id != playlistId) return p;
      return p.reorder(oldIdx, newIdx);
    }).toList();
    await _save();
  }

  Playlist? find(String id) => state.where((p) => p.id == id).firstOrNull;
}

final playlistProvider =
    StateNotifierProvider<PlaylistNotifier, List<Playlist>>(
      (ref) => PlaylistNotifier(),
    );
