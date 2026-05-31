import 'package:flutter/widgets.dart';

class SearchFocusTracker {
  SearchFocusTracker._();
  static final instance = SearchFocusTracker._();

  final _nodes = <FocusNode>{};
  bool _capturingShortcut = false;

  void register(FocusNode node) => _nodes.add(node);
  void unregister(FocusNode node) => _nodes.remove(node);

  void setCapturingShortcut(bool v) => _capturingShortcut = v;

  bool get hasFocus => _capturingShortcut || _nodes.any((n) => n.hasFocus);
}
