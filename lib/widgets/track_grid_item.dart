import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/models/audio_format.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

class TrackGridItem extends ConsumerStatefulWidget {
  final Track track;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;

  const TrackGridItem({
    super.key,
    required this.track,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
  });

  @override
  ConsumerState<TrackGridItem> createState() => _TrackGridItemState();
}

class _TrackGridItemState extends ConsumerState<TrackGridItem> {
  Uint8List? _artBytes;
  String? _loadedPath;

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
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onSecondaryTap: widget.onSecondaryTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        decoration: BoxDecoration(
          color: isPlaying
              ? cs.onSurface.withValues(alpha: 0.06)
              : cs.onSurface.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPlaying
                ? cs.onSurface.withValues(alpha: 0.16)
                : cs.onSurface.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album art
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(9),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _artBytes != null
                        ? Image.memory(_artBytes!, fit: BoxFit.cover)
                        : Container(
                            color: cs.onSurface.withValues(alpha: 0.04),
                            child: Icon(
                              Icons.album_rounded,
                              size: 28,
                              color: cs.onSurface.withValues(alpha: 0.10),
                            ),
                          ),
                    if (isPlaying)
                      Container(
                        color: Colors.black.withValues(alpha: 0.35),
                        child: Center(
                          child: Icon(
                            Icons.equalizer_rounded,
                            size: 20,
                            color: Colors.white.withValues(alpha: 0.80),
                          ),
                        ),
                      ),
                    // lossless dot
                    if (format.isLossless)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: cs.onSurface.withValues(alpha: 0.60),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Title + artist
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.track.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isPlaying ? FontWeight.w500 : FontWeight.w400,
                      color: isPlaying
                          ? cs.onSurface
                          : cs.onSurface.withValues(alpha: 0.80),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.track.displayArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
