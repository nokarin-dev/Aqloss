import 'package:flutter/foundation.dart';
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
  final List<Track> _cachedFiltered;
  final LibraryStatus status;
  final String? errorMessage;
  final List<String> folders;
  final String query;
  final SortField sortField;
  final SortOrder sortOrder;
  final LibraryFilter filter;

  const LibraryState({
    this.tracks = const [],
    List<Track> cachedFiltered = const [],
    this.status = LibraryStatus.idle,
    this.errorMessage,
    this.folders = const [],
    this.query = '',
    this.sortField = SortField.artist,
    this.sortOrder = SortOrder.ascending,
    this.filter = LibraryFilter.all,
  }) : _cachedFiltered = cachedFiltered;

  List<Track> get filteredTracks => _cachedFiltered;

  LibraryState copyWith({
    List<Track>? tracks,
    List<Track>? cachedFiltered,
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
        cachedFiltered: cachedFiltered ?? _cachedFiltered,
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
        folders: folders ?? this.folders,
        query: query ?? this.query,
        sortField: sortField ?? this.sortField,
        sortOrder: sortOrder ?? this.sortOrder,
        filter: filter ?? this.filter,
      );

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

List<Track> _computeFiltered(_FilterParams p) {
  var result = p.tracks.toList();

  switch (p.filter) {
    case LibraryFilter.lossless:
      result = result
          .where((t) => AudioFormat.fromExtension(t.format).isLossless)
          .toList();
      break;
    case LibraryFilter.hiRes:
      result = result
          .where((t) =>
              t.sampleRate >= 88200 || (t.bitDepth != null && t.bitDepth! >= 24))
          .toList();
      break;
    case LibraryFilter.all:
      break;
  }

  if (p.query.isNotEmpty) {
    final q = p.query.toLowerCase();
    result = result.where((t) {
      return (t.title?.toLowerCase().contains(q) ?? false) ||
          (t.artist?.toLowerCase().contains(q) ?? false) ||
          (t.album?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  result.sort((a, b) {
    int cmp;
    switch (p.sortField) {
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
    return p.sortOrder == SortOrder.ascending ? cmp : -cmp;
  });

  return result;
}

class _FilterParams {
  final List<Track> tracks;
  final LibraryFilter filter;
  final String query;
  final SortField sortField;
  final SortOrder sortOrder;
  const _FilterParams(this.tracks, this.filter, this.query, this.sortField, this.sortOrder);
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
      state = state.copyWith(tracks: [], cachedFiltered: [], status: LibraryStatus.idle);
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

      final filtered = await _rebuildFiltered(tracks, state);
      state = state.copyWith(tracks: tracks, cachedFiltered: filtered, status: LibraryStatus.done);
    } catch (e) {
      state = state.copyWith(status: LibraryStatus.error, errorMessage: e.toString());
    }
  }

  // Re-run filter+sort off the main thread, then update the cache.
  Future<void> _applyFilter() async {
    final filtered = await _rebuildFiltered(state.tracks, state);
    if (mounted) state = state.copyWith(cachedFiltered: filtered);
  }

  static Future<List<Track>> _rebuildFiltered(List<Track> tracks, LibraryState s) {
    final params = _FilterParams(tracks, s.filter, s.query, s.sortField, s.sortOrder);
    return compute(_computeFiltered, params);
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
    _applyFilter();
  }

  void setSortField(SortField f) {
    state = state.copyWith(sortField: f);
    _applyFilter();
  }

  void setSortOrder(SortOrder o) {
    state = state.copyWith(sortOrder: o);
    _applyFilter();
  }

  void toggleSortOrder() {
    state = state.copyWith(
        sortOrder: state.sortOrder == SortOrder.ascending
            ? SortOrder.descending
            : SortOrder.ascending);
    _applyFilter();
  }

  void setFilter(LibraryFilter f) {
    state = state.copyWith(filter: f);
    _applyFilter();
  }

  void clearAll() {
    _saveFolders([]);
    state = const LibraryState();
  }
}

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, LibraryState>(
  (ref) => LibraryNotifier(),
);
