import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import '../models/audio_format.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

enum LibraryStatus { idle, scanning, done, error }

enum SortField { title, artist, album, duration, format, dateAdded }

enum SortOrder { ascending, descending }

enum LibraryFilter { all, lossless, hiRes }

class LibraryState {
  final List<Track> tracks;
  final LibraryStatus status;
  final String? errorMessage;
  final List<String> folders;
  final String query;
  final SortField sortField;
  final SortOrder sortOrder;
  final LibraryFilter filter;

  const LibraryState({
    this.tracks = const [],
    this.status = LibraryStatus.idle,
    this.errorMessage,
    this.folders = const [],
    this.query = '',
    this.sortField = SortField.artist,
    this.sortOrder = SortOrder.ascending,
    this.filter = LibraryFilter.all,
  });

  LibraryState copyWith({
    List<Track>? tracks,
    LibraryStatus? status,
    String? errorMessage,
    List<String>? folders,
    String? query,
    SortField? sortField,
    SortOrder? sortOrder,
    LibraryFilter? filter,
  }) =>
      LibraryState(
        tracks: tracks ?? this.tracks,
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
        folders: folders ?? this.folders,
        query: query ?? this.query,
        sortField: sortField ?? this.sortField,
        sortOrder: sortOrder ?? this.sortOrder,
        filter: filter ?? this.filter,
      );

  List<Track> get filteredTracks {
    var result = tracks.toList();

    // Apply format filter
    switch (filter) {
      case LibraryFilter.lossless:
        result = result
            .where((t) => AudioFormat.fromExtension(t.format).isLossless)
            .toList();
        break;
      case LibraryFilter.hiRes:
        result = result
            .where((t) =>
                t.sampleRate >= 88200 ||
                (t.bitDepth != null && t.bitDepth! >= 24))
            .toList();
        break;
      case LibraryFilter.all:
        break;
    }

    // Apply search query
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      result = result.where((t) {
        return (t.title?.toLowerCase().contains(q) ?? false) ||
            (t.artist?.toLowerCase().contains(q) ?? false) ||
            (t.album?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // Apply sort
    result.sort((a, b) {
      int cmp;
      switch (sortField) {
        case SortField.title:
          cmp = (a.title ?? '').compareTo(b.title ?? '');
          break;
        case SortField.artist:
          final ac = (a.albumArtist ?? a.artist ?? '')
              .compareTo(b.albumArtist ?? b.artist ?? '');
          if (ac != 0) { cmp = ac; break; }
          final bc = (a.album ?? '').compareTo(b.album ?? '');
          if (bc != 0) { cmp = bc; break; }
          cmp = (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
          break;
        case SortField.album:
          final bc = (a.album ?? '').compareTo(b.album ?? '');
          if (bc != 0) { cmp = bc; break; }
          cmp = (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
          break;
        case SortField.duration:
          cmp = a.durationSecs.compareTo(b.durationSecs);
          break;
        case SortField.format:
          cmp = a.format.compareTo(b.format);
          break;
        case SortField.dateAdded:
          cmp = 0;
          break;
      }
      return sortOrder == SortOrder.ascending ? cmp : -cmp;
    });

    return result;
  }

  List<Track> get losslessTracks =>
      tracks.where((t) => AudioFormat.fromExtension(t.format).isLossless).toList();

  List<String> get allAlbums =>
      tracks.map((t) => t.album ?? '').where((a) => a.isNotEmpty).toSet().toList()..sort();

  List<String> get allArtists =>
      tracks.map((t) => t.displayArtist).toSet().toList()..sort();

  int get totalTracks => tracks.length;

  Duration get totalDuration =>
      tracks.fold(Duration.zero, (sum, t) => sum + t.duration);
}

const _kFoldersKey = 'aqloss_music_folders';

class LibraryNotifier extends StateNotifier<LibraryState> {
  LibraryNotifier() : super(const LibraryState()) {
    _restoreFolders();
  }

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
      state = state.copyWith(tracks: [], status: LibraryStatus.idle);
      return;
    }
    await _scanAll(updated);
  }

  Future<void> rescanAll() async {
    if (state.folders.isEmpty) return;
    state = state.copyWith(status: LibraryStatus.scanning);
    await _scanAll(state.folders);
  }

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
        } catch (_) {}
      }

      state = state.copyWith(tracks: tracks, status: LibraryStatus.done);
    } catch (e) {
      state = state.copyWith(
        status: LibraryStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void setQuery(String query) => state = state.copyWith(query: query);
  void setSortField(SortField f) => state = state.copyWith(sortField: f);
  void setSortOrder(SortOrder o) => state = state.copyWith(sortOrder: o);
  void toggleSortOrder() => state = state.copyWith(
      sortOrder: state.sortOrder == SortOrder.ascending
          ? SortOrder.descending
          : SortOrder.ascending);
  void setFilter(LibraryFilter f) => state = state.copyWith(filter: f);

  void clearAll() {
    _saveFolders([]);
    state = const LibraryState();
  }
}

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, LibraryState>(
  (ref) => LibraryNotifier(),
);
