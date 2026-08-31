import 'package:aqloss/util/update_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('host lookup failure is a network message', () {
    expect(
      formatUpdateCheckError(
        "ClientException: Failed host lookup: 'api.github.com' "
        '(OS Error: No address associated with hostname, errno = 7)',
      ),
      'No network. Check the connection and try again.',
    );
  });

  test('timeout is its own message', () {
    expect(
      formatUpdateCheckError('TimeoutException after 0:00:12.000000'),
      'GitHub timed out. Try again.',
    );
  });

  test('other errors stay generic', () {
    expect(formatUpdateCheckError('FormatException'), 'Could not check for updates.');
  });
}
