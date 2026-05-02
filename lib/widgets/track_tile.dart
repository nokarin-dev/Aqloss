import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/models/audio_format.dart';
import 'package:aqloss/providers/player_provider.dart';

class TrackTile extends ConsumerWidget {
  final Track track;
  final int? index;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TrackTile({
    super.key,
    required this.track,
    this.index,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final isPlaying = player.currentTrack?.path == track.path;
    final format = AudioFormat.fromExtension(track.format);
    final cs = Theme.of(context).colorScheme;

    return Draggable<Track>(
      data: track,
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
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
      child: _TileBody(
        track: track,
        isPlaying: isPlaying,
        format: format,
        index: index,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

class _TileBody extends StatelessWidget {
  final Track track;
  final bool isPlaying;
  final AudioFormat format;
  final int? index;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _TileBody({
    required this.track,
    required this.isPlaying,
    required this.format,
    this.index,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _Leading(isPlaying: isPlaying, format: format, index: index),
      title: Text(
        track.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isPlaying ? FontWeight.w500 : FontWeight.w400,
          color: isPlaying
              ? cs.onSurface
              : cs.onSurface.withValues(alpha: 0.70),
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        [
          if (track.artist != null) track.artist!,
          if (track.album != null) track.album!,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: cs.onSurface.withValues(alpha: 0.30),
        ),
      ),
      trailing: _Trailing(track: track, format: format),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _Leading extends StatelessWidget {
  final bool isPlaying;
  final AudioFormat format;
  final int? index;
  const _Leading({required this.isPlaying, required this.format, this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(
              child: isPlaying
                  ? Icon(
                      Icons.equalizer_rounded,
                      size: 14,
                      color: cs.onSurface.withValues(alpha: 0.54),
                    )
                  : Text(
                      index != null ? '${index! + 1}' : '♪',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.24),
                      ),
                    ),
            ),
          ),
          if (format.isLossless)
            Positioned(
              top: 1,
              right: 1,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.54),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Trailing extends StatelessWidget {
  final Track track;
  final AudioFormat format;
  const _Trailing({required this.track, required this.format});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          track.durationLabel,
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurface.withValues(alpha: 0.24),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          track.format.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: format.isLossless
                ? cs.onSurface.withValues(alpha: 0.38)
                : cs.onSurface.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}
