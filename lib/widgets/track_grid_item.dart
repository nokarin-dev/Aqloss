import 'dart:io';
import 'dart:typed_data';
import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/models/audio_format.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/widgets/shared/mini_album_art.dart';

class TrackGridItem extends ConsumerStatefulWidget {
  final Track track;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final void Function(TapDownDetails)? onSecondaryTapDown;

  const TrackGridItem({
    super.key,
    required this.track,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onSecondaryTapDown,
  });

  @override
  ConsumerState<TrackGridItem> createState() => _TrackGridItemState();
}

class _TrackGridItemState extends ConsumerState<TrackGridItem> {
  Uint8List? _artBytes;
  String? _loadedPath;
  bool _hovered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.track.path != _loadedPath) _loadArt(widget.track.path);
  }

  Future<void> _loadArt(String path) async {
    _loadedPath = path;
    try {
      final bytes = await backend.readAlbumArtThumbnail(path: path);
      if (mounted && _loadedPath == path) {
        setState(
          () => _artBytes = bytes != null ? Uint8List.fromList(bytes) : null,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _artBytes = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final isPlaying = player.currentTrack?.path == widget.track.path;
    final format = AudioFormat.fromExtension(widget.track.format);
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final isM3 = context.isMaterial3Ui;

    final content = _GridContent(
      track: widget.track,
      artBytes: _artBytes,
      isPlaying: isPlaying,
      format: format,
      hovered: isM3 && _hovered,
      onPlay: widget.onTap,
    );

    Widget tile;
    if (isM3) {
      tile = MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: _hovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            elevation: _hovered ? 4 : (isPlaying ? 2 : 0),
            child: InkWell(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              onSecondaryTap: widget.onSecondaryTap,
              onSecondaryTapDown: widget.onSecondaryTapDown,
              child: content,
            ),
          ),
        ),
      );
    } else {
      final aq = context.aq;
      tile = GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onSecondaryTap: widget.onSecondaryTap,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          decoration: BoxDecoration(
            color: isPlaying
                ? aq.onSurface.withValues(alpha: 0.06)
                : aq.onSurface.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isPlaying
                  ? aq.onSurface.withValues(alpha: 0.16)
                  : aq.border,
            ),
          ),
          child: content,
        ),
      );
    }

    if (!isDesktop) return tile;

    return Draggable<List<Track>>(
      data: [widget.track],
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 72, height: 90, child: tile),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }
}

class _GridContent extends StatelessWidget {
  final Track track;
  final Uint8List? artBytes;
  final bool isPlaying;
  final AudioFormat format;
  final bool hovered;
  final VoidCallback? onPlay;

  const _GridContent({
    required this.track,
    required this.artBytes,
    required this.isPlaying,
    required this.format,
    this.hovered = false,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    final artBg = isM3 ? cs.onSurface.withValues(alpha: 0.04) : aq.indicator;
    final artIcon = isM3
        ? cs.onSurface.withValues(alpha: 0.10)
        : aq.onSurface.withValues(alpha: 0.10);
    final losslessDot = isM3
        ? cs.onSurface.withValues(alpha: 0.60)
        : aq.onSurface.withValues(alpha: 0.60);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: isM3
                ? BorderRadius.zero
                : const BorderRadius.vertical(top: Radius.circular(9)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                artBytes != null
                    ? Image.memory(artBytes!, fit: BoxFit.cover)
                    : Container(
                        color: artBg,
                        child: Icon(
                          Icons.album_rounded,
                          size: 28,
                          color: artIcon,
                        ),
                      ),
                if (isPlaying) const PlayingArtScrim(iconSize: 22),
                if (isM3 && hovered && !isPlaying)
                  AnimatedOpacity(
                    opacity: 1,
                    duration: const Duration(milliseconds: 160),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.38),
                      child: Center(
                        child: IconButton.filled(
                          onPressed: onPlay,
                          icon: const Icon(Icons.play_arrow_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (format.isLossless)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: losslessDot,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  track.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isPlaying ? FontWeight.w500 : FontWeight.w400,
                    color: isPlaying
                        ? onSurface
                        : onSurface.withValues(alpha: 0.80),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.displayArtist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: isM3
                        ? cs.onSurface.withValues(alpha: 0.35)
                        : aq.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
