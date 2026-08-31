String libraryScanFinishedMessage(int trackCount) {
  if (trackCount == 1) return 'Scanned 1 track';
  return 'Scanned $trackCount tracks';
}

const kLibraryScanFailedMessage = 'Library scan failed';

const kScrobbleFailedMessage = 'Scrobble failed';

String updateAvailableMessage(String version) =>
    'Version $version is available';
