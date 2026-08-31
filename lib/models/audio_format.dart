enum AudioFormat {
  flac,
  wav,
  aiff,
  alac,
  mp3,
  aac,
  ogg,
  opus,
  wv,
  unknown;

  bool get isLossless => const {flac, wav, aiff, alac, wv}.contains(this);

  static AudioFormat fromExtension(String ext) {
    return switch (ext.toLowerCase()) {
      'flac' => flac,
      'wav' => wav,
      'aiff' || 'aif' => aiff,
      'alac' || 'm4a' => alac,
      'mp3' => mp3,
      'aac' => aac,
      'ogg' => ogg,
      'opus' => opus,
      'wv' => wv,
      _ => unknown,
    };
  }
}
