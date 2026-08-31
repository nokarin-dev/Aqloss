import 'package:aqloss/providers/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows defaults to exclusive', () {
    expect(
      platformDefaultOutputMode(windows: true),
      AudioOutputMode.exclusive,
    );
  });

  test('other platforms default to system', () {
    expect(
      platformDefaultOutputMode(windows: false),
      AudioOutputMode.system,
    );
  });
}
