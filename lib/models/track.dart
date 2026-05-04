class Track {
  final String path;
  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final int? trackNumber;
  final double durationSecs;
  final int sampleRate;
  final int? bitDepth;
  final int channels;
  final String format;
  final int fileSizeBytes;
  final double? replayGainTrack;
  final double? replayGainAlbum;

  const Track({
    required this.path,
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.trackNumber,
    required this.durationSecs,
    required this.sampleRate,
    this.bitDepth,
    required this.channels,
    required this.format,
    required this.fileSizeBytes,
    this.replayGainTrack,
    this.replayGainAlbum,
  });

  Track copyWith({
    String? path,
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    int? trackNumber,
    double? durationSecs,
    int? sampleRate,
    int? bitDepth,
    int? channels,
    String? format,
    int? fileSizeBytes,
    double? replayGainTrack,
    double? replayGainAlbum,
  }) => Track(
    path: path ?? this.path,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    albumArtist: albumArtist ?? this.albumArtist,
    trackNumber: trackNumber ?? this.trackNumber,
    durationSecs: durationSecs ?? this.durationSecs,
    sampleRate: sampleRate ?? this.sampleRate,
    bitDepth: bitDepth ?? this.bitDepth,
    channels: channels ?? this.channels,
    format: format ?? this.format,
    fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    replayGainTrack: replayGainTrack ?? this.replayGainTrack,
    replayGainAlbum: replayGainAlbum ?? this.replayGainAlbum,
  );

  factory Track.fromJson(Map<String, dynamic> json) => Track(
    path: json['path'] as String,
    title: json['title'] as String?,
    artist: json['artist'] as String?,
    album: json['album'] as String?,
    albumArtist: json['albumArtist'] as String?,
    trackNumber: json['trackNumber'] as int?,
    durationSecs: (json['durationSecs'] as num).toDouble(),
    sampleRate: json['sampleRate'] as int,
    bitDepth: json['bitDepth'] as int?,
    channels: json['channels'] as int,
    format: json['format'] as String,
    fileSizeBytes: json['fileSizeBytes'] as int,
    replayGainTrack: (json['replayGainTrack'] as num?)?.toDouble(),
    replayGainAlbum: (json['replayGainAlbum'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'path': path,
    'title': title,
    'artist': artist,
    'album': album,
    'albumArtist': albumArtist,
    'trackNumber': trackNumber,
    'durationSecs': durationSecs,
    'sampleRate': sampleRate,
    'bitDepth': bitDepth,
    'channels': channels,
    'format': format,
    'fileSizeBytes': fileSizeBytes,
    'replayGainTrack': replayGainTrack,
    'replayGainAlbum': replayGainAlbum,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Track && other.path == path);

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() =>
      'Track(title: $title, artist: $artist, format: $format, '
      'sampleRate: ${sampleRate}Hz, rg_track: $replayGainTrack dB)';

  String get displayTitle => title ?? path.split('/').last;
  String get displayArtist => artist ?? 'Unknown Artist';
  String get displayAlbum => album ?? 'Unknown Album';

  Duration get duration =>
      Duration(milliseconds: (durationSecs * 1000).round());

  Track copyWithDuration(Duration d) =>
      copyWith(durationSecs: d.inMilliseconds / 1000.0);

  String get formatLabel {
    final khz =
        '${(sampleRate / 1000).toStringAsFixed(sampleRate % 1000 == 0 ? 0 : 1)}kHz';
    final bits = bitDepth != null ? ' · ${bitDepth}bit' : '';
    return '$format · $khz$bits';
  }

  String get durationLabel {
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get fileSizeLabel =>
      '${(fileSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';

  bool get hasReplayGain => replayGainTrack != null || replayGainAlbum != null;
}
