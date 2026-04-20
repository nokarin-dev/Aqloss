import 'package:aqloss/models/track.dart';
import 'package:aqloss/models/playlist.dart';

class LibraryService {
  static final LibraryService _instance = LibraryService._();
  factory LibraryService() => _instance;
  LibraryService._();

  final List<Track> _tracks = [];
  final List<Playlist> _playlists = [];

  // Track
  List<Track> get allTracks => List.unmodifiable(_tracks);

  void addTracks(List<Track> tracks) {
    final existingPaths = _tracks.map((t) => t.path).toSet();
    final newTracks = tracks
        .where((t) => !existingPaths.contains(t.path))
        .toList();
    _tracks.addAll(newTracks);
    _tracks.sort((a, b) {
      final albumCmp = (a.album ?? '').compareTo(b.album ?? '');
      if (albumCmp != 0) return albumCmp;
      return (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
    });
  }

  void clearTracks() => _tracks.clear();

  // Playlist
  List<Playlist> get allPlaylists => List.unmodifiable(_playlists);

  void addPlaylist(Playlist playlist) => _playlists.add(playlist);

  void removePlaylist(String id) => _playlists.removeWhere((p) => p.id == id);

  void updatePlaylist(Playlist updated) {
    final idx = _playlists.indexWhere((p) => p.id == updated.id);
    if (idx != -1) _playlists[idx] = updated;
  }
}
