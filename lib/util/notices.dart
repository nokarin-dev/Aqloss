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
