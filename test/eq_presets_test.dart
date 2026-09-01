import 'package:aqloss/util/eq_presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builtin presets are Flat, Rock, Classical, Vocal', () {
    expect(kBuiltInEqPresets.map((p) => p.name).toList(), [
      'Flat',
      'Rock',
      'Classical',
      'Vocal',
    ]);
    for (final p in kBuiltInEqPresets) {
      expect(p.gains, hasLength(10));
    }
  });

  test('normalize pads, clamps, and snaps to 0.5 dB', () {
    expect(normalizeEqGains([1.2, 20]), [1.0, 12.0, 0, 0, 0, 0, 0, 0, 0, 0]);
  });

  test('matching finds builtin then user names', () {
    expect(matchingEqPresetName(List.filled(10, 0), const []), 'Flat');
    expect(matchingEqPresetName(kBuiltInEqPresets[1].gains, const []), 'Rock');
    final user = [EqPreset(name: 'Desk', gains: List.filled(10, 1.0))];
    expect(matchingEqPresetName(List.filled(10, 1.0), user), 'Desk');
    expect(matchingEqPresetName([1, 2, 3], const []), isNull);
  });

  test('sanitize and reserved names', () {
    expect(sanitizeEqPresetName('  '), isNull);
    expect(sanitizeEqPresetName(' Rock '), 'Rock');
    expect(isBuiltInEqPresetName('rock'), isTrue);
    expect(isBuiltInEqPresetName('Desk'), isFalse);
    expect(sanitizeEqPresetName('a' * 50), 'a' * 40);
  });

  test('upsert overwrites same name and rejects a full list', () {
    final first = upsertEqUserPreset(
      const [],
      name: 'Desk',
      gains: List.filled(10, 2),
    )!;
    expect(first.single.name, 'Desk');
    final replaced = upsertEqUserPreset(
      first,
      name: 'desk',
      gains: List.filled(10, 3),
    )!;
    expect(replaced, hasLength(1));
    expect(replaced.single.gains.first, 3.0);

    final full = [
      for (var i = 0; i < 20; i++)
        EqPreset(name: 'p$i', gains: List.filled(10, 0)),
    ];
    expect(
      upsertEqUserPreset(full, name: 'new', gains: List.filled(10, 1)),
      isNull,
    );
    expect(
      upsertEqUserPreset(full, name: 'p0', gains: List.filled(10, 1)),
      isNotNull,
    );
  });

  test('user preset json round-trip skips builtin names', () {
    final raw = encodeEqUserPresets([
      EqPreset(name: 'Desk', gains: List.filled(10, 1.5)),
    ]);
    final decoded = decodeEqUserPresets(raw);
    expect(decoded.single.name, 'Desk');
    expect(decoded.single.gains.first, 1.5);
    expect(
      decodeEqUserPresets('[{"name":"Rock","gains":[1,1,1,1,1,1,1,1,1,1]}]'),
      isEmpty,
    );
    expect(decodeEqUserPresets('not json'), isEmpty);
  });
}
