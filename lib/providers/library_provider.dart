import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aqloss/models/audio_format.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/plugins/plugin_api.dart';
import 'package:aqloss/plugins/plugin_registry.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/src/rust/lib.dart' show TrackInfo;
import 'package:aqloss/util/library_filter.dart';
import 'package:aqloss/util/library_sort.dart';
import 'package:aqloss/util/missing_files.dart';

export 'package:aqloss/util/library_filter.dart'
    show BitDepthFilter, LibraryFilter;
export 'package:aqloss/util/library_sort.dart' show SortField, SortOrder;

enum LibraryStatus { idle, scanning, done, error }

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
  final Set<AudioFormat> selectedFormats;
  final String? formatFilter;
  final BitDepthFilter bitDepthFilter;
  final int missingRemoved;

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
    this.selectedFormats = const {},
    this.formatFilter,
    this.bitDepthFilter = BitDepthFilter.any,
    this.missingRemoved = 0,
  }) : _cachedFiltered = cachedFiltered;

  List<Track> get filteredTracks => _cachedFiltered;

  AudioFormat? get formatFilter =>
      selectedFormats.length == 1 ? selectedFormats.first : null;

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
    Set<AudioFormat>? selectedFormats,
    String? formatFilter,
    bool clearFormatFilter = false,
    BitDepthFilter? bitDepthFilter,
    int? missingRemoved,
  }) => LibraryState(
    tracks: tracks ?? this.tracks,
    cachedFiltered: cachedFiltered ?? _cachedFiltered,
    status: status ?? this.status,
    errorMessage: errorMessage ?? this.errorMessage,
    folders: folders ?? this.folders,
    query: query ?? this.query,
    sortField: sortField ?? this.sortField,
    sortOrder: sortOrder ?? this.sortOrder,
    filter: filter ?? this.filter,
    selectedFormats: selectedFormats ?? this.selectedFormats,
    formatFilter: clearFormatFilter
        ? null
        : (formatFilter ?? this.formatFilter),
    bitDepthFilter: bitDepthFilter ?? this.bitDepthFilter,
    missingRemoved: missingRemoved ?? this.missingRemoved,
  );

  List<Track> get losslessTracks => tracks
      .where((t) => AudioFormat.fromExtension(t.format).isLossless)
      .toList();

  /// Gets all distinct `AudioFormat`s available in the scanned library
  List<AudioFormat> get availableFormats =>
      tracks
          .map((t) => AudioFormat.fromExtension(t.format))
          .where((f) => f != AudioFormat.unknown)
          .toSet()
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<String> get allAlbums =>
      tracks
          .map((t) => t.album ?? '')
          .where((a) => a.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  List<String> get allArtists =>
      tracks.map((t) => t.displayArtist).toSet().toList()..sort();

  int get totalTracks => tracks.length;

  Duration get totalDuration =>
      tracks.fold(Duration.zero, (sum, t) => sum + t.duration);
}

