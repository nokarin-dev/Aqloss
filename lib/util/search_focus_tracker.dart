import 'package:flutter/widgets.dart';

class SearchFocusTracker {
  SearchFocusTracker._();
  static final instance = SearchFocusTracker._();

  final _nodes = <FocusNode>{};

  void register(FocusNode node) {
    _nodes.add(node);
  }

  void unregister(FocusNode node) {
    _nodes.remove(node);
  }

  bool get hasFocus => _nodes.any((n) => n.hasFocus);
}
