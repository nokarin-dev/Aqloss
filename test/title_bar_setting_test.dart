import 'package:aqloss/providers/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('in-app title bar hides only on Linux when turned off', () {
    expect(
      showInAppTitleBar(linux: false, showTitleBar: false),
      isTrue,
    );
    expect(
      showInAppTitleBar(linux: true, showTitleBar: false),
      isFalse,
    );
    expect(
      showInAppTitleBar(linux: true, showTitleBar: true),
      isTrue,
    );
  });
}