// Filter
List<Track> _computeFiltered(_FilterParams p) {
  var result = p.tracks.where((t) {
    return trackMatchesLibraryFilters(
      track: t,
      quality: p.filter,
      format: p.formatFilter,
      bitDepth: p.bitDepthFilter,
    );
  }).toList();

  if (p.query.isNotEmpty) {
    final q = p.query.toLowerCase();
    result = result.where((t) {
      return (t.title?.toLowerCase().contains(q) ?? false) ||
          (t.artist?.toLowerCase().contains(q) ?? false) ||
          (t.album?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  result.sort((a, b) => compareLibraryTracks(a, b, p.sortField, p.sortOrder));

  return result;
}

class _FilterParams {
  final List<Track> tracks;
  final LibraryFilter filter;
  final Set<AudioFormat> selectedFormats;
  final String? formatFilter;
  final BitDepthFilter bitDepthFilter;
  final String query;
  final SortField sortField;
  final SortOrder sortOrder;

  const _FilterParams(
    this.tracks,
    this.filter,
    this.selectedFormats,
    this.formatFilter,
    this.bitDepthFilter,
    this.query,
    this.sortField,
    this.sortOrder,
  );
}

// Mtime snapshot
Map<String, int> _collectDirMtimes(List<String> roots) {
  final snapshot = <String, int>{};
  for (final root in roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    try {
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is Directory) {
          try {
            final ms = entity.statSync().modified.millisecondsSinceEpoch;
            snapshot[entity.path] = ms;
          } catch (_) {}
        }
      }
      // Root itself
      final ms = dir.statSync().modified.millisecondsSinceEpoch;
      snapshot[root] = ms;
    } catch (_) {}
  }
  return snapshot;
}

// Persistence helpers
const _kFoldersKey = 'aqloss_music_folders';
const _kCacheFile = 'aqloss_library_cache.v2.json';
const _kMtimeFile = 'aqloss_library_mtimes.json';
const _kMetaConcurrency = 8;

Future<File> _appFile(String name) async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/$name');
}

Future<List<Track>> _loadCache() async {
  try {
    final file = await _appFile(_kCacheFile);
    if (!await file.exists()) return [];
    final list = jsonDecode(await file.readAsString()) as List<dynamic>;
    return list
        .map((e) {
          try {
            return Track.fromJson(e as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<Track>()
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> _writeCache(List<Track> tracks) async {
  try {
    final file = await _appFile(_kCacheFile);
    await file.writeAsString(
      jsonEncode(tracks.map((t) => t.toJson()).toList()),
    );
  } catch (_) {}
}

Future<Map<String, int>> _loadMtimeSnapshot() async {
  try {
    final file = await _appFile(_kMtimeFile);
    if (!await file.exists()) return {};
    final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return raw.map((k, v) => MapEntry(k, (v as num).toInt()));
  } catch (_) {
    return {};
  }
}

Future<void> _writeMtimeSnapshot(Map<String, int> snapshot) async {
  try {
    final file = await _appFile(_kMtimeFile);
    await file.writeAsString(jsonEncode(snapshot));
  } catch (_) {}
}

Future<void> _deletePersistedState() async {
  for (final name in [_kCacheFile, _kMtimeFile]) {
    try {
      final file = await _appFile(name);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

// Notifier
class LibraryNotifier extends StateNotifier<LibraryState> {
  LibraryNotifier() : super(const LibraryState()) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_kFoldersKey) ?? [];
    if (saved.isEmpty) return;

    final cached = await _loadCache();
    final changed = await _foldersChanged(saved);

    var tracks = cached;
    var missingRemoved = 0;
    if (cached.isNotEmpty && !changed) {
      final kept = (await compute(existingPathsOnDisk, [
        for (final t in cached) t.path,
      ])).toSet();
      if (kept.length != cached.length) {
        tracks = [
          for (final t in cached)
            if (kept.contains(t.path)) t,
        ];
        missingRemoved = cached.length - tracks.length;
        await _writeCache(tracks);
      }
    }

    if (cached.isNotEmpty) {
      final filtered = await _rebuildFiltered(tracks, state);
      if (mounted) {
        state = state.copyWith(
          folders: saved,
          tracks: tracks,
          cachedFiltered: filtered,
          status: LibraryStatus.done,
          missingRemoved: missingRemoved,
        );
      }
    } else if (mounted) {
      state = state.copyWith(folders: saved, status: LibraryStatus.scanning);
    }

    if (!changed && cached.isNotEmpty) return;

    _scanAll(saved, background: cached.isNotEmpty);
  }

  Future<bool> _foldersChanged(List<String> folders) async {
    final stored = await _loadMtimeSnapshot();
    if (stored.isEmpty) return true;
    final current = await compute(_collectDirMtimes, folders);
    if (current.length != stored.length) return true;
    for (final entry in current.entries) {
      if (stored[entry.key] != entry.value) return true;
    }
    return false;
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
      await _deletePersistedState();
      state = state.copyWith(
        tracks: [],
        cachedFiltered: [],
        status: LibraryStatus.idle,
      );
      return;
    }
    await _scanAll(updated);
  }

  Future<void> rescanAll() async {
    if (state.folders.isEmpty) return;
    state = state.copyWith(status: LibraryStatus.scanning);
    await _scanAll(state.folders);
  }

  Future<void> _scanAll(List<String> folders, {bool background = false}) async {
    await PluginRegistry.instance.dispatchLibraryScan(
      const LibraryScanEvent(phase: LibraryScanPhase.started),
    );
    try {
      final results = await Future.wait(
        folders.map((f) => backend.scanDirectory(path: f)),
      );
      final seen = <String>{};
      final allPaths = results
          .expand((paths) => paths)
          .where((p) => seen.add(p))
          .toList();

      final tracks = await _readTracks(allPaths);

      final snapshot = await compute(_collectDirMtimes, folders);
      await Future.wait([_writeCache(tracks), _writeMtimeSnapshot(snapshot)]);

      final filtered = await _rebuildFiltered(tracks, state);
      if (mounted) {
        state = state.copyWith(
          tracks: tracks,
          cachedFiltered: filtered,
          status: LibraryStatus.done,
        );
      }
      await PluginRegistry.instance.dispatchLibraryScan(
        LibraryScanEvent(
          phase: LibraryScanPhase.complete,
          count: tracks.length,
        ),
      );
    } catch (e) {
      if (mounted && !background) {
        state = state.copyWith(
          status: LibraryStatus.error,
          errorMessage: e.toString(),
        );
      }
    }
  }

  Future<void> _applyFilter() async {
    final filtered = await _rebuildFiltered(state.tracks, state);
    if (mounted) state = state.copyWith(cachedFiltered: filtered);
  }

  static Future<List<Track>> _rebuildFiltered(
    List<Track> tracks,
    LibraryState s,
  ) {
    return compute(
      _computeFiltered,
      _FilterParams(
        tracks,
        s.filter,
        s.selectedFormats,
        s.formatFilter,
        s.bitDepthFilter,
        s.query,
        s.sortField,
        s.sortOrder,
      ),
    );
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
          : SortOrder.ascending,
    );
    _applyFilter();
  }

  void setFilter(LibraryFilter f) {
    state = state.copyWith(filter: f, selectedFormats: const {});
    _applyFilter();
  }

  void toggleFormatFilter(AudioFormat format) {
    final updatedFormats = Set<AudioFormat>.from(state.selectedFormats);
    if (updatedFormats.contains(format)) {
      updatedFormats.remove(format);
    } else {
      updatedFormats.add(format);
    }

    if (updatedFormats.isEmpty) {
      state = state.copyWith(
        filter: LibraryFilter.all,
        selectedFormats: const {},
      );
    } else {
      state = state.copyWith(
        filter: LibraryFilter.format,
        selectedFormats: updatedFormats,
      );
    }
    _applyFilter();
  }

  void clearFormatFilters() {
    state = state.copyWith(
      filter: LibraryFilter.all,
      selectedFormats: const {},
    );
    _applyFilter();
  }

  void setFormatFilter(AudioFormat? format) {
    if (format == null) {
      clearFormatFilters();
    } else {
      state = state.copyWith(
        filter: LibraryFilter.format,
        selectedFormats: {format},
      );
      _applyFilter();
    }
  }

  void setFormatFilter(String format) {
    final next = state.formatFilter == format ? null : format;
    state = state.copyWith(formatFilter: next, clearFormatFilter: next == null);
    _applyFilter();
  }

  void setBitDepthFilter(BitDepthFilter f) {
    final next = state.bitDepthFilter == f ? BitDepthFilter.any : f;
    state = state.copyWith(bitDepthFilter: next);
    _applyFilter();
  }

  void setFormatFilter(AudioFormat? format) {
    if (format == null) {
      clearFormatFilters();
    } else {
      state = state.copyWith(
        filter: LibraryFilter.format,
        selectedFormats: {format},
      );
      _applyFilter();
    }
  }

  void setFormatFilter(String format) {
    final next = state.formatFilter == format ? null : format;
    state = state.copyWith(formatFilter: next, clearFormatFilter: next == null);
    _applyFilter();
  }

  void setBitDepthFilter(BitDepthFilter f) {
    final next = state.bitDepthFilter == f ? BitDepthFilter.any : f;
    state = state.copyWith(bitDepthFilter: next);
    _applyFilter();
  }

  void clearAll() {
    _saveFolders([]);
    _deletePersistedState();
    state = const LibraryState();
  }

  Future<void> restoreFolders(List<String> folders) async {
    final updated = [
      for (final f in folders)
        if (f.trim().isNotEmpty) f.trim(),
    ];
    await _saveFolders(updated);
    if (updated.isEmpty) {
      await _deletePersistedState();
      if (mounted) state = const LibraryState();
      return;
    }
    if (mounted) {
      state = state.copyWith(
        folders: updated,
        status: LibraryStatus.scanning,
        missingRemoved: 0,
      );
    }
    await _scanAll(updated);
  }
}

Track _trackFromInfo(TrackInfo info) => Track(
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
  replayGainTrack: info.replayGainTrack,
  replayGainAlbum: info.replayGainAlbum,
);

Future<List<Track>> _readTracks(List<String> paths) async {
  final tracks = <Track>[];
  for (var i = 0; i < paths.length; i += _kMetaConcurrency) {
    final end = i + _kMetaConcurrency > paths.length
        ? paths.length
        : i + _kMetaConcurrency;
    final chunk = await Future.wait(
      paths.sublist(i, end).map((path) async {
        try {
          return _trackFromInfo(await backend.readMetadata(path: path));
        } catch (_) {
          return null;
        }
      }),
    );
    tracks.addAll(chunk.whereType<Track>());
  }
  return tracks;
}

final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>(
  (ref) => LibraryNotifier(),
);