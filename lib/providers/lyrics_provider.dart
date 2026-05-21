import 'dart:convert';
import 'dart:io';
import 'package:aqloss/util/logger.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

// LRC parser
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

// State
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

enum LyricsSource { none, embedded, lrcFile, txtFile, lrclib }

// Artist / title normalisation
List<String> _artistCandidates(String raw) {
  final candidates = <String>{};

  if (raw.contains(';')) {
    final first = raw.split(';').first.trim();
    candidates.add(_cleanSingleArtist(first));
    candidates.add('Various Artists');
    candidates.add('');
    return candidates.where((s) => s.isNotEmpty).toList();
  }

  // Normal single-artist cleanup
  candidates.add(_cleanSingleArtist(raw));

  // Remove "feat." component
  final noFeat = _removeFeat(raw);
  if (noFeat != raw) candidates.add(_cleanSingleArtist(noFeat));

  // Empty string
  candidates.add('');

  return candidates
      .where((s) => s.isNotEmpty || candidates.length == 1)
      .toList();
}

String _cleanSingleArtist(String s) {
  var out = s;
  // Remove (CV. ...) or (CV: ...) blocks
  out = out.replaceAll(RegExp(r'\(CV[.:][^)]*\)', caseSensitive: false), '');
  // Remove (voice: ...) blocks
  out = out.replaceAll(RegExp(r'\(voice[^)]*\)', caseSensitive: false), '');
  // Remove feat./ft./with/x collaborators
  out = _removeFeat(out);
  // Collapse whitespace
  out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
  // Remove trailing punctuation
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

// Normalise track title
List<String> _titleCandidates(String raw) {
  final candidates = [raw];
  // Strip common suffixes
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

// lrclib helpers
class _LrclibResult {
  final LrcDocument? document;
  final String? rawText;
  const _LrclibResult({this.document, this.rawText});
}

// /api/get endpoint
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

// /api/search endpoint
Future<_LrclibResult?> _searchFuzzy({
  required String artist,
  required String title,
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

    // Pick the first result whose track name matches closely
    final titleNorm = _norm(title);
    for (final item in list) {
      final obj = item as Map<String, dynamic>;
      final trackName = (obj['trackName'] as String? ?? '').trim();
      if (_norm(trackName) == titleNorm ||
          _norm(trackName).contains(titleNorm)) {
        return _parseLrclibMap(obj);
      }
    }
    // Accept first result as last resort
    return _parseLrclibMap(list.first as Map<String, dynamic>);
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

// Normalise string for fuzzy comparison
String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"[^\w\s]"), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

// Main entry point
Future<_LrclibResult?> _fetchFromLrclib({
  required String artist,
  required String title,
  int? duration,
}) async {
  final artists = _artistCandidates(artist);
  final titles = _titleCandidates(title);

  // strict /api/get
  for (final t in titles) {
    for (final a in artists) {
      final result = await _getExact(artist: a, title: t, duration: duration);
      if (result != null) {
        Logger.infoFrontend('"$title" ok=true (artist="$a", title="$t")');
        return result;
      }
    }
  }

  // fuzzy /api/search
  for (final t in titles) {
    for (final a in [artists.first, '']) {
      final result = await _searchFuzzy(artist: a, title: t);
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

// Notifier
class LyricsNotifier extends StateNotifier<LyricsState> {
  LyricsNotifier() : super(const LyricsState());

  Future<void> loadForTrack(
    String trackPath, {
    String? artist,
    String? title,
    int? duration,
  }) async {
    if (state.trackPath == trackPath) return;
    state = LyricsState(isLoading: true, trackPath: trackPath);

    try {
      // Embedded lyrics
      final embedded = await backend.readEmbeddedLyrics(path: trackPath);
      if (embedded != null && embedded.trim().isNotEmpty) {
        if (LrcDocument.looksLikeLrc(embedded)) {
          final doc = LrcDocument.parse(embedded);
          if (doc != null) {
            state = LyricsState(
              document: doc,
              trackPath: trackPath,
              source: LyricsSource.embedded,
            );
            return;
          }
        }
        state = LyricsState(
          rawText: embedded.trim(),
          trackPath: trackPath,
          source: LyricsSource.embedded,
        );
        return;
      }

      // Sidecar .lrc file
      final base = trackPath.replaceAll(RegExp(r'\.[^.]+$'), '');
      final lrcFile = File('$base.lrc');
      if (await lrcFile.exists()) {
        final content = await lrcFile.readAsString();
        final doc = LrcDocument.parse(content);
        if (doc != null) {
          state = LyricsState(
            document: doc,
            trackPath: trackPath,
            source: LyricsSource.lrcFile,
          );
          return;
        }
        final plain = content
            .split('\n')
            .where((l) => !l.startsWith('[') && l.trim().isNotEmpty)
            .join('\n');
        if (plain.isNotEmpty) {
          state = LyricsState(
            rawText: plain,
            trackPath: trackPath,
            source: LyricsSource.lrcFile,
          );
          return;
        }
      }

      // Sidecar .txt file
      final txtFile = File('$base.txt');
      if (await txtFile.exists()) {
        final content = await txtFile.readAsString();
        if (content.trim().isNotEmpty) {
          state = LyricsState(
            rawText: content.trim(),
            trackPath: trackPath,
            source: LyricsSource.txtFile,
          );
          return;
        }
      }

      // lrclib
      if (artist != null && title != null) {
        final result = await _fetchFromLrclib(
          artist: artist,
          title: title,
          duration: duration,
        );
        if (result != null) {
          state = LyricsState(
            document: result.document,
            rawText: result.rawText,
            trackPath: trackPath,
            source: LyricsSource.lrclib,
          );
          return;
        }
      }

      state = LyricsState(trackPath: trackPath);
    } catch (_) {
      state = LyricsState(trackPath: trackPath);
    }
  }

  void clear() => state = const LyricsState();
}

// Provider
final lyricsProvider = StateNotifierProvider<LyricsNotifier, LyricsState>((
  ref,
) {
  final notifier = LyricsNotifier();
  ref.listen<PlayerState>(playerProvider, (prev, next) {
    final path = next.currentTrack?.path;
    if (path != null && path != prev?.currentTrack?.path) {
      notifier.loadForTrack(
        path,
        artist: next.currentTrack?.artist,
        title: next.currentTrack?.title,
        duration: next.currentTrack?.duration.inSeconds,
      );
    } else if (path == null) {
      notifier.clear();
    }
  });
  return notifier;
});
