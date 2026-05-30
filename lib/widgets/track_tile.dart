import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/models/audio_format.dart';
import 'package:aqloss/providers/history_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

class TrackTile extends ConsumerWidget {
  final Track track;
  final int? index;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;

  const TrackTile({
    super.key,
    required this.track,
    this.index,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final isPlaying = player.currentTrack?.path == track.path;
    final format = AudioFormat.fromExtension(track.format);
    final showBitDepth = ref.watch(settingsProvider).showBitDepthInLibrary;
    final cs = Theme.of(context).colorScheme;

    return LongPressDraggable<List<Track>>(
      data: [track],
      hapticFeedbackOnStart: true,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.12)),
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
              Icon(
                Icons.music_note_rounded,
                size: 14,
                color: cs.onSurface.withValues(alpha: 0.38),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  track.displayTitle,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.70),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _TileBody(
          track: track,
          isPlaying: isPlaying,
          format: format,
          index: index,
          showBitDepth: showBitDepth,
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTap: onSecondaryTap,
        ),
      ),
      child: _TileBody(
        track: track,
        isPlaying: isPlaying,
        format: format,
        index: index,
        showBitDepth: showBitDepth,
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onSecondaryTap,
      ),
    );
  }
}

class _TileBody extends StatefulWidget {
  final Track track;
  final bool isPlaying;
  final AudioFormat format;
  final int? index;
  final bool showBitDepth;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;

  const _TileBody({
    required this.track,
    required this.isPlaying,
    required this.format,
    required this.showBitDepth,
    this.index,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
  });

  @override
  State<_TileBody> createState() => _TileBodyState();
}

class _TileBodyState extends State<_TileBody> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onSecondaryTap: widget.onSecondaryTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          color: _hovered
              ? cs.onSurface.withValues(alpha: 0.03)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(
            children: [
              _ArtThumb(
                path: widget.track.path,
                isPlaying: widget.isPlaying,
                isLossless: widget.format.isLossless,
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
                            ? cs.onSurface
                            : cs.onSurface.withValues(alpha: 0.72),
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
                        color: cs.onSurface.withValues(alpha: 0.30),
                      ),
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
                                  color: cs.onSurface.withValues(alpha: 0.36),
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
                          color: cs.onSurface.withValues(alpha: 0.24),
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
                          ? cs.onSurface.withValues(alpha: 0.38)
                          : cs.onSurface.withValues(alpha: 0.15),
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

class _ArtThumb extends ConsumerStatefulWidget {
  final String path;
  final bool isPlaying;
  final bool isLossless;

  const _ArtThumb({
    required this.path,
    required this.isPlaying,
    required this.isLossless,
  });

  @override
  ConsumerState<_ArtThumb> createState() => _ArtThumbState();
}

class _ArtThumbState extends ConsumerState<_ArtThumb> {
  Uint8List? _artBytes;
  String? _loadedPath;

  @override
  void initState() {
    super.initState();
    _loadArt(widget.path);
  }

  @override
  void didUpdateWidget(_ArtThumb old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _loadArt(widget.path);
  }

  Future<void> _loadArt(String path) async {
    _loadedPath = path;
    if (mounted) setState(() => _artBytes = null);
    try {
      final bytes = await backend.readAlbumArtThumbnail(path: path);
      if (mounted && _loadedPath == path) {
        setState(
          () => _artBytes = bytes != null ? Uint8List.fromList(bytes) : null,
        );
      }
    } catch (_) {
      if (mounted && _loadedPath == path) setState(() => _artBytes = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Container(
              width: 36,
              height: 36,
              color: cs.onSurface.withValues(alpha: 0.05),
              child: widget.isPlaying
                  ? Icon(
                      Icons.equalizer_rounded,
                      size: 14,
                      color: cs.onSurface.withValues(alpha: 0.54),
                    )
                  : _artBytes != null
                  ? Image.memory(_artBytes!, fit: BoxFit.cover)
                  : Icon(
                      Icons.music_note_rounded,
                      size: 14,
                      color: cs.onSurface.withValues(alpha: 0.18),
                    ),
            ),
          ),
          if (widget.isLossless)
            Positioned(
              top: 1,
              right: 1,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
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
    final cs = Theme.of(context).colorScheme;
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
              color: widget.isLoved
                  ? const Color(0xFFFF6B8A)
                  : cs.onSurface.withValues(alpha: 0.28),
            ),
          ),
        ),
      ),
    );
  }
}
