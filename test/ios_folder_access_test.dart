import 'package:aqloss/services/ios_folder_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('documents folder is prepended once', () {
    expect(withIosMusicFolder([], '/docs'), ['/docs']);
    expect(withIosMusicFolder(['/docs'], '/docs'), ['/docs']);
    expect(withIosMusicFolder(['/picked'], '/docs'), ['/docs', '/picked']);
  });
}
