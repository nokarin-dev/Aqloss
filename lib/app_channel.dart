const kAppChannel = String.fromEnvironment(
  'AQLOSS_CHANNEL',
  defaultValue: 'release',
);

const kIsNightly = kAppChannel == 'nightly';

const kNightlyAckPref = 'aqloss_nightly_ack';

bool shouldShowNightlyNotice({required bool isNightly, required bool acked}) =>
    isNightly && !acked;

String appVersionLabel(String version, {bool nightly = kIsNightly}) {
  if (nightly) return '$version (nightly)';
  return version;
}
