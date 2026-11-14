import 'package:aqloss/providers/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('drops the removed search shortcut and keeps later bindings', () {
    final decoded = decodeStoredShortcuts({
      '0': 'Space',
      '7': 'Ctrl+F',
      '8': 'Ctrl+M',
      '15': 'Ctrl+N',
    });
    expect(decoded[ShortcutAction.playPause], 'Space');
    expect(decoded[ShortcutAction.navPlayer], isNull);
    expect(decoded[ShortcutAction.newPlaylist], 'Ctrl+N');
    expect(decoded.length, 2);
  });

  test('named shortcut map ignores a leftover search key', () {
    final decoded = decodeStoredShortcuts({
      'playPause': 'Space',
      'search': 'Ctrl+F',
      'newPlaylist': 'Ctrl+N',
    });
    expect(decoded[ShortcutAction.playPause], 'Space');
    expect(decoded[ShortcutAction.newPlaylist], 'Ctrl+N');
    expect(decoded.length, 2);
  });
}
