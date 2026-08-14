enum AudioFormat {
  flac,
  wav,
  aiff,
  alac,
  dsf,
  dff,
  mp3,
  aac,
  ogg,
  opus,
  unknown;

  bool get isLossless => const {flac, wav, aiff, alac, dsf, dff}.contains(this);
  bool get isHiRes => const {dsf, dff}.contains(this);

  static AudioFormat fromExtension(String ext) {
    return switch (ext.toLowerCase()) {
      'flac' => flac,
      'wav' => wav,
      'aiff' || 'aif' => aiff,
      'alac' || 'm4a' => alac,
      'dsf' => dsf,
      'dff' => dff,
      'mp3' => mp3,
      'aac' => aac,
      'ogg' => ogg,
      'opus' => opus,
      _ => unknown,
    };
  }
}
