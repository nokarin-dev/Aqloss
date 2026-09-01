import 'package:aqloss/models/track.dart';

enum SortField { title, artist, album, duration, format, dateAdded }

enum SortOrder { ascending, descending }

int compareLibraryTracks(Track a, Track b, SortField field, SortOrder order) {
  final sign = order == SortOrder.ascending ? 1 : -1;
  switch (field) {
    case SortField.title:
      return _by(a, b, sign, [_title, _artist, _album]);
    case SortField.artist:
      return _by(a, b, sign, [_artist, _album, _trackNo]);
    case SortField.album:
      return _by(a, b, sign, [_album, _artist, _trackNo]);
    case SortField.duration:
      return _by(a, b, sign, [_duration, _title]);
    case SortField.format:
      return _by(a, b, sign, [_format, _artist, _album, _trackNo]);
    case SortField.dateAdded:
      return 0;
  }
}

int _by(
  Track a,
  Track b,
  int primarySign,
  List<int Function(Track, Track)> keys,
) {
  for (var i = 0; i < keys.length; i++) {
    final c = keys[i](a, b);
    if (c != 0) return i == 0 ? c * primarySign : c;
  }
  return 0;
}

int _text(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

String _sortArtist(Track t) => (t.albumArtist ?? t.artist ?? '').trim();

int _title(Track a, Track b) => _text(a.displayTitle, b.displayTitle);

int _artist(Track a, Track b) => _text(_sortArtist(a), _sortArtist(b));

int _album(Track a, Track b) => _text(a.album ?? '', b.album ?? '');

int _trackNo(Track a, Track b) =>
    (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);

int _duration(Track a, Track b) => a.durationSecs.compareTo(b.durationSecs);

int _format(Track a, Track b) => _text(a.format, b.format);
