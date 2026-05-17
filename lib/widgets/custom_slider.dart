import 'package:flutter/material.dart';

class CustomSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double trackHeight;
  final double thumbRadius;
  final bool showThumb;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;

  const CustomSlider({
    super.key,
    required this.value,
    this.onChanged,
    this.onChangeEnd,
    this.trackHeight = 2,
    this.thumbRadius = 5,
    this.showThumb = true,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
  });

  @override
  State<CustomSlider> createState() => _CustomSliderState();
}

class _CustomSliderState extends State<CustomSlider> {
  bool _dragging = false;
  double _dragValue = 0.0;

  void _handleTapDown(TapDownDetails d, double width) {
    if (widget.onChanged == null) return;
    final v = (d.localPosition.dx / width).clamp(0.0, 1.0);
    widget.onChanged!(v);
    widget.onChangeEnd?.call(v);
  }

  void _handleDragStart(DragStartDetails d, double width) {
    _dragValue = (d.localPosition.dx / width).clamp(0.0, 1.0);
    setState(() => _dragging = true);
  }

  void _handleDragUpdate(DragUpdateDetails d, double width) {
    if (widget.onChanged == null) return;
    final v = (d.localPosition.dx / width).clamp(0.0, 1.0);
    _dragValue = v;
    widget.onChanged!(v);
  }

  void _handleDragEnd(DragEndDetails _) {
    setState(() => _dragging = false);
    widget.onChangeEnd?.call(_dragValue);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = widget.activeColor ?? cs.onSurface;
    final inactive =
        widget.inactiveColor ?? cs.onSurface.withValues(alpha: 0.12);
    final thumb = widget.thumbColor ?? cs.onSurface;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _handleTapDown(d, w),
          onHorizontalDragStart: (d) => _handleDragStart(d, w),
          onHorizontalDragUpdate: (d) => _handleDragUpdate(d, w),
          onHorizontalDragEnd: _handleDragEnd,
          child: SizedBox(
            height: widget.thumbRadius * 2 + 8,
            child: CustomPaint(
              size: Size(w, widget.thumbRadius * 2 + 8),
              painter: _SliderPainter(
                value: widget.value,
                trackHeight: widget.trackHeight,
                thumbRadius: _dragging
                    ? widget.thumbRadius + 1.5
                    : widget.thumbRadius,
                showThumb: widget.showThumb,
                activeColor: active,
                inactiveColor: inactive,
                thumbColor: thumb,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SliderPainter extends CustomPainter {
  final double value, trackHeight, thumbRadius;
  final bool showThumb;
  final Color activeColor, inactiveColor, thumbColor;

  _SliderPainter({
    required this.value,
    required this.trackHeight,
    required this.thumbRadius,
    required this.showThumb,
    required this.activeColor,
    required this.inactiveColor,
    required this.thumbColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final left = thumbRadius;
    final right = size.width - thumbRadius;
    final trackW = right - left;
    final fillX = left + trackW * value.clamp(0.0, 1.0);

    final trackPaint = Paint()
      ..color = inactiveColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = trackHeight
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = activeColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = trackHeight
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(left, cy), Offset(right, cy), trackPaint);
    if (fillX > left) {
      canvas.drawLine(Offset(left, cy), Offset(fillX, cy), fillPaint);
    }
    if (showThumb) {
      canvas.drawCircle(
        Offset(fillX, cy),
        thumbRadius,
        Paint()..color = thumbColor,
      );
    }
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.value != value ||
      old.thumbRadius != thumbRadius ||
      old.activeColor != activeColor;
}
