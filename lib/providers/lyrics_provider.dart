import 'dart:convert';
import 'dart:io';
import 'package:aqloss/util/logger.dart';
import 'package:aqloss/util/lyrics_match.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

class LrcLine {
  final Duration timestamp;
  final String text;
  const LrcLine(this.timestamp, this.text);
}

class LrcDocument {
  final List<LrcLine> lines;
  const LrcDocument(this.lines);

  int currentIndex(Duration position) {
    if (lines.isEmpty) return -1;
    int idx = 0;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].timestamp <= position) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  static LrcDocument? parse(String content) {
    final lines = <LrcLine>[];
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final tagRe = RegExp(r'\[(\d+):(\d+)[.:](\d+)\](.*)');
      final m = tagRe.firstMatch(line);
      if (m == null) continue;
      final minutes = int.parse(m.group(1)!);
      final seconds = int.parse(m.group(2)!);
      final centis = int.parse(m.group(3)!.padRight(2, '0').substring(0, 2));
      final text = m.group(4)!.trim();
      if (text.isEmpty) continue;
      final ts = Duration(
        minutes: minutes,
        seconds: seconds,
        milliseconds: centis * 10,
      );
      lines.add(LrcLine(ts, text));
    }
    if (lines.isEmpty) return null;
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return LrcDocument(lines);
  }

  static bool looksLikeLrc(String content) {
    return RegExp(r'\[\d+:\d+[.:]\d+\]').hasMatch(content);
  }
}

class LyricsState {
  final LrcDocument? document;
  final String? rawText;
  final bool isLoading;
  final String? trackPath;
  final LyricsSource source;

  const LyricsState({
    this.document,
    this.rawText,
    this.isLoading = false,
    this.trackPath,
    this.source = LyricsSource.none,
  });

  bool get hasLyrics => document != null || rawText != null;
  bool get hasSynced => document != null;
}

// Lines around the playhead. The start of a loop is the first lines.
({int start, int end}) lyricLineWindow(int current, int length) {
  if (length <= 0) return (start: 0, end: 0);
  var index = current;
  if (index < 0) index = 0;
  if (index >= length) index = length - 1;
  final start = (index - 2).clamp(0, length - 1).toInt();
  final end = (index + 3).clamp(start + 1, length).toInt();
  return (start: start, end: end);
}

// Keep lyrics on screen when the same song restarts.
LyricsState pickShownLyrics(LyricsState shown, LyricsState live, String? path) {
  if (path != null && live.trackPath == path && live.hasLyrics) return live;
  if (shown.hasLyrics && (path == null || shown.trackPath == path)) {
    return shown;
  }
  if (path != null && live.trackPath == path && live.isLoading) return live;
  return const LyricsState();
}

enum LyricsSource { none, embedded, lrcFile, txtFile, lrclib }

List<String> _artistCandidates(String raw) {
  final candidates = <String>{};

  if (raw.contains(';')) {
    final first = raw.split(';').first.trim();
    candidates.add(_cleanSingleArtist(first));
    candidates.add('Various Artists');
    candidates.add('');
    return candidates.where((s) => s.isNotEmpty).toList();
  }

  candidates.add(_cleanSingleArtist(raw));

  final noFeat = _removeFeat(raw);
  if (noFeat != raw) candidates.add(_cleanSingleArtist(noFeat));

  candidates.add('');

  return candidates
      .where((s) => s.isNotEmpty || candidates.length == 1)
      .toList();
}

String _cleanSingleArtist(String s) {
  var out = s;
  out = out.replaceAll(RegExp(r'\(CV[.:][^)]*\)', caseSensitive: false), '');
  out = out.replaceAll(RegExp(r'\(voice[^)]*\)', caseSensitive: false), '');
  out = _removeFeat(out);
  out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
  out = out.replaceAll(RegExp(r'[,;/&|]+$'), '').trim();
  return out;
}

String _removeFeat(String s) {
  return s
      .replaceAll(
        RegExp(r'\s+(feat\.|ft\.|with|×|x)\s.*', caseSensitive: false),
        '',
      )
      .trim();
}

