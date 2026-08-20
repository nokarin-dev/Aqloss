import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/legacy.dart';

const _channel = MethodChannel('xyz.nokarin.aqloss/window_chrome');

// Linux tiled/maximized: no CSD inset
final windowFlushProvider = StateProvider<bool>((ref) => false);

void bindWindowChromeChannel(void Function(bool flush) onFlush) {
  if (!Platform.isLinux) return;
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'setFlush') {
      onFlush(call.arguments == true);
    }
  });
  _channel
      .invokeMethod<bool>('getFlush')
      .then((value) {
        if (value != null) onFlush(value);
      })
      .catchError((_) {});
}
