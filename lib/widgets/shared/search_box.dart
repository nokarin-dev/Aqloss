import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/util/search_focus_tracker.dart';
import 'package:flutter/material.dart';

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
    if (context.isMaterial3Ui) {
      return TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: 'Search',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: widget.onClear,
                )
              : null,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    final aq = context.aq;
    return GestureDetector(
      onTap: _focusNode.requestFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 36,
        decoration: BoxDecoration(
          color: aq.indicator,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: aq.onSurface.withValues(
              alpha: _focusNode.hasFocus ? 0.18 : 0.08,
            ),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Icon(Icons.search_rounded, size: 16, color: aq.onSurfaceMuted),
            const SizedBox(width: 8),
            Expanded(
              child: EditableText(
                controller: widget.controller,
                focusNode: _focusNode,
                onChanged: widget.onChanged,
                style: TextStyle(color: aq.onSurface, fontSize: 13),
                cursorColor: aq.onSurface.withValues(alpha: 0.60),
                backgroundCursorColor: Colors.transparent,
                cursorWidth: 1.2,
                cursorRadius: const Radius.circular(1),
                selectionColor: aq.onSurface.withValues(alpha: 0.15),
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
                    color: aq.onSurfaceMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
