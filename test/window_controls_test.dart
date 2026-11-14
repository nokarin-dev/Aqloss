import 'package:aqloss/util/window_controls.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hyprland keeps close and drops minimize and maximize', () {
    final set = windowControlSet(
      desktop: true,
      platform: 'linux',
      env: {
        'HYPRLAND_INSTANCE_SIGNATURE': 'abc',
        'XDG_CURRENT_DESKTOP': 'Hyprland',
      },
    );
    expect(set.minimize, isFalse);
    expect(set.maximize, isFalse);
    expect(set.close, isTrue);
  });

  test('gnome keeps minimize, maximize, and close', () {
    final set = windowControlSet(
      desktop: true,
      platform: 'linux',
      env: {'XDG_CURRENT_DESKTOP': 'GNOME'},
    );
    expect(set.minimize, isTrue);
    expect(set.maximize, isTrue);
    expect(set.close, isTrue);
  });

  test('windows keeps all three and macos uses the system buttons', () {
    final windows = windowControlSet(
      desktop: true,
      platform: 'windows',
      env: const {},
    );
    final mac = windowControlSet(
      desktop: true,
      platform: 'macos',
      env: const {},
    );
    expect(windows.minimize && windows.maximize && windows.close, isTrue);
    expect(mac.minimize || mac.maximize || mac.close, isFalse);
  });

  test('a phone draws no window buttons', () {
    final set = windowControlSet(
      desktop: false,
      platform: 'android',
      env: const {},
    );
    expect(set.close, isFalse);
  });
}
