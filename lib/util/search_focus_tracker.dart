import 'package:flutter/widgets.dart';

class SearchFocusTracker {
  SearchFocusTracker._();
  static final instance = SearchFocusTracker._();

  final _nodes = <FocusNode>{};
  bool _capturingShortcut = false;

  void register(FocusNode node) => _nodes.add(node);
  void unregister(FocusNode node) => _nodes.remove(node);

  void setCapturingShortcut(bool v) => _capturingShortcut = v;

  bool get hasFocus =>
      _capturingShortcut || _nodes.any((n) => n.hasFocus) || _editingText;

  bool get _editingText {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorStateOfType<EditableTextState>() != null;
  }
}
