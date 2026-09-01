import 'package:aqloss/models/audio_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DSD is not a scanned format', () {
    expect(AudioFormat.fromExtension('dsf'), AudioFormat.unknown);
    expect(AudioFormat.fromExtension('dff'), AudioFormat.unknown);
  });

  test('wavpack is lossless', () {
    expect(AudioFormat.fromExtension('wv'), AudioFormat.wv);
    expect(AudioFormat.wv.isLossless, isTrue);
  });
}
