import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

class NowPlayingHeader extends ConsumerStatefulWidget {
  const NowPlayingHeader({super.key});

  @override
  ConsumerState<NowPlayingHeader> createState() => _NowPlayingHeaderState();
}

class _NowPlayingHeaderState extends ConsumerState<NowPlayingHeader> {
  Uint8List? _artBytes;
  String? _loadedPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final path = ref.read(playerProvider).currentTrack?.path;
    if (path != _loadedPath) _loadArt(path);
  }

  Future<void> _loadArt(String? path) async {
    if (path == null) {
      if (mounted) {
        setState(() {
          _artBytes = null;
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
    final track = player.currentTrack;

    if (track?.path != _loadedPath) {
      Future.microtask(() => _loadArt(track?.path));
    }

    if (track == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final isPlaying = player.status == PlayerStatus.playing;
    final notifier = ref.read(playerProvider.notifier);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      child: SizedBox(
        key: ValueKey(track.path),
        height: 180,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Art background
                if (_artBytes != null) ...[
                  Image.memory(_artBytes!, fit: BoxFit.cover),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.62),
                    ),
                  ),
                  // Overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.50),
                    ),
                  ),
                ] else
                  Container(color: cs.surfaceContainerHighest),

                // Content
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Cover art
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _artBytes != null
                            ? Image.memory(_artBytes!, fit: BoxFit.cover)
                            : Container(
                                color: cs.onSurface.withValues(alpha: 0.06),
                                child: Center(
                                  child: Icon(
                                    Icons.music_note_rounded,
                                    size: 18,
                                    color: cs.onSurface.withValues(alpha: 0.22),
                                  ),
                                ),
                              ),
                      ),

                      const SizedBox(width: 14),

                      // Track info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'NOW PLAYING',
                              style: TextStyle(
                                fontSize: 14,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface.withValues(alpha: 0.36),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              track.displayTitle,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${track.displayArtist} \u2014 ${track.displayAlbum}',
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.46),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Play/pause toggle
                      GestureDetector(
                        onTap: isPlaying ? notifier.pause : notifier.play,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: cs.onSurface.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: cs.onSurface,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
