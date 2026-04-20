import 'dart:io';
import 'package:flutter_riverpod/legacy.dart';
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

enum LyricsSource { none, embedded, lrcFile, txtFile }

// Notifier
class LyricsNotifier extends StateNotifier<LyricsState> {
  LyricsNotifier() : super(const LyricsState());

  Future<void> loadForTrack(String trackPath) async {
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

      state = LyricsState(trackPath: trackPath);
    } catch (_) {
      state = LyricsState(trackPath: trackPath);
    }
  }

  void clear() {
    state = const LyricsState();
  }
}

final lyricsProvider = StateNotifierProvider<LyricsNotifier, LyricsState>(
      (ref) {
    final notifier = LyricsNotifier();
    ref.listen<PlayerState>(playerProvider, (prev, next) {
      final path = next.currentTrack?.path;
      if (path != null && path != prev?.currentTrack?.path) {
        notifier.loadForTrack(path);
      } else if (path == null) {
        notifier.clear();
      }
    });
    return notifier;
  },
);