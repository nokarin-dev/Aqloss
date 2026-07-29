import 'package:flutter/material.dart';

class M3SearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const M3SearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<M3SearchField> createState() => _M3SearchFieldState();
}

class _M3SearchFieldState extends State<M3SearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SearchBar(
      controller: widget.controller,
      hintText: widget.hintText,
      leading: const Icon(Icons.search_rounded),
      trailing: widget.controller.text.isNotEmpty
          ? [
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  widget.onClear();
                  setState(() {});
                },
              ),
            ]
          : null,
      onChanged: widget.onChanged,
      elevation: WidgetStateProperty.all(0),
      backgroundColor: WidgetStateProperty.all(
        theme.colorScheme.surfaceContainerHighest,
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}
