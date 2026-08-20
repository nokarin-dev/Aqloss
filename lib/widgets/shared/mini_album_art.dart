import 'dart:typed_data';

import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:flutter/material.dart';

// Playing overlay
class PlayingArtScrim extends StatelessWidget {
  final double iconSize;
  const PlayingArtScrim({super.key, this.iconSize = 14});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.22),
      child: Center(
        child: Icon(
          Icons.equalizer_rounded,
          size: iconSize,
          color: Colors.white.withValues(alpha: 0.94),
          shadows: const [Shadow(color: Color(0x99000000), blurRadius: 8)],
        ),
      ),
    );
  }
}

class MiniAlbumArt extends StatefulWidget {
  final String path;
  final double size;
  final bool playing;
  final bool lossless;
  final double radius;

  const MiniAlbumArt({
    super.key,
    required this.path,
    this.size = 36,
    this.playing = false,
    this.lossless = false,
    this.radius = 5,
  });

  @override
  State<MiniAlbumArt> createState() => _MiniAlbumArtState();
}

class _MiniAlbumArtState extends State<MiniAlbumArt> {
  Uint8List? _artBytes;
  String? _loadedPath;

  @override
  void initState() {
    super.initState();
    _load(widget.path);
  }

  @override
  void didUpdateWidget(MiniAlbumArt old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _load(widget.path);
  }

  Future<void> _load(String path) async {
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
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final bg = isM3 ? cs.onSurface.withValues(alpha: 0.05) : aq.indicator;
    final iconIdle = isM3
        ? cs.onSurface.withValues(alpha: 0.18)
        : aq.onSurface.withValues(alpha: 0.18);
    final losslessDot = isM3
        ? cs.onSurface.withValues(alpha: 0.55)
        : aq.onSurface.withValues(alpha: 0.55);
    final radius = BorderRadius.circular(widget.radius);
    final iconSize = (widget.size * 0.38).clamp(12.0, 18.0);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: radius,
            child: ColoredBox(
              color: bg,
              child: _artBytes != null
                  ? Image.memory(
                      _artBytes!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : Icon(
                      Icons.music_note_rounded,
                      size: iconSize,
                      color: iconIdle,
                    ),
            ),
          ),
          if (widget.playing)
            ClipRRect(
              borderRadius: radius,
              child: PlayingArtScrim(iconSize: iconSize),
            ),
          if (widget.lossless)
            Positioned(
              top: 1,
              right: 1,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: losslessDot,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
