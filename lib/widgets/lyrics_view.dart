import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/lyrics_provider.dart';
import 'package:aqloss/providers/player_provider.dart';

class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({super.key});

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final _scrollController = ScrollController();
  int _lastIndex = -1;
  bool _userScrolling = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index, int total) {
    if (_userScrolling) return;
    if (!_scrollController.hasClients) return;
    const lineH = 52.0;
    final offset = (index * lineH) - 100.0;
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = ref.watch(lyricsProvider);
    final player = ref.watch(playerProvider);

    if (lyrics.isLoading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white24),
        ),
      );
    }

    if (!lyrics.hasLyrics) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lyrics_outlined, size: 32, color: Colors.white12),
            const SizedBox(height: 12),
            const Text(
              'No lyrics found',
              style: TextStyle(fontSize: 13, color: Colors.white24),
            ),
            const SizedBox(height: 6),
            Text(
              'Add a .lrc file next to your audio file',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.12)),
            ),
          ],
        ),
      );
    }

    // Synced LRC
    if (lyrics.hasSynced) {
      final doc = lyrics.document!;
      final currentIdx = doc.currentIndex(player.position);

      if (currentIdx != _lastIndex) {
        _lastIndex = currentIdx;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToIndex(currentIdx, doc.lines.length);
        });
      }

      return NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollStartNotification && n.dragDetails != null) {
            _userScrolling = true;
          } else if (n is ScrollEndNotification) {
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) _userScrolling = false;
            });
          }
          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
          itemCount: doc.lines.length,
          itemBuilder: (_, i) {
            final isCurrent = i == currentIdx;
            final isPast = i < currentIdx;
            return _LyricLine(
              text: doc.lines[i].text,
              isCurrent: isCurrent,
              isPast: isPast,
            );
          },
        ),
      );
    }

    // Plain text fallback
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Text(
        lyrics.rawText!,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.white54,
          height: 1.8,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _LyricLine extends StatelessWidget {
  final String text;
  final bool isCurrent;
  final bool isPast;

  const _LyricLine({
    required this.text,
    required this.isCurrent,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: isCurrent
          ? BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      )
          : null,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 300),
        style: TextStyle(
          fontSize: isCurrent ? 16 : 13.5,
          fontWeight: isCurrent ? FontWeight.w500 : FontWeight.w300,
          color: isCurrent
              ? Colors.white
              : isPast
              ? Colors.white30
              : Colors.white24,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}