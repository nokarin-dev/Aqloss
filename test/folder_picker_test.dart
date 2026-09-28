import 'package:aqloss/services/folder_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first launch prompts only after init with no folders', () {
    expect(
      shouldPromptFirstMusicFolder(
        prompted: false,
        initDone: false,
        foldersEmpty: true,
      ),
      isFalse,
    );
    expect(
      shouldPromptFirstMusicFolder(
        prompted: false,
        initDone: true,
        foldersEmpty: false,
      ),
      isFalse,
    );
    expect(
      shouldPromptFirstMusicFolder(
        prompted: true,
        initDone: true,
        foldersEmpty: true,
      ),
      isFalse,
    );
    expect(
      shouldPromptFirstMusicFolder(
        prompted: false,
        initDone: true,
        foldersEmpty: true,
      ),
      isTrue,
    );
  });
}
