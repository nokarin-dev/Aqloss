import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:aqloss/models/playlist.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

class PlaylistArtIcon extends StatefulWidget {
  final Playlist playlist;
  final double size;
  final double radius;

  const PlaylistArtIcon({
    super.key,
    required this.playlist,
    this.size = 26,
    this.radius = 5,
  });

  @override
  State<PlaylistArtIcon> createState() => _PlaylistArtIconState();
}

class _PlaylistArtIconState extends State<PlaylistArtIcon> {
  Uint8List? _bytes;
  String? _loadedPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PlaylistArtIcon old) {
    super.didUpdateWidget(old);
    final newPath = widget.playlist.tracks.firstOrNull?.path;
    if (newPath != _loadedPath) _load();
  }

  Future<void> _load() async {
    final path = widget.playlist.tracks.firstOrNull?.path;
    if (path == null) {
      if (mounted) {
        setState(() {
          _bytes = null;
          _loadedPath = null;
        });
      }
      return;
    }
    _loadedPath = path;
    try {
      final bytes = await backend.readAlbumArt(path: path);
      if (mounted && _loadedPath == path) {
        setState(
          () => _bytes = bytes != null ? Uint8List.fromList(bytes) : null,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _bytes = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final letter = widget.playlist.name.isNotEmpty
        ? widget.playlist.name[0].toUpperCase()
        : '♪';

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: _bytes != null
          ? Image.memory(_bytes!, fit: BoxFit.cover)
          : Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: widget.size * 0.38,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.44),
                ),
              ),
            ),
    );
  }
}