List<String> _titleCandidates(String raw) {
  final candidates = [raw];
  final stripped = raw
      .replaceAll(
        RegExp(
          r'\s*[\[(](?:TV\s*Size|Short\s*Ver\.?|Instrumental|Karaoke|Remix)[)\]].*$',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
  if (stripped != raw && stripped.isNotEmpty) candidates.add(stripped);
  return candidates;
}

class _LrclibResult {
  final LrcDocument? document;
  final String? rawText;
  const _LrclibResult({this.document, this.rawText});
}

Future<_LrclibResult?> _getExact({
  required String artist,
  required String title,
  int? duration,
}) async {
  final params = <String, String>{
    'track_name': title,
    if (artist.isNotEmpty) 'artist_name': artist,
    if (duration != null) 'duration': duration.toString(),
  };
  final uri = Uri.https('lrclib.net', '/api/get', params);
  Logger.infoFrontend('lrclib get: $uri');
  try {
    final res = await http
        .get(
          uri,
          headers: {
            'User-Agent': 'aqloss/1.0 (https://nokarin.xyz/projects/aqloss)',
          },
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    return _parseLrclibJson(res.body);
  } catch (_) {
    return null;
  }
}

Future<_LrclibResult?> _searchFuzzy({
  required String artist,
  required String title,
  int? duration,
}) async {
  final params = <String, String>{
    'q': artist.isNotEmpty ? '$artist $title' : title,
  };
  final uri = Uri.https('lrclib.net', '/api/search', params);
  Logger.infoFrontend('lrclib search: $uri');
  try {
    final res = await http
        .get(
          uri,
          headers: {
            'User-Agent': 'aqloss/1.0 (https://nokarin.xyz/projects/aqloss)',
          },
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final list = jsonDecode(res.body) as List<dynamic>;
    if (list.isEmpty) return null;

    final rows = [for (final item in list) item as Map<String, dynamic>];
    final index = pickLyricsHit(
      [
        for (final obj in rows)
          LyricsSearchHit(
            artist: (obj['artistName'] as String? ?? '').trim(),
            title: (obj['trackName'] as String? ?? '').trim(),
            duration: (obj['duration'] as num?)?.round(),
          ),
      ],
      artist: artist,
      title: title,
      duration: duration,
    );
    if (index == null) return null;
    final picked = rows[index];
    Logger.infoFrontend(
      '"$title" hit artist="${picked['artistName'] ?? ''}" title="${picked['trackName'] ?? ''}"',
    );
    return _parseLrclibMap(picked);
  } catch (_) {
    return null;
  }
}

_LrclibResult? _parseLrclibJson(String body) {
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return _parseLrclibMap(json);
  } catch (_) {
    return null;
  }
}

_LrclibResult? _parseLrclibMap(Map<String, dynamic> json) {
  final synced = json['syncedLyrics'] as String?;
  if (synced != null && synced.trim().isNotEmpty) {
    final doc = LrcDocument.parse(synced);
    if (doc != null) return _LrclibResult(document: doc);
  }
  final plain = json['plainLyrics'] as String?;
  if (plain != null && plain.trim().isNotEmpty) {
    return _LrclibResult(rawText: plain.trim());
  }
  return null;
}

Future<_LrclibResult?> _fetchFromLrclib({
  required String artist,
  required String title,
  int? duration,
}) async {
  final artists = _artistCandidates(artist);
  final titles = _titleCandidates(title);

  for (final t in titles) {
    for (final a in artists) {
      final result = await _getExact(artist: a, title: t, duration: duration);
      if (result != null) {
        Logger.infoFrontend('"$title" ok=true (artist="$a", title="$t")');
        return result;
      }
    }
  }

  // fuzzy /api/search stays on the tagged artist
  final named = artists.where((a) => a.isNotEmpty).toList();
  for (final t in titles) {
    for (final a in named.isEmpty ? [''] : named) {
      final result = await _searchFuzzy(
        artist: a,
        title: t,
        duration: duration,
      );
      if (result != null) {
        Logger.infoFrontend(
          '"$title" ok=true via search (artist="$a", title="$t")',
        );
        return result;
      }
    }
  }

  Logger.infoFrontend('"$title" ok=false');
  return null;
}

class LyricsNotifier extends StateNotifier<LyricsState> {
  LyricsNotifier() : super(const LyricsState());

  final Map<String, LyricsState> _saved = {};
  int _ticket = 0;

  // Saved lyrics count only while that copy is on screen.
  bool covers(String path) {
    if (_saved.containsKey(path)) {
      return state.trackPath == path && state.hasLyrics;
    }
    return state.trackPath == path;
  }

  Future<void> loadForTrack(
    String trackPath, {
    String? artist,
    String? title,
    int? duration,
  }) async {
    final saved = _saved[trackPath];
    if (saved != null) {
      _ticket++;
      if (state.trackPath != trackPath || !state.hasLyrics) state = saved;
      return;
    }
    // Same track already showing lyrics. A loop must not wipe them.
    if (state.trackPath == trackPath && (state.hasLyrics || state.isLoading)) {
      return;
    }
    final ticket = ++_ticket;
    state = LyricsState(isLoading: true, trackPath: trackPath);

    try {
      final next = await _fetchLyrics(
        trackPath,
        artist: artist,
        title: title,
        duration: duration,
      );
      if (ticket != _ticket) return;
      if (next == null) {
        if (state.trackPath == trackPath && state.hasLyrics) return;
        state = LyricsState(trackPath: trackPath);
        return;
      }
      _saved[trackPath] = next;
      state = next;
    } catch (_) {
      if (ticket != _ticket) return;
      final kept = _saved[trackPath];
      if (kept != null) {
        state = kept;
        return;
      }
      if (state.trackPath == trackPath && state.hasLyrics) return;
      state = LyricsState(trackPath: trackPath);
    }
  }

  void clear() => state = const LyricsState();
}

Future<LyricsState?> _fetchLyrics(
  String trackPath, {
  String? artist,
  String? title,
  int? duration,
}) async {
  final embedded = await backend.readEmbeddedLyrics(path: trackPath);
  if (embedded != null && embedded.trim().isNotEmpty) {
    if (LrcDocument.looksLikeLrc(embedded)) {
      final doc = LrcDocument.parse(embedded);
      if (doc != null) {
        return LyricsState(
          document: doc,
          trackPath: trackPath,
          source: LyricsSource.embedded,
        );
      }
    }
    return LyricsState(
      rawText: embedded.trim(),
      trackPath: trackPath,
      source: LyricsSource.embedded,
    );
  }

  final base = trackPath.replaceAll(RegExp(r'\.[^.]+$'), '');
  final lrcFile = File('$base.lrc');
  if (await lrcFile.exists()) {
    final content = await lrcFile.readAsString();
    final doc = LrcDocument.parse(content);
    if (doc != null) {
      return LyricsState(
        document: doc,
        trackPath: trackPath,
        source: LyricsSource.lrcFile,
      );
    }
    final plain = content
        .split('\n')
        .where((l) => !l.startsWith('[') && l.trim().isNotEmpty)
        .join('\n');
    if (plain.isNotEmpty) {
      return LyricsState(
        rawText: plain,
        trackPath: trackPath,
        source: LyricsSource.lrcFile,
      );
    }
  }

  final txtFile = File('$base.txt');
  if (await txtFile.exists()) {
    final content = await txtFile.readAsString();
    if (content.trim().isNotEmpty) {
      return LyricsState(
        rawText: content.trim(),
        trackPath: trackPath,
        source: LyricsSource.txtFile,
      );
    }
  }

  if (artist != null && title != null) {
    final result = await _fetchFromLrclib(
      artist: artist,
      title: title,
      duration: duration,
    );
    if (result != null) {
      return LyricsState(
        document: result.document,
        rawText: result.rawText,
        trackPath: trackPath,
        source: LyricsSource.lrclib,
      );
    }
  }
  return null;
}

final lyricsProvider = StateNotifierProvider<LyricsNotifier, LyricsState>((
  ref,
) {
  final notifier = LyricsNotifier();
  // The song already playing counts, including the one restored at launch.
  ref.listen<PlayerState>(playerProvider, (prev, next) {
    final path = next.currentTrack?.path;
    if (path == null) {
      if (next.status != PlayerStatus.loading) notifier.clear();
      return;
    }
    final changed = path != prev?.currentTrack?.path;
    if (changed || !notifier.covers(path)) {
      notifier.loadForTrack(
        path,
        artist: next.currentTrack?.artist,
        title: next.currentTrack?.title,
        duration: next.currentTrack?.duration.inSeconds,
      );
    }
  }, fireImmediately: true);
  return notifier;
});
