import 'package:aqloss/l10n/l10n.dart';

String libraryScanFinishedMessage(int trackCount) {
  if (trackCount == 1) return tr('Scanned 1 track');
  return trFill('Scanned {count} tracks', {'count': '$trackCount'});
}

const kLibraryScanFailedMessage = 'Library scan failed';

const kScrobbleFailedMessage = 'Scrobble failed';

String updateAvailableMessage(String version) =>
    trFill('Version {version} is available', {'version': version});

String missingFilesRemovedMessage(int count) {
  if (count == 1) return tr('Removed 1 missing file');
  return trFill('Removed {count} missing files', {'count': '$count'});
}

String missingPlaylistFilesMessage(int count) {
  if (count == 1) return tr('1 file missing');
  return trFill('{count} files missing', {'count': '$count'});
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

const kIosMusicFolderHint =
    'Copy tracks into Files, On My iPhone, Aqloss. Add Folder only works for folders you pick in Files.';

const kNightlyBuildTitle = 'Nightly build';

const kNightlyBuildMessage =
    'This is a rolling build from main. Features may be unfinished or break. Use a GitHub or Flathub release if you want something stable.';
