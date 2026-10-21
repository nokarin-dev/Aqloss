import 'package:aqloss/l10n/l10n.dart';
import 'package:aqloss/util/notices.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scan finished names the track count', () {
    expect(libraryScanFinishedMessage(0), 'Scanned 0 tracks');
    expect(libraryScanFinishedMessage(1), 'Scanned 1 tracks');
    expect(libraryScanFinishedMessage(12), 'Scanned 12 tracks');
  });

  test('update available names the version', () {
    expect(updateAvailableMessage('1.0.2'), 'Version 1.0.2 is available');
  });

  test('missing file copy names the count', () {
    expect(missingFilesRemovedMessage(1), 'Removed 1 missing files');
    expect(missingFilesRemovedMessage(3), 'Removed 3 missing files');
    expect(missingPlaylistFilesMessage(1), '1 files missing');
    expect(missingPlaylistFilesMessage(4), '4 files missing');
  });

  test('backup copy is short', () {
    expect(tr(kBackupSavedMessage), 'Backup saved');
    expect(tr(kBackupRestoredMessage), 'Backup restored');
    expect(tr(kBackupInvalidMessage), 'This is not an Aqloss backup');
    expect(
      tr(kStoragePermissionRequiredMessage),
      'Storage permission is required to scan music folders',
    );
    expect(tr(kFolderPickFailedMessage), 'Could not open that folder');
  });

  test('nightly warning copy is short', () {
    expect(tr(kNightlyBuildTitle), 'Nightly build');
    expect(
      tr(kNightlyBuildMessage),
      'This is a rolling build from main. Features may be unfinished or break. Use a GitHub or Flathub release if you want something stable.',
    );
  });
}
