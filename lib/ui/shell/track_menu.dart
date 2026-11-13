import 'package:aqloss/l10n/l10n.dart';
import 'package:aqloss/models/playlist.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:aqloss/services/playlist_io_service.dart';
import 'package:aqloss/ui/shell/glass_morph.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

class TrackMenu extends ConsumerWidget {
  final Track track;
  final Widget child;
  final String? playlistId;

  const TrackMenu({
    super.key,
    required this.track,
    required this.child,
    this.playlistId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onSecondaryTapUp: (details) => _open(context, details.globalPosition),
      onLongPressStart: (details) => _open(context, details.globalPosition),
      child: child,
    );
  }

  void _open(BuildContext context, Offset origin) {
    showShellMorph(
      context: context,
      origin: origin,
      menu: (_) => _TrackActions(
        key: const ValueKey('track'),
        track: track,
        playlistId: playlistId,
      ),
    );
  }
}

class PlaylistMenu extends ConsumerWidget {
  final Playlist playlist;
  final Widget child;

  const PlaylistMenu({super.key, required this.playlist, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onSecondaryTapUp: (details) => _open(context, details.globalPosition),
      onLongPressStart: (details) => _open(context, details.globalPosition),
      child: child,
    );
  }

  void _open(BuildContext context, Offset origin) {
    showShellMorph(
      context: context,
      origin: origin,
      menu: (routeContext) => _PlaylistActions(
        key: const ValueKey('playlist'),
        playlist: playlist,
        pageContext: context,
        routeContext: routeContext,
      ),
    );
  }
}

class _TrackActions extends ConsumerWidget {
  final Track track;
  final String? playlistId;

  const _TrackActions({super.key, required this.track, this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ShellMenu(
      children: [
        ShellMenuRow(
          icon: CupertinoIcons.play_fill,
          label: tr('player.play_next'),
          onTap: () {
            Navigator.pop(context);
            ref.read(playerProvider.notifier).playNext(track);
          },
        ),
        ShellMenuRow(
          icon: CupertinoIcons.list_bullet,
          label: tr('queue.add'),
          onTap: () {
            Navigator.pop(context);
            ref.read(playerProvider.notifier).addToQueueLast(track);
          },
        ),
        if (playlistId == null)
          ShellMenuRow(
            icon: CupertinoIcons.music_note_list,
            label: tr('track.add_playlist'),
            onTap: () {
              MorphSwap.of(context).replace(
                _PlaylistPick(key: const ValueKey('pick'), track: track),
              );
            },
          )
        else
          ShellMenuRow(
            icon: CupertinoIcons.trash,
            label: tr('playlists.remove_track'),
            destructive: true,
            onTap: () {
              final id = playlistId!;
              Navigator.pop(context);
              Playlist? playlist;
              for (final item in ref.read(playlistProvider)) {
                if (item.id == id) playlist = item;
              }
              if (playlist == null) return;
              final index = playlist.tracks.indexWhere(
                (item) => item.path == track.path,
              );
              if (index < 0) return;
              ref.read(playlistProvider.notifier).removeTrack(id, index);
            },
          ),
      ],
    );
  }
}

class _PlaylistPick extends ConsumerWidget {
  final Track track;

  const _PlaylistPick({super.key, required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistProvider);
    return ShellMenu(
      children: [
        if (playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text(
              tr('playlists.empty'),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          )
        else
          for (final playlist in playlists)
            ShellMenuRow(
              label: playlist.name,
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(playlistProvider.notifier)
                    .addTrack(playlist.id, track);
              },
            ),
        ShellMenuRow(
          label: tr('sidebar.dismiss'),
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

class _PlaylistActions extends ConsumerWidget {
  final Playlist playlist;
  final BuildContext pageContext;
  final BuildContext routeContext;

  const _PlaylistActions({
    super.key,
    required this.playlist,
    required this.pageContext,
    required this.routeContext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ShellMenu(
      children: [
        ShellMenuRow(
          icon: CupertinoIcons.square_arrow_up,
          label: tr('playlists.export'),
          onTap: () async {
            Navigator.pop(routeContext);
            await _export(pageContext, playlist);
          },
        ),
        ShellMenuRow(
          icon: CupertinoIcons.trash,
          label: tr('playlists.remove'),
          destructive: true,
          onTap: () {
            Navigator.pop(routeContext);
            ref.read(playlistProvider.notifier).delete(playlist.id);
          },
        ),
      ],
    );
  }
}

Future<void> _export(BuildContext context, Playlist playlist) async {
  final result = await PlaylistIOService.export(playlist);
  if (!context.mounted || result.success || result.error == null) return;
  await showLiquidGlassDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return LiquidGlassDialog(
        width: 320,
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('playlists.export'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                trFill('playlists.export_failed', {'error': '${result.error}'}),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(tr('sidebar.dismiss')),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
