import 'package:aqloss/l10n/l10n.dart';

String libraryScanFinishedMessage(int trackCount) =>
    trFill('library.scanned', {'count': '$trackCount'});

const kLibraryScanFailedMessage = 'library.scan_failed';

const kScrobbleFailedMessage = 'integrations.scrobble_failed';

String updateAvailableMessage(String version) =>
    trFill('updates.available', {'version': version});

String missingFilesRemovedMessage(int count) =>
    trFill('playlists.removed_count', {'count': '$count'});

String missingPlaylistFilesMessage(int count) =>
    trFill('playlists.missing_count', {'count': '$count'});

const kBackupSavedMessage = 'support.saved';

const kBackupRestoredMessage = 'support.restored';

const kBackupSaveFailedMessage = 'support.save_failed';

const kBackupFailedMessage = 'support.restore_failed';

const kBackupInvalidMessage = 'support.invalid';

const kStoragePermissionRequiredMessage = 'folders.permission';

const kFolderPickFailedMessage = 'folders.open_failed';

const kAndroidFolderUnusableMessage = 'folders.android_unusable';

const kIosMusicFolderHint = 'folders.ios_hint';

const kNightlyBuildTitle = 'updates.nightly';

const kNightlyBuildMessage = 'updates.nightly_body';
