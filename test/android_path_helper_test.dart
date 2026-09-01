import 'package:aqloss/util/android_path_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tree URI on primary storage becomes a filesystem path', () {
    expect(
      decodeAndroidContentUri(
        'content://com.android.externalstorage.documents/tree/primary%3AMusic',
      ),
      '/storage/emulated/0/Music',
    );
  });

  test('document URI under a tree uses the document id', () {
    expect(
      decodeAndroidContentUri(
        'content://com.android.externalstorage.documents/tree/primary%3AMusic/document/primary%3AMusic%2FAlbums',
      ),
      '/storage/emulated/0/Music/Albums',
    );
  });

  test('SD card volume maps under /storage', () {
    expect(
      decodeAndroidContentUri(
        'content://com.android.externalstorage.documents/tree/1A2B-3C4D%3AMusic',
      ),
      '/storage/1A2B-3C4D/Music',
    );
  });

  test('file URI becomes a path', () {
    expect(
      decodeAndroidContentUri('file:///storage/emulated/0/Music'),
      '/storage/emulated/0/Music',
    );
  });

  test('plain paths and unknown URIs stay as-is', () {
    expect(
      decodeAndroidContentUri('/storage/emulated/0/Music'),
      '/storage/emulated/0/Music',
    );
    expect(
      decodeAndroidContentUri(
        'content://com.android.providers.downloads.documents/tree/downloads',
      ),
      'content://com.android.providers.downloads.documents/tree/downloads',
    );
  });

  test('content URIs are not scannable', () {
    expect(isScannableFolderPath('/storage/emulated/0/Music'), isTrue);
    expect(isScannableFolderPath(''), isFalse);
    expect(
      isScannableFolderPath(
        'content://com.android.providers.downloads.documents/tree/downloads',
      ),
      isFalse,
    );
  });
}
