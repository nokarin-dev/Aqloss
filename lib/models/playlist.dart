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
  }) =>
      Playlist(
        id: id ?? this.id,
        name: name ?? this.name,
        tracks: tracks ?? this.tracks,
        createdAt: createdAt ?? this.createdAt,
      );

  int get length => tracks.length;

  Duration get totalDuration =>
      tracks.fold(Duration.zero, (sum, t) => sum + t.duration);

  Playlist addTrack(Track track) =>
      copyWith(tracks: [...tracks, track]);

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        tracks: (json['tracks'] as List<dynamic>)
            .map((t) => Track.fromJson(t as Map<String, dynamic>))
            .toList(),
      );

  String get durationLabel {
    final d = totalDuration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
