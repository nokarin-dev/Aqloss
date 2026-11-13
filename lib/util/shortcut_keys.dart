import 'package:flutter/services.dart';

// True while a settings row is recording a new chord
bool shortcutCapture = false;

// Chord string stored for a shortcut
String? shortcutChord(KeyEvent event) {
  final ctrl =
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;
  final shift = HardwareKeyboard.instance.isShiftPressed;
  final key = event.logicalKey;

  if (key == LogicalKeyboardKey.control ||
      key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight ||
      key == LogicalKeyboardKey.meta ||
      key == LogicalKeyboardKey.shift ||
      key == LogicalKeyboardKey.alt) {
    return null;
  }

  final keyName = ctrl
      ? (_physicalKeyName(event.physicalKey) ?? _logicalKeyName(key))
      : _logicalKeyName(key);
  if (keyName == null) return null;

  final parts = <String>[if (ctrl) 'Ctrl', if (shift) 'Shift', keyName];
  return parts.join('+');
}

String? _physicalKeyName(PhysicalKeyboardKey physical) {
  final label = physical.debugName;
  if (label == null) return null;
  if (label.startsWith('Key ')) return label.substring(4).toUpperCase();
  if (label.startsWith('Digit ')) return label.substring(6);
  const named = <String, String>{
    'Space': 'Space',
    'Arrow Left': 'ArrowLeft',
    'Arrow Right': 'ArrowRight',
    'Arrow Up': 'ArrowUp',
    'Arrow Down': 'ArrowDown',
    'Enter': 'Enter',
    'Numpad Enter': 'Enter',
    'Tab': 'Tab',
    'Backspace': 'Backspace',
    'Delete': 'Delete',
    'Home': 'Home',
    'End': 'End',
    'Page Up': 'PageUp',
    'Page Down': 'PageDown',
    'F1': 'F1',
    'F2': 'F2',
    'F3': 'F3',
    'F4': 'F4',
    'F5': 'F5',
    'F6': 'F6',
    'F7': 'F7',
    'F8': 'F8',
    'F9': 'F9',
    'F10': 'F10',
    'F11': 'F11',
    'F12': 'F12',
  };
  return named[label];
}

String? _logicalKeyName(LogicalKeyboardKey key) {
  final named = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.space: 'Space',
    LogicalKeyboardKey.arrowLeft: 'ArrowLeft',
    LogicalKeyboardKey.arrowRight: 'ArrowRight',
    LogicalKeyboardKey.arrowUp: 'ArrowUp',
    LogicalKeyboardKey.arrowDown: 'ArrowDown',
    LogicalKeyboardKey.enter: 'Enter',
    LogicalKeyboardKey.tab: 'Tab',
    LogicalKeyboardKey.backspace: 'Backspace',
    LogicalKeyboardKey.delete: 'Delete',
    LogicalKeyboardKey.home: 'Home',
    LogicalKeyboardKey.end: 'End',
    LogicalKeyboardKey.pageUp: 'PageUp',
    LogicalKeyboardKey.pageDown: 'PageDown',
    LogicalKeyboardKey.f1: 'F1',
    LogicalKeyboardKey.f2: 'F2',
    LogicalKeyboardKey.f3: 'F3',
    LogicalKeyboardKey.f4: 'F4',
    LogicalKeyboardKey.f5: 'F5',
    LogicalKeyboardKey.f6: 'F6',
    LogicalKeyboardKey.f7: 'F7',
    LogicalKeyboardKey.f8: 'F8',
    LogicalKeyboardKey.f9: 'F9',
    LogicalKeyboardKey.f10: 'F10',
    LogicalKeyboardKey.f11: 'F11',
    LogicalKeyboardKey.f12: 'F12',
  };
  if (named.containsKey(key)) return named[key];
  final label = key.keyLabel;
  if (label.isNotEmpty) return label.toUpperCase();
  return null;
}
