import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/widgets/shared/mini_album_art.dart';
import 'package:aqloss/widgets/shared/track_context_menu.dart';
import 'package:aqloss/widgets/ui/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final queuePanelOpenProvider = StateProvider<bool>((ref) => false);

class QueuePanel extends ConsumerWidget {
  const QueuePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(queuePanelOpenProvider);
    final narrow = MediaQuery.sizeOf(context).width < 1100;
    final panelW = narrow ? 220.0 : 272.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      width: open ? panelW : 0.0,
      child: open ? const _QueuePanelContent() : const SizedBox.shrink(),
    );
  }
}

class _QueuePanelContent extends ConsumerWidget {
  const _QueuePanelContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    Color onSurfaceAlpha(double a) => onSurface.withValues(alpha: a);
    final player = ref.watch(playerProvider);
    final queue = player.queue;
    final curIdx = player.queueIndex;
    final notifier = ref.read(playerProvider.notifier);

    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
          child: Row(
            children: [
              Icon(
                Icons.queue_music_rounded,
                size: 14,
                color: onSurfaceAlpha(0.30),
              ),
              const SizedBox(width: 8),
              Text(
                'Queue',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: onSurfaceAlpha(0.80),
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Text(
                '${queue.length} track${queue.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 10.5, color: onSurfaceAlpha(0.26)),
              ),
              const SizedBox(width: 8),
              _CloseBtn(
                onTap: () =>
                    ref.read(queuePanelOpenProvider.notifier).state = false,
              ),
            ],
          ),
        ),
        if (isM3) const UiDivider(),
        Expanded(
          child: queue.isEmpty
              ? _EmptyQueue()
              : _QueueList(queue: queue, curIdx: curIdx, notifier: notifier),
        ),
      ],
    );

    if (isM3) {
      return SizedBox.expand(
        child: UiSurface(borderRadius: BorderRadius.zero, child: panel),
      );
    }

    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: onSurfaceAlpha(0.055))),
        ),
        child: panel,
      ),
    );
  }
}

class _QueueList extends StatefulWidget {
  final List<Track> queue;
  final int curIdx;
  final PlayerNotifier notifier;

  const _QueueList({
    required this.queue,
    required this.curIdx,
    required this.notifier,
  });

  @override
  State<_QueueList> createState() => _QueueListState();
}

class _QueueListState extends State<_QueueList> {
  final _scroll = ScrollController();
  static const _kItemH = 52.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void didUpdateWidget(_QueueList old) {
    super.didUpdateWidget(old);
    if (old.curIdx != widget.curIdx) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToCurrent() {
    if (!_scroll.hasClients || widget.curIdx < 0) return;
    final viewportH = _scroll.position.viewportDimension;
    final centered = widget.curIdx * _kItemH - viewportH / 2 + _kItemH / 2;
    final target = centered.clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      scrollController: _scroll,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: widget.queue.length,
      proxyDecorator: (child, index, animation) =>
          Material(color: Colors.transparent, child: child),
      onReorder: (oldIndex, newIndex) =>
          widget.notifier.reorderQueue(oldIndex, newIndex),
      itemBuilder: (context, i) {
        final track = widget.queue[i];
        final isCur = i == widget.curIdx;
        final isPast = i < widget.curIdx;

        return _QueueTile(
          key: ValueKey('q_${i}_${track.path}'),
          track: track,
          isCurrent: isCur,
          isPast: isPast,
          onTap: () => widget.notifier.jumpToQueue(i),
          onRemove: () => widget.notifier.removeFromQueue(i),
        );
      },
    );
  }
}

// Individual queue tile
class _QueueTile extends ConsumerStatefulWidget {
  final Track track;
  final bool isCurrent;
  final bool isPast;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _QueueTile({
    super.key,
    required this.track,
    required this.isCurrent,
    required this.isPast,
    required this.onTap,
    required this.onRemove,
  });

  @override
  ConsumerState<_QueueTile> createState() => _QueueTileState();
}

class _QueueTileState extends ConsumerState<_QueueTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    Color onSurfaceAlpha(double a) => onSurface.withValues(alpha: a);
    final alpha = widget.isPast ? 0.40 : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: (d) => showTrackContextMenu(
          context: context,
          globalPosition: d.globalPosition,
          track: widget.track,
          ref: ref,
        ),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: widget.isCurrent
              ? onSurfaceAlpha(0.05)
              : _hovered
              ? onSurfaceAlpha(0.03)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Opacity(
            opacity: alpha,
            child: Row(
              children: [
                MiniAlbumArt(
                  path: widget.track.path,
                  size: 32,
                  playing: widget.isCurrent,
                  radius: 4,
                ),
                const SizedBox(width: 9),

                // Title + artist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.track.displayTitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: widget.isCurrent
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: widget.isCurrent
                              ? onSurface
                              : onSurfaceAlpha(0.78),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.track.displayArtist,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: onSurfaceAlpha(0.32),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Remove button
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 110),
                  opacity: _hovered ? 1.0 : 0.0,
                  child: GestureDetector(
                    onTap: widget.onRemove,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.close_rounded,
                        size: 12,
                        color: cs.onSurface.withValues(alpha: 0.32),
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

// Empty state
class _EmptyQueue extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    Color onSurfaceAlpha(double a) => onSurface.withValues(alpha: a);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 26,
            color: onSurfaceAlpha(0.10),
          ),
          const SizedBox(height: 10),
          Text(
            'Queue is empty',
            style: TextStyle(fontSize: 13, color: onSurfaceAlpha(0.26)),
          ),
        ],
      ),
    );
  }
}

// Close button
class _CloseBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _CloseBtn({required this.onTap});

  @override
  State<_CloseBtn> createState() => _CloseBtnState();
}

class _CloseBtnState extends State<_CloseBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    Color onSurfaceAlpha(double a) => onSurface.withValues(alpha: a);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: _hovered ? onSurfaceAlpha(0.07) : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(
            Icons.close_rounded,
            size: 12,
            color: onSurfaceAlpha(0.34),
          ),
        ),
      ),
    );
  }
}
