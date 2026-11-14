import 'package:flutter/material.dart';

const textMuted = Color(0xFFA3A3A3);
const playGreen = Color(0xFF00FF22);
const motionDuration = Duration(milliseconds: 280);
const motionCurve = Curves.easeInOutCubic;

// Card height plus its bottom inset, so the last row clears the player.
const double playerClearance = 128;

Duration motionOf(BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context)) return Duration.zero;
  return motionDuration;
}

class Crossfade extends StatelessWidget {
  final Widget child;

  const Crossfade({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: motionOf(context),
      switchInCurve: motionCurve,
      switchOutCurve: motionCurve,
      layoutBuilder: (current, previous) {
        return Stack(
          fit: StackFit.expand,
          children: [
            for (final old in previous) IgnorePointer(child: old),
            ?current,
          ],
        );
      },
      child: RepaintBoundary(key: child.key, child: child),
    );
  }
}

// One fill that travels between keyed children. Same color, same radius.
class MovingFill extends StatefulWidget {
  final GlobalKey selectedKey;
  final Color color;
  final double radius;
  final Widget child;

  const MovingFill({
    super.key,
    required this.selectedKey,
    required this.color,
    required this.radius,
    required this.child,
  });

  @override
  State<MovingFill> createState() => _MovingFillState();
}

class _MovingFillState extends State<MovingFill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _move;
  Rect? _from;
  Rect? _cached;
  Rect? _shown;
  bool _waiting = false;

  @override
  void initState() {
    super.initState();
    _move = AnimationController(
      vsync: this,
      duration: motionDuration,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(MovingFill old) {
    super.didUpdateWidget(old);
    if (old.selectedKey == widget.selectedKey) return;
    _from = _shown ?? _box(old.selectedKey) ?? _cached;
    _move.duration = motionOf(context);
    _move.forward(from: 0);
  }

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  Rect? _box(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    final parent = context.findRenderObject();
    if (box is! RenderBox || parent is! RenderBox) return null;
    if (!box.attached || !parent.attached || !box.hasSize || !parent.hasSize) {
      return null;
    }
    return parent.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
  }

  Rect? _paint() {
    final live = _box(widget.selectedKey);
    if (live != null) _cached = live;
    final target = live ?? _cached;
    if (target == null) return _shown = null;
    if (_from == null || _move.value >= 1) return _shown = target;
    return _shown = Rect.lerp(
      _from,
      target,
      motionCurve.transform(_move.value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _move,
      builder: (context, child) {
        final rect = _paint();
        if (rect == null && !_waiting) {
          _waiting = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _waiting = false;
            if (mounted) setState(() {});
          });
        }
        return Stack(
          children: [
            if (rect != null)
              Positioned.fromRect(
                rect: rect,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(widget.radius),
                    ),
                  ),
                ),
              ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

class IconFade extends StatelessWidget {
  final Widget child;

  const IconFade({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: motionOf(context),
      switchInCurve: motionCurve,
      switchOutCurve: motionCurve,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

enum NavDest { home, playlists, artists, history, queue, settings }

enum HomeBrowse { library, nowPlaying, albums }

enum LibraryLayout { grid, details }

class EmptyNote extends StatelessWidget {
  final String text;

  const EmptyNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: const TextStyle(color: textMuted, fontSize: 15)),
    );
  }
}
