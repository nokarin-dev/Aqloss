import 'package:aqloss/l10n/l10n.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/ui/shell/album_art.dart';
import 'package:aqloss/ui/shell/glass.dart';
import 'package:aqloss/ui/shell/tokens.dart';
import 'package:aqloss/ui/shell/track_menu.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _line = Color(0xFF3A3A3A);
const _deskWidth = 280.0;

const _title = TextStyle(
  color: Colors.white,
  fontSize: 28,
  height: 36 / 28,
  fontWeight: FontWeight.w600,
);

// Slides over the open page. The page underneath stays.
class QueueOverlay extends ConsumerWidget {
  final bool open;
  final bool phone;
  final EdgeInsets margin;
  final VoidCallback onClose;
  final VoidCallback onOpenLibrary;

  const QueueOverlay({
    super.key,
    required this.open,
    required this.phone,
    this.margin = EdgeInsets.zero,
    required this.onClose,
    required this.onOpenLibrary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(playerProvider.select((player) => player.queue));
    final index = ref.watch(
      playerProvider.select((player) => player.queueIndex),
    );
    final body = phone
        ? _Phone(queue: queue, index: index, onOpenLibrary: onOpenLibrary)
        : _Desk(
            queue: queue,
            index: index,
            onClose: onClose,
            onOpenLibrary: onOpenLibrary,
          );

    // Clip the slide to the page.
    return Positioned.fill(
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = phone
                ? constraints.maxWidth
                : _deskWidth + margin.horizontal;
            return Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                width: width,
                height: constraints.maxHeight,
                child: IgnorePointer(
                  ignoring: !open,
                  child: AnimatedSlide(
                    offset: open ? Offset.zero : const Offset(1, 0),
                    duration: motionOf(context),
                    curve: motionCurve,
                    child: Padding(padding: margin, child: body),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Desk extends StatelessWidget {
  final List<Track> queue;
  final int index;
  final VoidCallback onClose;
  final VoidCallback onOpenLibrary;

  const _Desk({
    required this.queue,
    required this.index,
    required this.onClose,
    required this.onOpenLibrary,
  });

  @override
  Widget build(BuildContext context) {
    return ShellLens(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _Close(onClose: onClose),
          ),
          Expanded(
            child: queue.isEmpty
                ? _Empty(onOpenLibrary: onOpenLibrary, bottom: 0)
                : _Tracks(queue: queue, index: index, bottom: 8),
          ),
        ],
      ),
    );
  }
}

class _Phone extends StatelessWidget {
  final List<Track> queue;
  final int index;
  final VoidCallback onOpenLibrary;

  const _Phone({
    required this.queue,
    required this.index,
    required this.onOpenLibrary,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 44,
              width: double.infinity,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tr('queue'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _title,
                ),
              ),
            ),
            Expanded(
              child: queue.isEmpty
                  ? _Empty(
                      onOpenLibrary: onOpenLibrary,
                      bottom: playerClearance,
                    )
                  : _Tracks(
                      queue: queue,
                      index: index,
                      bottom: playerClearance,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Close extends StatelessWidget {
  final VoidCallback onClose;

  const _Close({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tr('queue.toggle'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onClose,
          behavior: HitTestBehavior.opaque,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x66FFFFFF)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(0, 1),
                    child: Icon(
                      CupertinoIcons.chevron_right,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    tr('sidebar.queue'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1,
                      fontWeight: FontWeight.w500,
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
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

class _Tracks extends ConsumerWidget {
  final List<Track> queue;
  final int index;
  final double bottom;

  const _Tracks({
    required this.queue,
    required this.index,
    required this.bottom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = <String, int>{};
    final keys = [
      for (final track in queue)
        ValueKey(
          '${track.path}#${seen.update(track.path, (v) => v + 1, ifAbsent: () => 0)}',
        ),
    ];
    return ReorderableListView.builder(
      padding: EdgeInsets.only(top: 12, bottom: bottom),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) => child,
      itemCount: queue.length,
      onReorderItem: (oldIndex, newIndex) {
        ref.read(playerProvider.notifier).reorderQueue(oldIndex, newIndex);
      },
      itemBuilder: (context, i) {
        final track = queue[i];
        return Padding(
          key: keys[i],
          padding: const EdgeInsets.only(bottom: 8),
          child: _Card(
            index: i,
            track: track,
            active: i == index,
            onTap: () {
              if (i == index) return;
              ref.read(playerProvider.notifier).jumpToQueue(i);
            },
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  final int index;
  final Track track;
  final bool active;
  final VoidCallback onTap;

  const _Card({
    required this.index,
    required this.track,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TrackMenu(
      track: track,
      child: Material(
        color: active ? const Color(0x18FFFFFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line),
          ),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: SizedBox(
                      width: 28,
                      height: 56,
                      child: Icon(
                        CupertinoIcons.line_horizontal_3,
                        size: 16,
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
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 56,
                        child: Row(
                          children: [
                            MiniAlbumArt(path: track.path, size: 40, radius: 8),
                            const SizedBox(width: 10),
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
                                      fontWeight: FontWeight.w500,
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
                            Text(
                              track.durationLabel,
                              style: const TextStyle(
                                color: textMuted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
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

class _Empty extends StatelessWidget {
  final VoidCallback onOpenLibrary;
  final double bottom;

  const _Empty({required this.onOpenLibrary, required this.bottom});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < 420
              ? constraints.maxWidth
              : 420.0;
          return Center(
            child: SizedBox(width: width, child: _emptyCard(onOpenLibrary)),
          );
        },
      ),
    );
  }
}

Widget _emptyCard(VoidCallback onOpenLibrary) {
  return Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      mouseCursor: SystemMouseCursors.click,
      onTap: onOpenLibrary,
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.search, size: 22, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                tr('queue.empty'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 22 / 15,
                ),
              ),
              Text(
                tr('queue.empty_hint'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 22 / 15,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
