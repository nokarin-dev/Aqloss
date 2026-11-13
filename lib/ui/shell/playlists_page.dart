import 'package:aqloss/l10n/l10n.dart';
import 'package:aqloss/models/playlist.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/history_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/playlist_provider.dart';
import 'package:aqloss/ui/shell/album_art.dart';
import 'package:aqloss/ui/shell/love_button.dart';
import 'package:aqloss/ui/shell/tokens.dart';
import 'package:aqloss/ui/shell/track_menu.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final playlistCreateTickProvider = StateProvider<int>((ref) => 0);

const _sheet = Color(0xFF0A0A0A);
const _chip = Color(0xFF0F0F0F);
const _line = Color(0xFF2D2D2D);
const _title = TextStyle(
  color: Colors.white,
  fontSize: 28,
  height: 36 / 28,
  fontWeight: FontWeight.w600,
);
const _section = TextStyle(
  color: Colors.white,
  fontSize: 18,
  height: 24 / 18,
  fontWeight: FontWeight.w500,
);

class PlaylistsPage extends ConsumerStatefulWidget {
  const PlaylistsPage({super.key});

  @override
  ConsumerState<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends ConsumerState<PlaylistsPage> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  String? _openId;
  bool _naming = false;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_onNameFocus);
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_onNameFocus);
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onNameFocus() {
    if (!_naming || _nameFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _nameFocus.hasFocus || !_naming) return;
      setState(() => _naming = false);
    });
  }

  void _openName() {
    setState(() => _naming = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  void _startCreate() {
    if (_openId != null) setState(() => _openId = null);
    _openName();
  }

  void _closeName() {
    if (!_naming || !mounted) return;
    _naming = false;
    _nameFocus.unfocus();
    setState(() {});
  }

  void _toggleName() {
    if (_naming) {
      _closeName();
    } else {
      _openName();
    }
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await ref.read(playlistProvider.notifier).create(name);
    if (!mounted) return;
    _name.clear();
    _nameFocus.unfocus();
    setState(() => _naming = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(playlistCreateTickProvider, (previous, next) {
      if (previous == next) return;
      _startCreate();
    });
    final playlists = ref.watch(playlistProvider);
    final open = _openId == null
        ? null
        : playlists.where((playlist) => playlist.id == _openId).firstOrNull;
    final wide = MediaQuery.sizeOf(context).width >= 800;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        wide ? 50 : 20,
        wide ? 50 : 24,
        wide ? 50 : 20,
        24,
      ),
      child: Crossfade(
        child: KeyedSubtree(
          key: ValueKey(open?.id ?? 'playlists'),
          child: open == null
              ? _Board(
                  playlists: playlists,
                  naming: _naming,
                  name: _name,
                  nameFocus: _nameFocus,
                  onName: _toggleName,
                  onDismiss: () {
                    if (_naming) _nameFocus.unfocus();
                  },
                  onCreate: _create,
                  onOpen: (playlist) {
                    _nameFocus.unfocus();
                    setState(() {
                      _naming = false;
                      _openId = playlist.id;
                    });
                  },
                )
              : _Tracks(
                  playlist: open,
                  wide: wide,
                  onBack: () => setState(() => _openId = null),
                ),
        ),
      ),
    );
  }
}

class _Board extends ConsumerWidget {
  final List<Playlist> playlists;
  final bool naming;
  final TextEditingController name;
  final FocusNode nameFocus;
  final VoidCallback onName;
  final VoidCallback onDismiss;
  final VoidCallback onCreate;
  final ValueChanged<Playlist> onOpen;

