import 'package:flutter/material.dart';

class CustomSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double>? onChanged;
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

  void _handleTapDown(TapDownDetails d, double width) {
    if (widget.onChanged == null) return;
    final v = (d.localPosition.dx / width).clamp(0.0, 1.0);
    widget.onChanged!(v);
  }

  void _handleDrag(DragUpdateDetails d, double width) {
    if (widget.onChanged == null) return;
    final v = (d.localPosition.dx / width).clamp(0.0, 1.0);
    widget.onChanged!(v);
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
          onHorizontalDragStart: (_) => setState(() => _dragging = true),
          onHorizontalDragUpdate: (d) => _handleDrag(d, w),
          onHorizontalDragEnd: (_) => setState(() => _dragging = false),
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
    final trackY = cy;
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

    // inactive track
    canvas.drawLine(Offset(left, trackY), Offset(right, trackY), trackPaint);
    // active track
    if (fillX > left) {
      canvas.drawLine(Offset(left, trackY), Offset(fillX, trackY), fillPaint);
    }

    // thumb
    if (showThumb) {
      canvas.drawCircle(
        Offset(fillX, trackY),
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
