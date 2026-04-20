import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/models/audio_format.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

enum LibraryStatus { idle, scanning, done, error }

class LibraryState {
  final List<Track> tracks;
  final LibraryStatus status;
  final String? errorMessage;
  final List<String> folders;
  final String query;

  const LibraryState({
    this.tracks = const [],
    this.status = LibraryStatus.idle,
    this.errorMessage,
    this.folders = const [],
    this.query = '',
  });

  LibraryState copyWith({
    List<Track>? tracks,
    LibraryStatus? status,
    String? errorMessage,
    List<String>? folders,
    String? query,
  }) =>
      LibraryState(
        tracks: tracks ?? this.tracks,
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
        folders: folders ?? this.folders,
        query: query ?? this.query,
      );

  List<Track> get filteredTracks {
    if (query.isEmpty) return tracks;
    final q = query.toLowerCase();
    return tracks.where((t) {
      return (t.title?.toLowerCase().contains(q) ?? false) ||
          (t.artist?.toLowerCase().contains(q) ?? false) ||
          (t.album?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<Track> get losslessTracks =>
      tracks.where((t) => AudioFormat.fromExtension(t.format).isLossless).toList();

  int get totalTracks => tracks.length;

  Duration get totalDuration =>
      tracks.fold(Duration.zero, (sum, t) => sum + t.duration);
}

const _kFoldersKey = 'aqloss_music_folders';

class LibraryNotifier extends StateNotifier<LibraryState> {
  LibraryNotifier() : super(const LibraryState()) {
    _restoreFolders();
  }

  // Persistence
  Future<void> _restoreFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_kFoldersKey) ?? [];
    if (saved.isEmpty) return;
    state = state.copyWith(folders: saved, status: LibraryStatus.scanning);
    await _scanAll(saved);
  }

  Future<void> _saveFolders(List<String> folders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kFoldersKey, folders);
  }

  // Folder management
  Future<void> addFolder(String folderPath) async {
    if (state.folders.contains(folderPath)) return;
    final updated = [...state.folders, folderPath];
    state = state.copyWith(folders: updated, status: LibraryStatus.scanning);
    await _saveFolders(updated);
    await _scanAll(updated);
  }

  Future<void> removeFolder(String folderPath) async {
    final updated = state.folders.where((f) => f != folderPath).toList();
    state = state.copyWith(folders: updated, status: LibraryStatus.scanning);
    await _saveFolders(updated);
    if (updated.isEmpty) {
      state = state.copyWith(
          tracks: [], status: LibraryStatus.idle);
      return;
    }
    await _scanAll(updated);
  }

  Future<void> rescanAll() async {
    if (state.folders.isEmpty) return;
    state = state.copyWith(status: LibraryStatus.scanning);
    await _scanAll(state.folders);
  }

  // Internal scan
  Future<void> _scanAll(List<String> folders) async {
    try {
      final results = await Future.wait(
        folders.map((f) => backend.scanDirectory(path: f)),
      );

      final seen = <String>{};
      final allPaths = results
          .expand((paths) => paths)
          .where((p) => seen.add(p))
          .toList();

      // Read metadata for each file
      final tracks = <Track>[];
      for (final path in allPaths) {
        try {
          final info = await backend.readMetadata(path: path);
          tracks.add(Track(
            path: info.path,
            title: info.title,
            artist: info.artist,
            album: info.album,
            albumArtist: info.albumArtist,
            trackNumber: info.trackNumber?.toInt(),
            durationSecs: info.durationSecs,
            sampleRate: info.sampleRate,
            bitDepth: info.bitDepth?.toInt(),
            channels: info.channels,
            format: info.format,
            fileSizeBytes: info.fileSizeBytes.toInt(),
          ));
        } catch (_) { }
      }

      tracks.sort((a, b) {
        final ac = (a.albumArtist ?? a.artist ?? '').compareTo(
            b.albumArtist ?? b.artist ?? '');
        if (ac != 0) return ac;
        final bc = (a.album ?? '').compareTo(b.album ?? '');
        if (bc != 0) return bc;
        return (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
      });

      state = state.copyWith(tracks: tracks, status: LibraryStatus.done);
    } catch (e) {
      state = state.copyWith(
        status: LibraryStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  // Search
  void setQuery(String query) => state = state.copyWith(query: query);

  void clearAll() {
    _saveFolders([]);
    state = const LibraryState();
  }
}

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, LibraryState>(
  (ref) => LibraryNotifier(),
);
