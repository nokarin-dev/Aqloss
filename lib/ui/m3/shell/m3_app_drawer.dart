import 'package:aqloss/models/playlist.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:aqloss/ui/m3/m3_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class M3AppDrawer extends ConsumerWidget {
  final int route;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreatePlaylist;
  final VoidCallback? onSearch;
  final VoidCallback? onOpenQueue;

  const M3AppDrawer({
    super.key,
    required this.route,
    required this.onSelect,
    required this.onCreatePlaylist,
    this.onSearch,
    this.onOpenQueue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistProvider);
    final library = ref.watch(libraryProvider);
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 16, 8),
              child: Text('Aqloss', style: theme.textTheme.headlineSmall),
            ),
            if (library.totalTracks > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 16, 8),
                child: Text(
                  '${library.totalTracks} tracks',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (onSearch != null)
              ListTile(
                leading: const Icon(Icons.search_rounded),
                title: const Text('Search'),
                onTap: () {
                  Navigator.pop(context);
                  onSearch!();
                },
              ),
            if (onOpenQueue != null)
              ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: const Text('Queue'),
                onTap: () {
                  Navigator.pop(context);
                  onOpenQueue!();
                },
              ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Artists'),
              selected: route == M3Route.artists,
              onTap: () {
                Navigator.pop(context);
                onSelect(M3Route.artists);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('History'),
              selected: route == M3Route.history,
              onTap: () {
                Navigator.pop(context);
                onSelect(M3Route.history);
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Playlists', style: theme.textTheme.titleSmall),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'New playlist',
                    onPressed: () {
                      Navigator.pop(context);
                      onCreatePlaylist();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: playlists.isEmpty
                  ? Center(
                      child: Text(
                        'No playlists yet',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: playlists.length,
                      itemBuilder: (ctx, i) {
                        final pl = playlists[i];
                        return _PlaylistTile(
                          playlist: pl,
                          selected: route == M3Route.playlistBase + i,
                          onTap: () {
                            Navigator.pop(context);
                            onSelect(M3Route.playlistBase + i);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final bool selected;
  final VoidCallback onTap;

  const _PlaylistTile({
    required this.playlist,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.queue_music_rounded),
      title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${playlist.length} tracks'),
      selected: selected,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    );
  }
}

Future<void> showM3CreatePlaylistDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final ctrl = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('New playlist'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Playlist name',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Create'),
        ),
      ],
    ),
  );
  if (name != null && name.isNotEmpty && context.mounted) {
    ref.read(playlistProvider.notifier).create(name);
  }
}
