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
  final _itemHeights = <int, double>{};
  final _listKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (_userScrolling) return;
    if (!_scrollController.hasClients) return;

    double offset = 40.0;
    for (int i = 0; i < index; i++) {
      offset += _itemHeights[i] ?? 52.0;
    }

    final viewportHeight = _scrollController.position.viewportDimension;
    final target = (offset - viewportHeight * 0.28).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = ref.watch(lyricsProvider);
    final player = ref.watch(playerProvider);
    final cs = Theme.of(context).colorScheme;

    if (lyrics.isLoading) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: cs.onSurface.withValues(alpha: 0.20),
          ),
        ),
      );
    }

    if (!lyrics.hasLyrics) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: 32,
              color: cs.onSurface.withValues(alpha: 0.10),
            ),
            const SizedBox(height: 12),
            Text(
              'No lyrics found',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.24),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Embed lyrics in the audio file tags,\nor add a .lrc file next to it',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.14),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final sourceBadge = _SourceBadge(source: lyrics.source);

    // Synced LRC
    if (lyrics.hasSynced) {
      final doc = lyrics.document!;
      final currentIdx = doc.currentIndex(player.position);

      if (currentIdx != _lastIndex && currentIdx >= 0) {
        _lastIndex = currentIdx;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToIndex(currentIdx);
        });
      }

      return Column(
        children: [
          sourceBadge,
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollStartNotification && n.dragDetails != null) {
                  _userScrolling = true;
                } else if (n is ScrollEndNotification) {
                  Future.delayed(const Duration(seconds: 4), () {
                    if (mounted) _userScrolling = false;
                  });
                }
                return false;
              },
              child: ListView.builder(
                key: _listKey,
                controller: _scrollController,
                padding: const EdgeInsets.only(
                  top: 40,
                  bottom: 120,
                  left: 16,
                  right: 16,
                ),
                itemCount: doc.lines.length,
                itemBuilder: (_, i) {
                  final isCurrent = i == currentIdx;
                  final isPast = i < currentIdx;
                  return _MeasuredLyricLine(
                    key: ValueKey('lyric_$i'),
                    text: doc.lines[i].text,
                    isCurrent: isCurrent,
                    isPast: isPast,
                    onHeight: (h) => _itemHeights[i] = h,
                  );
                },
              ),
            ),
          ),
        ],
      );
    }

    // Plain text fallback
    return Column(
      children: [
        sourceBadge,
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Text(
              lyrics.rawText!,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.50),
                height: 1.8,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

class _MeasuredLyricLine extends StatefulWidget {
  final String text;
  final bool isCurrent;
  final bool isPast;
  final void Function(double) onHeight;

  const _MeasuredLyricLine({
    super.key,
    required this.text,
    required this.isCurrent,
    required this.isPast,
    required this.onHeight,
  });

  @override
  State<_MeasuredLyricLine> createState() => _MeasuredLyricLineState();
}

class _MeasuredLyricLineState extends State<_MeasuredLyricLine> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportHeight());
  }

  @override
  void didUpdateWidget(_MeasuredLyricLine old) {
    super.didUpdateWidget(old);
    _reportHeight();
  }

  void _reportHeight() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) widget.onHeight(box.size.height);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.isCurrent
        ? cs.onSurface
        : widget.isPast
        ? cs.onSurface.withValues(alpha: 0.28)
        : cs.onSurface.withValues(alpha: 0.22);
    final highlight = cs.onSurface.withValues(alpha: 0.05);

    return AnimatedContainer(
      key: _key,
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: widget.isCurrent
          ? BoxDecoration(
              color: highlight,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 300),
        style: TextStyle(
          fontSize: widget.isCurrent ? 16 : 13.5,
          fontWeight: widget.isCurrent ? FontWeight.w500 : FontWeight.w300,
          color: color,
          height: 1.45,
        ),
        textAlign: TextAlign.center,
        child: Text(widget.text, textAlign: TextAlign.center),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final LyricsSource source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    if (source == LyricsSource.none) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final (icon, label) = switch (source) {
      LyricsSource.embedded => (Icons.music_note, 'Embedded'),
      LyricsSource.lrcFile => (Icons.text_snippet_outlined, '.lrc file'),
      LyricsSource.txtFile => (Icons.text_fields, '.txt file'),
      LyricsSource.lrclib => (Icons.cloud_outlined, 'lrclib'),
      LyricsSource.none => (Icons.close, ''),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 11, color: cs.onSurface.withValues(alpha: 0.22)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: cs.onSurface.withValues(alpha: 0.22),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
