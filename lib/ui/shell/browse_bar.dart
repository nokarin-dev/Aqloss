import 'package:aqloss/l10n/l10n.dart';
import 'package:aqloss/ui/shell/glass.dart';
import 'package:aqloss/ui/shell/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const _items = <(HomeBrowse, IconData, String)>[
  (HomeBrowse.library, CupertinoIcons.music_albums, 'header.library'),
  (
    HomeBrowse.nowPlaying,
    CupertinoIcons.play_circle_fill,
    'header.now_playing',
  ),
  (HomeBrowse.albums, CupertinoIcons.square_stack_fill, 'header.albums'),
];

const _slot = 30.0;
const _pad = 12.0;
const _icon = 14.0;
const _gap = 6.0;
const _layoutGap = 4.0;
const _fieldWidth = 220.0;
const _layoutWidth = _layoutGap + (_pad * 2 + _icon) * 2;
const _labelStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);

final _browseKeys = <HomeBrowse, GlobalKey>{
  for (final item in _items) item.$1: GlobalKey(),
};

final _layoutKeys = <LibraryLayout, GlobalKey>{
  LibraryLayout.grid: GlobalKey(),
  LibraryLayout.details: GlobalKey(),
};

class BrowseBar extends StatefulWidget {
  final HomeBrowse browse;
  final bool searching;
  final TextEditingController query;
  final FocusNode focus;
  final String hint;
  final ValueChanged<HomeBrowse> onBrowse;
  final VoidCallback onOpenSearch;
  final VoidCallback onCloseSearch;
  final ValueChanged<String> onQuery;
  final LibraryLayout layout;
  final ValueChanged<LibraryLayout> onLayout;

  const BrowseBar({
    super.key,
    required this.browse,
    required this.searching,
    required this.query,
    required this.focus,
    required this.hint,
    required this.onBrowse,
    required this.onOpenSearch,
    required this.onCloseSearch,
    required this.onQuery,
    required this.layout,
    required this.onLayout,
  });

  @override
  State<BrowseBar> createState() => _BrowseBarState();
}

class _BrowseBarState extends State<BrowseBar> with TickerProviderStateMixin {
  late final AnimationController _tools;
  late final AnimationController _query;
  late final AnimationController _labels;
  var _placed = false;

