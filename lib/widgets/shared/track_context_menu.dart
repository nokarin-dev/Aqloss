import 'dart:io';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:aqloss/widgets/q_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showTrackContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required Track track,
  required WidgetRef ref,
}) async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

  final playlists = ref.read(playlistProvider);
  final notifier = ref.read(playlistProvider.notifier);
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final size = overlay.size;

  final left = globalPosition.dx.clamp(8.0, size.width - 220);
  final top = globalPosition.dy.clamp(8.0, size.height - 280);

  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(left, top, left + 1, top + 1),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    elevation: 8,
    items: [
      if (playlists.isNotEmpty)
        const PopupMenuItem<String>(
          enabled: false,
          height: 28,
          child: Text(
            'Add to playlist',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ...playlists.map(
        (pl) => PopupMenuItem<String>(
          value: pl.id,
          height: 36,
          child: Row(
            children: [
              Icon(
                Icons.queue_music_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pl.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
      if (playlists.isEmpty)
        const PopupMenuItem<String>(
          enabled: false,
          child: Text('No playlists yet', style: TextStyle(fontSize: 12)),
        ),
    ],
  );

  if (selected != null && context.mounted) {
    notifier.addTrack(selected, track);
    final pl = playlists.firstWhere((p) => p.id == selected);
    QToast.show(context, 'Added to "${pl.name}"');
  }
}
