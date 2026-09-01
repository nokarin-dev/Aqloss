String libraryScanFinishedMessage(int trackCount) {
  if (trackCount == 1) return 'Scanned 1 track';
  return 'Scanned $trackCount tracks';
}

const kLibraryScanFailedMessage = 'Library scan failed';

const kScrobbleFailedMessage = 'Scrobble failed';

String updateAvailableMessage(String version) =>
    'Version $version is available';

String missingFilesRemovedMessage(int count) {
  if (count == 1) return 'Removed 1 missing file';
  return 'Removed $count missing files';
}

String missingPlaylistFilesMessage(int count) {
  if (count == 1) return '1 file missing';
  return '$count files missing';
}

const kBackupSavedMessage = 'Backup saved';

const kBackupRestoredMessage = 'Backup restored';

const kBackupSaveFailedMessage = 'Could not save backup';

const kBackupFailedMessage = 'Could not restore backup';

const kBackupInvalidMessage = 'This is not an Aqloss backup';

const kStoragePermissionRequiredMessage =
    'Storage permission is required to scan music folders';

const kFolderPickFailedMessage = 'Could not open that folder';

const kAndroidFolderUnusableMessage =
    'This folder cannot be scanned. Pick a folder on internal storage, such as Music.';
