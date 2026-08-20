import 'dart:io';
import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/models/audio_format.dart';
import 'package:aqloss/providers/history_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/providers/accent_provider.dart';
import 'package:aqloss/widgets/shared/mini_album_art.dart';

class TrackTile extends ConsumerWidget {
  final Track track;
  final int? index;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final void Function(TapDownDetails)? onSecondaryTapDown;

  const TrackTile({
    super.key,
    required this.track,
    this.index,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onSecondaryTapDown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final isPlaying = player.currentTrack?.path == track.path;
    final format = AudioFormat.fromExtension(track.format);
    final showBitDepth = ref.watch(settingsProvider).showBitDepthInLibrary;
    final aq = context.aq;
    final cs = Theme.of(context).colorScheme;
    final feedbackBg = context.isMaterial3Ui ? cs.surface : aq.card;
    final feedbackBorder = context.isMaterial3Ui
        ? cs.onSurface.withValues(alpha: 0.12)
        : aq.border;
    final feedbackIcon = context.isMaterial3Ui
        ? cs.onSurface.withValues(alpha: 0.38)
        : aq.onSurfaceMuted;
    final feedbackText = context.isMaterial3Ui
        ? cs.onSurface.withValues(alpha: 0.70)
        : aq.onSurface.withValues(alpha: 0.70);

    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    final tileBody = _TileBody(
      track: track,
      isPlaying: isPlaying,
      format: format,
      index: index,
      showBitDepth: showBitDepth,
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onSecondaryTap,
      onSecondaryTapDown: onSecondaryTapDown,
    );

    final feedback = Material(
      color: Colors.transparent,
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: feedbackBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: feedbackBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note_rounded, size: 14, color: feedbackIcon),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                track.displayTitle,
                style: TextStyle(color: feedbackText, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    if (isDesktop) {
      return Draggable<List<Track>>(
        data: [track],
        feedback: feedback,
        childWhenDragging: Opacity(opacity: 0.4, child: tileBody),
        child: tileBody,
      );
    }

    return LongPressDraggable<List<Track>>(
      data: [track],
      hapticFeedbackOnStart: true,
      feedback: feedback,
      childWhenDragging: Opacity(opacity: 0.4, child: tileBody),
      child: tileBody,
    );
  }
}

class _TileBody extends ConsumerStatefulWidget {
  final Track track;
  final bool isPlaying;
  final AudioFormat format;
  final int? index;
  final bool showBitDepth;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final void Function(TapDownDetails)? onSecondaryTapDown;

  const _TileBody({
    required this.track,
    required this.isPlaying,
    required this.format,
    required this.showBitDepth,
    this.index,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onSecondaryTapDown,
  });

  @override
  ConsumerState<_TileBody> createState() => _TileBodyState();
}

class _TileBodyState extends ConsumerState<_TileBody> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (context.isMaterial3Ui) {
      return _M3TileBody(
        track: widget.track,
        isPlaying: widget.isPlaying,
        format: widget.format,
        showBitDepth: widget.showBitDepth,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onSecondaryTap: widget.onSecondaryTap,
        onSecondaryTapDown: widget.onSecondaryTapDown,
      );
    }

    final aq = context.aq;
    final accent = ref.watch(accentColorProvider);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onSecondaryTap: widget.onSecondaryTap,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          color: _hovered
              ? aq.onSurface.withValues(alpha: 0.03)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(
            children: [
              MiniAlbumArt(
                path: widget.track.path,
                playing: widget.isPlaying,
                lossless: widget.format.isLossless,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.track.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: widget.isPlaying
                            ? FontWeight.w500
                            : FontWeight.w400,
                        color: widget.isPlaying
                            ? (accent ?? aq.onSurface)
                            : aq.onSurface.withValues(alpha: 0.72),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (widget.track.artist != null) widget.track.artist!,
                        if (widget.track.album != null) widget.track.album!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: aq.onSurfaceMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Love button
              Consumer(
                builder: (context, ref, _) {
                  final isLoved = ref
                      .watch(historyProvider)
                      .isLoved(widget.track);
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: _hovered || isLoved ? 1.0 : 0.0,
                    child: _TileLoveBtn(track: widget.track, isLoved: isLoved),
                  );
                },
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Play count badge
                      Consumer(
                        builder: (context, ref, _) {
                          final count = ref
                              .watch(historyProvider)
                              .playCount(widget.track.path);
                          if (count == 0) return const SizedBox.shrink();
                          return AnimatedOpacity(
                            duration: const Duration(milliseconds: 140),
                            opacity: _hovered ? 1.0 : 0.45,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: Text(
                                '${count}x',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: aq.onSurface.withValues(alpha: 0.36),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      Text(
                        widget.track.durationLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: aq.onSurface.withValues(alpha: 0.24),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.showBitDepth
                        ? widget.track.formatLabel
                        : widget.track.format.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: widget.format.isLossless
                          ? aq.onSurface.withValues(alpha: 0.38)
                          : aq.onSurface.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _M3TileBody extends ConsumerStatefulWidget {
  final Track track;
  final bool isPlaying;
  final AudioFormat format;
  final bool showBitDepth;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final void Function(TapDownDetails)? onSecondaryTapDown;

  const _M3TileBody({
    required this.track,
    required this.isPlaying,
    required this.format,
    required this.showBitDepth,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onSecondaryTapDown,
  });

  @override
  ConsumerState<_M3TileBody> createState() => _M3TileBodyState();
}

class _M3TileBodyState extends ConsumerState<_M3TileBody> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = ref.watch(accentColorProvider);
    final formatLabel = widget.showBitDepth
        ? widget.track.formatLabel
        : widget.track.format.toUpperCase();
    final playingTint = accent ?? cs.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onSecondaryTap: widget.onSecondaryTap,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: widget.isPlaying
                ? playingTint.withValues(alpha: 0.08)
                : _hovered
                ? cs.onSurface.withValues(alpha: 0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              MiniAlbumArt(
                path: widget.track.path,
                playing: widget.isPlaying,
                lossless: widget.format.isLossless,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.track.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: widget.isPlaying
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: widget.isPlaying
                            ? playingTint
                            : cs.onSurface.withValues(alpha: 0.88),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (widget.track.artist != null) widget.track.artist!,
                        if (widget.track.album != null) widget.track.album!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  final isLoved = ref
                      .watch(historyProvider)
                      .isLoved(widget.track);
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: _hovered || isLoved ? 1.0 : 0.0,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: isLoved ? 'Unlove' : 'Love',
                      onPressed: () => ref
                          .read(historyProvider.notifier)
                          .toggleLove(widget.track),
                      icon: Icon(
                        isLoved
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                        color: isLoved
                            ? const Color(0xFFFF6B8A)
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: _hovered ? 1.0 : 0.0,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: 'Add to queue',
                  onPressed: () => ref
                      .read(playerProvider.notifier)
                      .addToQueueLast(widget.track),
                  icon: Icon(
                    Icons.playlist_add_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.track.durationLabel,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      formatLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Love button
class _TileLoveBtn extends ConsumerStatefulWidget {
  final Track track;
  final bool isLoved;
  const _TileLoveBtn({required this.track, required this.isLoved});

  @override
  ConsumerState<_TileLoveBtn> createState() => _TileLoveBtnState();
}

class _TileLoveBtnState extends ConsumerState<_TileLoveBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.45,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    _busy = true;
    await _anim.forward();
    await _anim.reverse();
    await ref.read(historyProvider.notifier).toggleLove(widget.track);
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final idleColor = isM3
        ? cs.onSurface.withValues(alpha: 0.28)
        : aq.onSurface.withValues(alpha: 0.28);

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 22,
          height: 22,
          child: Center(
            child: Icon(
              widget.isLoved
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 13,
              color: widget.isLoved ? const Color(0xFFFF6B8A) : idleColor,
            ),
          ),
        ),
      ),
    );
  }
}
