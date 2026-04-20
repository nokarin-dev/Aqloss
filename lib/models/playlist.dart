import 'track.dart';

class Playlist {
  final String id;
  final String name;
  final List<Track> tracks;
  final DateTime createdAt;

  const Playlist({
    required this.id,
    required this.name,
    this.tracks = const [],
    required this.createdAt,
  });

  Playlist copyWith({
    String? id,
    String? name,
    List<Track>? tracks,
    DateTime? createdAt,
  }) => Playlist(
    id: id ?? this.id,
    name: name ?? this.name,
    tracks: tracks ?? this.tracks,
    createdAt: createdAt ?? this.createdAt,
  );

  int get length => tracks.length;

  Duration get totalDuration =>
      tracks.fold(Duration.zero, (sum, t) => sum + t.duration);

  Playlist addTrack(Track track) => copyWith(tracks: [...tracks, track]);

  Playlist removeTrackAt(int index) {
    final updated = List<Track>.from(tracks)..removeAt(index);
    return copyWith(tracks: updated);
  }

  Playlist reorder(int oldIndex, int newIndex) {
    final updated = List<Track>.from(tracks);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    return copyWith(tracks: updated);
  }

  static Playlist create(String name) => Playlist(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    name: name,
    createdAt: DateTime.now(),
  );
}
