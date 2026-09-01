import 'dart:convert';

import 'package:http/http.dart' as http;

const _kLatestReleaseUrl =
    'https://api.github.com/repos/nokarin-dev/aqloss/releases/latest';

String formatUpdateCheckError(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('timed out') || s.contains('timeout')) {
    return 'GitHub timed out. Try again.';
  }
  if (s.contains('failed host lookup') ||
      s.contains('no address associated') ||
      s.contains('network is unreachable') ||
      s.contains('socketexception') ||
      s.contains('connection refused') ||
      s.contains('connection reset')) {
    return 'No network. Check the connection and try again.';
  }
  return 'Could not check for updates.';
}

bool isNewerVersion(String remote, String local) {
  List<int> parse(String v) => v
      .split('.')
      .map((s) => int.tryParse(s.replaceAll(RegExp(r'[^\d]'), '')) ?? 0)
      .toList();
  final r = parse(remote);
  final l = parse(local);
  final len = r.length > l.length ? r.length : l.length;
  for (var i = 0; i < len; i++) {
    final rv = i < r.length ? r[i] : 0;
    final lv = i < l.length ? l[i] : 0;
    if (rv > lv) return true;
    if (rv < lv) return false;
  }
  return false;
}

String stripReleaseDownloads(String raw) {
  final hrIdx = raw.indexOf('\n---');
  final trimmed = hrIdx != -1 ? raw.substring(0, hrIdx) : raw;
  return trimmed
      .split('\n')
      .where((line) {
        final t = line.trim();
        if (t.startsWith('[![')) return false;
        if (RegExp(r'^https?://').hasMatch(t)) return false;
        return true;
      })
      .join('\n')
      .trim();
}

enum UpdateCheckStatus { upToDate, available, error }

class UpdateCheckResult {
  final UpdateCheckStatus status;
  final String? latestVersion;
  final String? notes;
  final String? url;
  final String? error;

  const UpdateCheckResult.upToDate()
    : status = UpdateCheckStatus.upToDate,
      latestVersion = null,
      notes = null,
      url = null,
      error = null;

  const UpdateCheckResult.available({
    required this.latestVersion,
    this.notes,
    this.url,
  }) : status = UpdateCheckStatus.available,
       error = null;

  const UpdateCheckResult.error(this.error)
    : status = UpdateCheckStatus.error,
      latestVersion = null,
      notes = null,
      url = null;
}

Future<UpdateCheckResult> checkGithubLatest({
  required String currentVersion,
  http.Client? client,
}) async {
  final owned = client == null;
  final httpClient = client ?? http.Client();
  try {
    final resp = await httpClient
        .get(
          Uri.parse(_kLatestReleaseUrl),
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(const Duration(seconds: 12));

    if (resp.statusCode == 404) return const UpdateCheckResult.upToDate();
    if (resp.statusCode != 200) {
      return UpdateCheckResult.error(
        'GitHub responded with ${resp.statusCode}',
      );
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String? ?? '').replaceFirst('v', '');
    final notes = stripReleaseDownloads(data['body'] as String? ?? '');
    final url = data['html_url'] as String? ?? '';
    if (tag.isEmpty || !isNewerVersion(tag, currentVersion)) {
      return const UpdateCheckResult.upToDate();
    }
    return UpdateCheckResult.available(
      latestVersion: tag,
      notes: notes.isEmpty ? null : notes,
      url: url.isEmpty ? null : url,
    );
  } catch (e) {
    return UpdateCheckResult.error(formatUpdateCheckError(e));
  } finally {
    if (owned) httpClient.close();
  }
}
