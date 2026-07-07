import 'package:aqloss/widgets/q_toast.dart';
import 'package:flutter/material.dart';

class PluginToastService {
  PluginToastService._();
  static final PluginToastService instance = PluginToastService._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  void show(String message) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    QToast.show(ctx, message);
  }
}
