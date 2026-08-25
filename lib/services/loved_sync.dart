import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/history_provider.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/services/lastfm_service.dart';
import 'package:aqloss/services/listenbrainz_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LovedSyncResult {
  final int imported;
  final int remoteCount;
  const LovedSyncResult({required this.imported, required this.remoteCount});
}

class LovedSync {
  static LastFmCredentials? _creds;
  static String? _session;
  static String? _lastFmUser;
  static String? _lbToken;
  static String? _lbUser;
  static bool _busy = false;

  static void configure({
    LastFmCredentials? lastFmCreds,
    String? lastFmSession,
    String? lastFmUser,
    String? listenBrainzToken,
    String? listenBrainzUser,
  }) {
    _creds = lastFmCreds;
    _session = lastFmSession;
    _lastFmUser = lastFmUser;
    _lbToken = listenBrainzToken;
    _lbUser = listenBrainzUser;
  }

  static Future<void> push(Track track, {required bool loved}) async {
    final artist = track.displayArtist;
    final title = track.displayTitle;
    final creds = _creds;
    final session = _session;
    if (creds != null && session != null) {
      LastFmService.setLoved(
        sessionKey: session,
        creds: creds,
        artist: artist,
        track: title,
        loved: loved,
      );
    }
    final token = _lbToken;
    if (token != null && token.isNotEmpty) {
      ListenBrainzService.setLoved(
        token: token,
        artist: artist,
        track: title,
        loved: loved,
      );
    }
  }

  static Future<LovedSyncResult> importInto(WidgetRef ref) async {
    if (_busy) return const LovedSyncResult(imported: 0, remoteCount: 0);
    _busy = true;
    try {
      final pairs = <({String artist, String title})>{};
      if (_creds != null && (_lastFmUser ?? '').isNotEmpty) {
        pairs.addAll(
          await LastFmService.fetchLovedTracks(
            user: _lastFmUser!,
            creds: _creds!,
          ),
        );
      }
      if ((_lbToken ?? '').isNotEmpty && (_lbUser ?? '').isNotEmpty) {
        pairs.addAll(
          await ListenBrainzService.fetchLovedTracks(
            token: _lbToken!,
            user: _lbUser!,
          ),
        );
      }
      if (pairs.isEmpty) {
        return const LovedSyncResult(imported: 0, remoteCount: 0);
      }
      final keys = <String>{};
      for (final p in pairs) {
        keys.add(_loveKey(p.artist, p.title));
      }
      final paths = <String>[];
      for (final track in ref.read(libraryProvider).tracks) {
        if (keys.contains(_loveKey(track.displayArtist, track.displayTitle))) {
          paths.add(track.path);
        }
      }
      await ref.read(historyProvider.notifier).importLoved(paths);
      return LovedSyncResult(imported: paths.length, remoteCount: pairs.length);
    } finally {
      _busy = false;
    }
  }
}

String _loveKey(String artist, String title) {
  String n(String s) {
    var t = s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    t = t.replaceAll(
      RegExp(
        r'\s*[\(\[](feat\.?|ft\.?|with)[^\)\]]*[\)\]]',
        caseSensitive: false,
      ),
      '',
    );
    return t.trim();
  }

  return '${n(artist)}\t${n(title)}';
}
