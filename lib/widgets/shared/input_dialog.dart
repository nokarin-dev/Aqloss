import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/util/search_focus_tracker.dart';
import 'package:flutter/material.dart';

class InputDialog extends StatefulWidget {
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
  State<InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<InputDialog> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    SearchFocusTracker.instance.register(_focusNode);
  }

  @override
  void dispose() {
    SearchFocusTracker.instance.unregister(_focusNode);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    final field = TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      autofocus: true,
      style: TextStyle(color: onSurface, fontSize: 14),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.24)),
        filled: true,
        fillColor: isM3 ? cs.onSurface.withValues(alpha: 0.04) : aq.indicator,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isM3 ? cs.onSurface.withValues(alpha: 0.08) : aq.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isM3 ? cs.onSurface.withValues(alpha: 0.08) : aq.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: onSurface.withValues(alpha: 0.22)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 11,
        ),
      ),
      onSubmitted: (_) => Navigator.pop(context, widget.controller.text),
    );

    final actions = [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(
          'Cancel',
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.32),
            fontSize: 13,
          ),
        ),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, widget.controller.text),
        child: Text(
          widget.confirmLabel,
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.68),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ];

    if (isM3) {
      return AlertDialog(
        title: Text(
          widget.title,
          style: TextStyle(
            color: onSurface,
            fontWeight: FontWeight.w400,
            fontSize: 15,
          ),
        ),
        content: field,
        actions: actions,
      );
    }

    return Dialog(
      backgroundColor: aq.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                color: aq.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 14),
            field,
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ),
      ),
    );
  }
}
