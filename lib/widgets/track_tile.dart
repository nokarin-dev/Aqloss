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

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _buildLeading(context, isPlaying, format),
      title: Text(
        track.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isPlaying ? FontWeight.w500 : FontWeight.normal,
          color: isPlaying
              ? Theme.of(context).colorScheme.primary
              : null,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        '${track.displayArtist} · ${track.displayAlbum}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.38),
        ),
      ),
      trailing: _buildTrailing(context, format),
      onTap: onTap ??
          () {
            ref.read(playerProvider.notifier).load(track);
          },
      onLongPress: onLongPress,
    );
  }

  Widget _buildLeading(
      BuildContext context, bool isPlaying, AudioFormat format) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: isPlaying
                  ? Icon(Icons.equalizer,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary)
                  : Text(
                      index != null ? '${index! + 1}' : '♪',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
            ),
          ),
          if (format.isLossless)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrailing(BuildContext context, AudioFormat format) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          track.durationLabel,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: format.isLossless
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            track.format.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: format.isLossless
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ),
      ],
    );
  }
}
