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

      // Plain .txt file
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

      // lrclib fallback
      if (artist != null && title != null) {
        final lrclibResult = await _fetchFromLrclib(
          artist: artist,
          title: title,
          duration: duration,
        );
        if (lrclibResult != null) {
          state = LyricsState(
            document: lrclibResult.document,
            rawText: lrclibResult.rawText,
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

  void clear() {
    state = const LyricsState();
  }
}

// lrclib result container
class _LrclibResult {
  final LrcDocument? document;
  final String? rawText;
  const _LrclibResult({this.document, this.rawText});
}

Future<_LrclibResult?> _fetchFromLrclib({
  required String artist,
  required String title,
  int? duration,
}) async {
  try {
    final uri = Uri.https('lrclib.net', '/api/get', {
      'artist_name': artist,
      'track_name': title,
      if (duration != null) 'duration': duration.toString(),
    });
    Logger.infoFrontend("Searching for $title lyrics: $uri");

    final res = await http
        .get(
          uri,
          headers: {
            'User-Agent': 'aqloss/1.0 (https://nokarin.xyz/projects/aqloss)',
          },
        )
        .timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) return null;

    final json = jsonDecode(res.body) as Map<String, dynamic>;

    // Prefer synced LRC over plain text
    final syncedLyrics = json['syncedLyrics'] as String?;
    if (syncedLyrics != null && syncedLyrics.trim().isNotEmpty) {
      final doc = LrcDocument.parse(syncedLyrics);
      if (doc != null) return _LrclibResult(document: doc);
    }

    final plainLyrics = json['plainLyrics'] as String?;
    if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
      return _LrclibResult(rawText: plainLyrics.trim());
    }
  } catch (_) {}
  return null;
}

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
