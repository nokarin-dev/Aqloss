import 'package:aqloss/util/notices.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scan finished names the track count', () {
    expect(libraryScanFinishedMessage(0), 'Scanned 0 tracks');
    expect(libraryScanFinishedMessage(1), 'Scanned 1 track');
    expect(libraryScanFinishedMessage(12), 'Scanned 12 tracks');
  });

  test('update available names the version', () {
    expect(updateAvailableMessage('1.0.2'), 'Version 1.0.2 is available');
  });
}
