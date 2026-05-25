import 'package:flutter/material.dart';
import 'package:aqloss/util/search_focus_tracker.dart';

class SearchBox extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const SearchBox({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    SearchFocusTracker.instance.register(_focusNode);
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    SearchFocusTracker.instance.unregister(_focusNode);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _focusNode.requestFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 36,
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: cs.onSurface.withValues(
              alpha: _focusNode.hasFocus ? 0.18 : 0.08,
            ),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Icon(
              Icons.search_rounded,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.28),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: EditableText(
                controller: widget.controller,
                focusNode: _focusNode,
                onChanged: widget.onChanged,
                style: TextStyle(color: cs.onSurface, fontSize: 13),
                cursorColor: cs.onSurface.withValues(alpha: 0.60),
                backgroundCursorColor: Colors.transparent,
                cursorWidth: 1.2,
                cursorRadius: const Radius.circular(1),
                selectionColor: cs.onSurface.withValues(alpha: 0.15),
              ),
            ),
            if (widget.controller.text.isNotEmpty)
              GestureDetector(
                onTap: widget.onClear,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: cs.onSurface.withValues(alpha: 0.28),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