  @override
  void initState() {
    super.initState();
    _tools = AnimationController(
      vsync: this,
      duration: motionDuration,
      value: widget.browse == HomeBrowse.nowPlaying ? 0 : 1,
    );
    _query = AnimationController(
      vsync: this,
      duration: motionDuration,
      value: widget.searching ? 1 : 0,
    );
    _labels = AnimationController(
      vsync: this,
      duration: motionDuration,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(BrowseBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.browse != widget.browse) {
      _aim(_tools, widget.browse == HomeBrowse.nowPlaying ? 0 : 1);
    }
    if (oldWidget.searching != widget.searching) {
      _aim(_query, widget.searching ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _tools.dispose();
    _query.dispose();
    _labels.dispose();
    super.dispose();
  }

  void _aim(AnimationController controller, double next) {
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.value = next;
      return;
    }
    if (next == 1) {
      if (controller.value != 1) controller.forward();
      return;
    }
    if (controller.value != 0) controller.reverse();
  }

  void _fitLabels(bool show) {
    final next = show ? 1.0 : 0.0;
    if (!_placed) {
      _placed = true;
      _labels.value = next;
      return;
    }
    if ((_labels.value - next).abs() < 0.001 ||
        (_labels.status == AnimationStatus.forward && next == 1) ||
        (_labels.status == AnimationStatus.reverse && next == 0)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _aim(_labels, next);
    });
  }

  double _textWidth(BuildContext context, String text) {
    final style = DefaultTextStyle.of(context).style.merge(_labelStyle);
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  double _segmentsWidth(BuildContext context, double labels) {
    var width = 0.0;
    for (final item in _items) {
      width +=
          _pad * 2 + _icon + labels * (_gap + _textWidth(context, tr(item.$3)));
    }
    return width;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final openSegments = _segmentsWidth(context, 1);
        final widest =
            6 +
            _slot +
            (openSegments > _fieldWidth ? openSegments : _fieldWidth) +
            _layoutWidth;
        _fitLabels(widest <= constraints.maxWidth);
        return AnimatedBuilder(
          animation: Listenable.merge([_tools, _query, _labels]),
          builder: (context, _) {
            final tools = motionCurve.transform(_tools.value);
            final query = motionCurve.transform(_query.value);
            final labels = motionCurve.transform(_labels.value);
            final toolWidth = tools * (_slot + _layoutWidth);
            final room = (constraints.maxWidth - 6 - toolWidth).clamp(
              80.0,
              _fieldWidth,
            );
            final field = room < _fieldWidth ? room : _fieldWidth;
            final segments = _segmentsWidth(context, labels);
            final middle = segments + (field - segments) * query;
            final showField = widget.searching || query > 0;
            return SizedBox(
              height: 36,
              child: Align(
                alignment: Alignment.topCenter,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ShellLens(
                        radius: 999,
                        padding: EdgeInsets.zero,
                        child: SizedBox.expand(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Clip(
                            factor: tools,
                            child: _SearchButton(
                              open: widget.searching,
                              onPressed: widget.searching
                                  ? widget.onCloseSearch
                                  : widget.onOpenSearch,
                            ),
                          ),
                          SizedBox(
                            width: middle,
                            height: _slot,
                            child: ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.centerLeft,
                                minWidth: 0,
                                maxWidth: double.infinity,
                                minHeight: _slot,
                                maxHeight: _slot,
                                child: Stack(
                                  alignment: Alignment.centerLeft,
                                  clipBehavior: Clip.none,
                                  children: [
                                    IgnorePointer(
                                      ignoring: query > 0.5,
                                      child: Opacity(
                                        opacity: 1 - query,
                                        child: MovingFill(
                                          selectedKey:
                                              _browseKeys[widget.browse]!,
                                          color: const Color(0x24FFFFFF),
                                          radius: 999,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              for (final item in _items)
                                                _Segment(
                                                  key: _browseKeys[item.$1],
                                                  icon: item.$2,
                                                  label: tr(item.$3),
                                                  labels: labels,
                                                  selected:
                                                      widget.browse == item.$1,
                                                  onTap: () =>
                                                      widget.onBrowse(item.$1),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (showField)
                                      IgnorePointer(
                                        ignoring: query < 0.5,
                                        child: Opacity(
                                          opacity: query,
                                          child: SizedBox(
                                            width: field,
                                            child: _QueryBox(
                                              controller: widget.query,
                                              focus: widget.focus,
                                              hint: widget.hint,
                                              onChanged: widget.onQuery,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          _Clip(
                            factor: tools,
                            child: _LayoutViews(
                              layout: widget.layout,
                              onLayout: widget.onLayout,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Clip extends StatelessWidget {
  final double factor;
  final Widget child;

  const _Clip({required this.factor, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: factor <= 0 ? 0 : factor,
        child: child,
      ),
    );
  }
}

class _LayoutViews extends StatelessWidget {
  final LibraryLayout layout;
  final ValueChanged<LibraryLayout> onLayout;

  const _LayoutViews({required this.layout, required this.onLayout});

  @override
  Widget build(BuildContext context) {
    return MovingFill(
      selectedKey: _layoutKeys[layout]!,
      color: const Color(0x24FFFFFF),
      radius: 999,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: _layoutGap),
          _ViewChoice(
            key: _layoutKeys[LibraryLayout.grid],
            selected: layout == LibraryLayout.grid,
            tooltip: tr('header.grid'),
            onTap: () => onLayout(LibraryLayout.grid),
            child: const Icon(CupertinoIcons.square_grid_2x2, size: _icon),
          ),
          _ViewChoice(
            key: _layoutKeys[LibraryLayout.details],
            selected: layout == LibraryLayout.details,
            tooltip: tr('header.details'),
            onTap: () => onLayout(LibraryLayout.details),
            child: const Icon(CupertinoIcons.list_bullet, size: _icon),
          ),
        ],
      ),
    );
  }
}

class _ViewChoice extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final String? tooltip;

  const _ViewChoice({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : textMuted;
    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: _slot,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _pad),
            child: IconTheme(
              data: IconThemeData(color: color, size: _icon),
              child: child,
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _SearchButton extends StatelessWidget {
  final bool open;
  final VoidCallback onPressed;

  const _SearchButton({required this.open, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _slot,
      height: _slot,
      child: IconButton(
        tooltip: tr(open ? 'sidebar.dismiss' : 'sidebar.search'),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: _slot, height: _slot),
        onPressed: onPressed,
        icon: Icon(
          CupertinoIcons.search,
          size: 15,
          color: open ? CupertinoColors.white : textMuted,
        ),
      ),
    );
  }
}

class _QueryBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final String hint;
  final ValueChanged<String> onChanged;

  const _QueryBox({
    required this.controller,
    required this.focus,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _slot,
      child: CupertinoTextField(
        controller: controller,
        focusNode: focus,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        style: const TextStyle(color: CupertinoColors.white, fontSize: 13),
        placeholder: hint,
        placeholderStyle: const TextStyle(color: textMuted, fontSize: 13),
        decoration: const BoxDecoration(),
        cursorColor: CupertinoColors.white,
        onChanged: onChanged,
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final IconData icon;
  final String label;
  final double labels;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    super.key,
    required this.icon,
    required this.label,
    required this.labels,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : textMuted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: _slot,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _pad),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: _icon, color: color),
                _Clip(
                  factor: labels,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: _gap),
                      Text(label, style: _labelStyle.copyWith(color: color)),
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
