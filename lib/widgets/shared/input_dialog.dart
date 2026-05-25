import 'package:flutter/material.dart';

class InputDialog extends StatelessWidget {
  final String title;
  final String hint;
  final String confirmLabel;
  final TextEditingController controller;

  const InputDialog({
    super.key,
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: TextStyle(
          color: cs.onSurface,
          fontWeight: FontWeight.w400,
          fontSize: 15,
        ),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: TextStyle(color: cs.onSurface, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.24)),
          filled: true,
          fillColor: cs.onSurface.withValues(alpha: 0.04),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: cs.onSurface.withValues(alpha: 0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: cs.onSurface.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: cs.onSurface.withValues(alpha: 0.22)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 11,
          ),
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.32),
              fontSize: 13,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.68),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
