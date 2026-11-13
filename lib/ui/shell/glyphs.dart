import 'package:flutter/material.dart';

enum ShellGlyph {
  moon,
  shuffle,
  previous,
  play,
  pause,
  next,
  repeat,
  repeatOne,
  volume,
  volumeMute,
}

class ShellIcon extends StatelessWidget {
  final ShellGlyph glyph;
  final Color color;
  final double size;

  const ShellIcon({
    super.key,
    required this.glyph,
    required this.color,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(glyph, color),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final ShellGlyph glyph;
  final Color color;

  const _GlyphPainter(this.glyph, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.scale(size.width / 24);
    switch (glyph) {
      case ShellGlyph.moon:
        _moon(canvas, fill);
      case ShellGlyph.shuffle:
        _shuffle(canvas, stroke);
      case ShellGlyph.previous:
        _skip(canvas, stroke);
      case ShellGlyph.next:
        canvas.translate(24, 0);
        canvas.scale(-1, 1);
        _skip(canvas, stroke);
      case ShellGlyph.play:
        _disc(canvas, stroke);
        canvas.drawPath(_triangle(), fill);
      case ShellGlyph.pause:
        _disc(canvas, stroke);
        canvas.drawRRect(_bar(9.1), fill);
        canvas.drawRRect(_bar(13.1), fill);
      case ShellGlyph.repeat:
        _repeat(canvas, stroke);
      case ShellGlyph.repeatOne:
        _repeat(canvas, stroke);
        _one(canvas, stroke);
      case ShellGlyph.volume:
        _speaker(canvas, stroke, waves: true);
      case ShellGlyph.volumeMute:
        _speaker(canvas, stroke, waves: false);
    }
    canvas.restore();
  }

  void _moon(Canvas canvas, Paint fill) {
    final path = Path()..fillType = PathFillType.evenOdd;
    path.addOval(Rect.fromCircle(center: const Offset(11, 12), radius: 6.5));
    path.addOval(
      Rect.fromCircle(center: const Offset(13.8, 10.2), radius: 5.3),
    );
    canvas.drawPath(path, fill);
  }

  void _shuffle(Canvas canvas, Paint stroke) {
    _curve(canvas, stroke, const Offset(4, 8), const Offset(20, 16), true);
    _curve(canvas, stroke, const Offset(4, 16), const Offset(20, 8), false);
  }

  void _curve(Canvas canvas, Paint stroke, Offset from, Offset to, bool down) {
    final bend = down ? 16.0 : 8.0;
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(9, from.dy, 14, bend, to.dx - 1, to.dy);
    canvas.drawPath(path, stroke);
    _head(canvas, stroke, Offset(to.dx - 0.4, to.dy), const Offset(1, 0));
  }

  void _skip(Canvas canvas, Paint stroke) {
    canvas.drawLine(const Offset(6.5, 7), const Offset(6.5, 17), stroke);
    canvas.drawPath(
      Path()
        ..moveTo(17.5, 7)
        ..lineTo(10.2, 12)
        ..lineTo(17.5, 17),
      stroke,
    );
  }

  void _disc(Canvas canvas, Paint stroke) {
    canvas.drawCircle(const Offset(12, 12), 8.6, stroke);
  }

  Path _triangle() {
    return Path()
      ..moveTo(10.3, 8.5)
      ..lineTo(16.2, 12)
      ..lineTo(10.3, 15.5)
      ..close();
  }

  RRect _bar(double left) {
    return RRect.fromRectAndRadius(
      Rect.fromLTWH(left, 8.3, 1.8, 7.4),
      const Radius.circular(0.6),
    );
  }

  void _repeat(Canvas canvas, Paint stroke) {
    final path = Path()
      ..moveTo(16.2, 8)
      ..lineTo(8.4, 8)
      ..arcToPoint(
        const Offset(8.4, 16),
        radius: const Radius.circular(3.6),
        clockwise: false,
      )
      ..lineTo(15.2, 16)
      ..arcToPoint(
        const Offset(16.6, 11.2),
        radius: const Radius.circular(3.6),
        clockwise: false,
      );
    canvas.drawPath(path, stroke);
    _head(canvas, stroke, const Offset(16.8, 8), const Offset(1, 0));
  }

  void _speaker(Canvas canvas, Paint stroke, {required bool waves}) {
    final body = Path()
      ..moveTo(3.5, 9.5)
      ..lineTo(8, 9.5)
      ..lineTo(13, 5.5)
      ..lineTo(13, 18.5)
      ..lineTo(8, 14.5)
      ..lineTo(3.5, 14.5)
      ..close();
    canvas.drawPath(body, stroke);
    if (!waves) {
      canvas.drawLine(const Offset(16, 8.5), const Offset(21, 15.5), stroke);
      canvas.drawLine(const Offset(21, 8.5), const Offset(16, 15.5), stroke);
      return;
    }
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(13, 12), radius: 4.2),
      -0.9,
      1.8,
      false,
      stroke,
    );
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(13, 12), radius: 7.2),
      -0.75,
      1.5,
      false,
      stroke,
    );
  }

  void _one(Canvas canvas, Paint stroke) {
    canvas.drawLine(const Offset(12, 10.4), const Offset(12, 14.2), stroke);
    canvas.drawLine(const Offset(10.7, 11.4), const Offset(12, 10.4), stroke);
  }

  void _head(Canvas canvas, Paint stroke, Offset tip, Offset dir) {
    final unit = dir / dir.distance;
    final side = Offset(-unit.dy, unit.dx);
    final base = tip - unit * 4;
    canvas.drawLine(tip, base + side * 2.5, stroke);
    canvas.drawLine(tip, base - side * 2.5, stroke);
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) {
    return old.glyph != glyph || old.color != color;
  }
}
