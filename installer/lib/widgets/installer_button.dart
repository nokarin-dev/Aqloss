import 'package:flutter/material.dart';

class InstallerButton extends StatefulWidget {
  const InstallerButton({
    super.key,
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final VoidCallback? onTap;

  @override
  State<InstallerButton> createState() => _InstallerButtonState();
}

class _InstallerButtonState extends State<InstallerButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _disabled => widget.onTap == null;

  @override
  Widget build(BuildContext context) {
    final bg = widget.primary
        ? _disabled
              ? const Color(0xFF2A3050)
              : _pressed
              ? const Color(0xFF3A70E0)
              : _hovered
              ? const Color(0xFF5A9EFF)
              : const Color(0xFF4F8EF7)
        : _pressed
        ? const Color(0xFF252530)
        : _hovered
        ? const Color(0xFF1E1E2A)
        : Colors.transparent;

    final border = widget.primary
        ? BorderSide.none
        : BorderSide(
            color: _hovered ? const Color(0xFF3A3A4A) : const Color(0xFF2A2A35),
          );

    final fg = widget.primary
        ? _disabled
              ? const Color(0xFF4A5880)
              : Colors.white
        : const Color(0xFFAAAAAA);

    return MouseRegion(
      cursor: _disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: _disabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: _disabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: _disabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.fromBorderSide(border),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}
