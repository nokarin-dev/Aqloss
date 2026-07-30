import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class InstallerTitleBar extends StatelessWidget {
  const InstallerTitleBar({
    super.key,
    required this.onClose,
    this.title = 'Aqloss Installer',
  });

  final VoidCallback onClose;
  final String title;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 36,
        color: const Color(0xFF0A0A0B),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF5A5A6A),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            _CloseButton(onTap: onClose),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? Colors.white : const Color(0xFF4A4A5A);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFE04040) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: CustomPaint(
            size: const Size(10, 10),
            painter: _CloseXPainter(color: color),
          ),
        ),
      ),
    );
  }
}

class _CloseXPainter extends CustomPainter {
  _CloseXPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _CloseXPainter oldDelegate) =>
      oldDelegate.color != color;
}