  const _Board({
    required this.playlists,
    required this.naming,
    required this.name,
    required this.nameFocus,
    required this.onName,
    required this.onDismiss,
    required this.onCreate,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final ranked =
        [
          for (var i = 0; i < playlists.length; i++)
            if (_plays(playlists[i], history) > 0) (i, playlists[i]),
        ]..sort((a, b) {
          final byPlays = _plays(
            b.$2,
            history,
          ).compareTo(_plays(a.$2, history));
          if (byPlays != 0) return byPlays;
          return a.$1.compareTo(b.$1);
        });

    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.translucent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tr('playlists.discover'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _title,
                  ),
                ),
                if (playlists.isNotEmpty) ...[
                  _RevealField(
                    open: naming,
                    align: Alignment.centerRight,
                    field: _PillField(
                      controller: name,
                      focus: nameFocus,
                      hint: tr('playlists.name_hint'),
                      width: 250,
                      onSubmit: onCreate,
                    ),
                  ),
                  _Plus(open: naming, onTap: onName),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: playlists.isEmpty
                ? _Empty(
                    naming: naming,
                    name: name,
                    focus: nameFocus,
                    onPlus: onName,
                    onCreate: onCreate,
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: playerClearance),
                    children: [
                      if (ranked.isNotEmpty) ...[
                        Text(tr('playlists.most_played'), style: _section),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 50,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: ranked.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final playlist = ranked[index].$2;
                              return _PlayedCard(
                                playlist: playlist,
                                onTap: () => onOpen(playlist),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                      Text(tr('playlists.all'), style: _section),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 20,
                        children: [
                          for (final playlist in playlists)
                            _CoverCard(
                              playlist: playlist,
                              onTap: () => onOpen(playlist),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final bool naming;
  final TextEditingController name;
  final FocusNode focus;
  final VoidCallback onPlus;
  final VoidCallback onCreate;

  const _Empty({
    required this.naming,
    required this.name,
    required this.focus,
    required this.onPlus,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 530 ? constraints.maxWidth : 530.0;
        final room = width / 2 - 25;
        final fieldWidth = room > 250 ? 250.0 : (room < 0 ? 0.0 : room);
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: width,
                height: 298,
                decoration: BoxDecoration(
                  color: _sheet,
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icons/playlist_empty.png',
                      width: 56,
                      height: 56,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      tr('playlists.none'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 24 / 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: width,
                height: 30,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _Plus(open: naming, onTap: onPlus),
                    Positioned(
                      left: width / 2 + 15,
                      top: 0,
                      bottom: 0,
                      child: _RevealField(
                        open: naming,
                        align: Alignment.centerLeft,
                        field: _PillField(
                          controller: name,
                          focus: focus,
                          hint: tr('playlists.name_hint'),
                          width: fieldWidth,
                          onSubmit: onCreate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayedCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;

  const _PlayedCard({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final artist = playlist.tracks.isEmpty
        ? ''
        : playlist.tracks.first.uiArtist;
    return PlaylistMenu(
      playlist: playlist,
      child: Material(
        color: _chip,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 50,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Art(playlist: playlist, size: 30, radius: 6),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        if (artist.isNotEmpty)
                          Text(
                            artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: textMuted,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 50),
                  Text(
                    _clock(playlist.totalDuration),
                    style: const TextStyle(color: textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;

  const _CoverCard({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final artist = playlist.tracks.isEmpty
        ? ''
        : playlist.tracks.first.uiArtist;
    return PlaylistMenu(
      playlist: playlist,
      child: SizedBox(
        width: 180,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            mouseCursor: SystemMouseCursors.click,
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Art(playlist: playlist, size: 180, radius: 10),
                const SizedBox(height: 6),
                Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                if (artist.isNotEmpty)
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: textMuted, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tracks extends ConsumerWidget {
  final Playlist playlist;
  final bool wide;
  final VoidCallback onBack;

  const _Tracks({
    required this.playlist,
    required this.wide,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(
      playerProvider.select((player) => player.currentTrack?.path),
    );
    final status = ref.watch(playerProvider.select((player) => player.status));
    final here =
        current != null &&
        playlist.tracks.any((track) => track.path == current);
    final playing = here && status == PlayerStatus.playing;
    final art = wide ? 128.0 : 88.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PlaylistMenu(
                playlist: playlist,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Art(playlist: playlist, size: art, radius: 12),
                    const SizedBox(width: 30),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (playlist.tracks.isNotEmpty)
                            Text(
                              playlist.tracks.first.uiArtist,
                              style: const TextStyle(
                                color: textMuted,
                                fontSize: 14,
                              ),
                            ),
                          if (wide && playlist.tracks.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _PlayMark(
                              playing: playing,
                              onTap: () {
                                final notifier = ref.read(
                                  playerProvider.notifier,
                                );
                                if (playing) {
                                  notifier.pause();
                                } else if (here) {
                                  notifier.play();
                                } else {
                                  notifier.loadWithQueue(
                                    playlist.tracks.first,
                                    playlist.tracks,
                                  );
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            _BackCard(onTap: onBack),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: playlist.tracks.isEmpty
              ? Center(
                  child: Text(
                    tr('playlists.tracks_empty'),
                    style: const TextStyle(color: textMuted, fontSize: 15),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 108),
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, animation) => child,
                  itemCount: playlist.tracks.length,
                  onReorderItem: (oldIndex, newIndex) {
                    ref
                        .read(playlistProvider.notifier)
                        .reorderTrack(playlist.id, oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final track = playlist.tracks[index];
                    return _TrackLine(
                      key: ValueKey(track.path),
                      playlistId: playlist.id,
                      index: index,
                      track: track,
                      active: track.path == current,
                      onTap: () {
                        ref
                            .read(playerProvider.notifier)
                            .loadWithQueue(track, playlist.tracks);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TrackLine extends StatelessWidget {
  final String playlistId;
  final int index;
  final Track track;
  final bool active;
  final VoidCallback onTap;

  const _TrackLine({
    super.key,
    required this.playlistId,
    required this.index,
    required this.track,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TrackMenu(
      track: track,
      playlistId: playlistId,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: active ? const Color(0xFF050505) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: active ? _line : Colors.transparent),
          ),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: SizedBox(
                      width: 44,
                      height: 64,
                      child: Icon(
                        CupertinoIcons.line_horizontal_3,
                        size: 18,
                        color: textMuted,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _MouseReorder(
                    index: index,
                    child: InkWell(
                      mouseCursor: SystemMouseCursors.click,
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Row(
                          children: [
                            MiniAlbumArt(path: track.path, size: 28, radius: 6),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.displayTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    track.uiArtist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            LoveButton(track: track),
                            Text(
                              track.durationLabel,
                              style: const TextStyle(
                                color: textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

// Reorder on a vertical mouse drag. Touch scrolling stays with the list.
class _MouseReorder extends StatelessWidget {
  final int index;
  final Widget child;

  const _MouseReorder({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.touch ||
            event.kind == PointerDeviceKind.stylus) {
          return;
        }
        if (event.buttons != kPrimaryButton) return;
        SliverReorderableList.maybeOf(context)?.startItemDragReorder(
          index: index,
          event: event,
          recognizer: VerticalMultiDragGestureRecognizer()
            ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context),
        );
      },
      child: child,
    );
  }
}

class _PillField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final String hint;
  final double width;
  final VoidCallback? onSubmit;

  const _PillField({
    required this.controller,
    required this.focus,
    required this.hint,
    required this.width,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 30,
      child: CupertinoTextField(
        controller: controller,
        focusNode: focus,
        placeholder: hint,
        placeholderStyle: const TextStyle(color: textMuted, fontSize: 13),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        cursorColor: Colors.white,
        clearButtonMode: OverlayVisibilityMode.never,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF3A3A3A)),
        ),
        onSubmitted: (_) => onSubmit?.call(),
      ),
    );
  }
}

class _RevealField extends StatelessWidget {
  final bool open;
  final Alignment align;
  final Widget field;

  const _RevealField({
    required this.open,
    required this.align,
    required this.field,
  });

  @override
  Widget build(BuildContext context) {
    final leading = align == Alignment.centerLeft;
    return AnimatedSize(
      duration: motionOf(context),
      curve: motionCurve,
      alignment: align,
      child: AnimatedSwitcher(
        duration: motionOf(context),
        switchInCurve: motionCurve,
        switchOutCurve: motionCurve,
        layoutBuilder: (current, previous) {
          return Stack(
            alignment: align,
            children: [
              for (final old in previous) IgnorePointer(child: old),
              ?current,
            ],
          );
        },
        child: open
            ? KeyedSubtree(
                key: const ValueKey('field'),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: leading ? 10 : 0,
                    right: leading ? 0 : 10,
                  ),
                  child: field,
                ),
              )
            : const SizedBox(key: ValueKey('shut'), width: 0, height: 30),
      ),
    );
  }
}

class _BackCard extends StatelessWidget {
  final VoidCallback onTap;

  const _BackCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _sheet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _line),
      ),
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.chevron_left,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                tr('playlists.back'),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Plus extends StatelessWidget {
  final bool open;
  final VoidCallback onTap;

  const _Plus({required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tr(open ? 'sidebar.dismiss' : 'playlists.new'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: const CustomPaint(size: Size.square(20), painter: _PlusMark()),
        ),
      ),
    );
  }
}

class _PlayMark extends StatelessWidget {
  final bool playing;
  final VoidCallback onTap;

  const _PlayMark({required this.playing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            playing ? Icons.pause : Icons.play_arrow,
            color: Colors.black,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _Art extends StatelessWidget {
  final Playlist playlist;
  final double size;
  final double radius;

  const _Art({
    required this.playlist,
    required this.size,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    if (playlist.tracks.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: ColoredBox(
          color: _chip,
          child: SizedBox.square(dimension: size),
        ),
      );
    }
    return MiniAlbumArt(
      path: playlist.tracks.first.path,
      size: size,
      radius: radius,
    );
  }
}

class _PlusMark extends CustomPainter {
  const _PlusMark();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final rect = Offset.zero & size;
    canvas.drawCircle(rect.center, size.width / 2 - 0.8, paint);
    final arm = size.width * 0.22;
    canvas.drawLine(
      rect.center - Offset(arm, 0),
      rect.center + Offset(arm, 0),
      paint,
    );
    canvas.drawLine(
      rect.center - Offset(0, arm),
      rect.center + Offset(0, arm),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

int _plays(Playlist playlist, HistoryState history) {
  var total = 0;
  for (final track in playlist.tracks) {
    total += history.playCount(track.path);
  }
  return total;
}

String _clock(Duration duration) {
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
