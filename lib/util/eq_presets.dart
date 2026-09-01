import 'dart:convert';

const kEqBandCount = 10;
const kEqGainMin = -12.0;
const kEqGainMax = 12.0;
const kMaxEqUserPresets = 20;
const kEqPresetNameMaxLen = 40;

class EqPreset {
  final String name;
  final List<double> gains;

  const EqPreset({required this.name, required this.gains});
}

const kBuiltInEqPresets = <EqPreset>[
  EqPreset(name: 'Flat', gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  EqPreset(name: 'Rock', gains: [4, 3, 1, -1.5, -2, -1, 1, 3, 4, 4]),
  EqPreset(name: 'Classical', gains: [4, 3, 2, 0, 0, 0, 0.5, 2, 3.5, 4]),
  EqPreset(name: 'Vocal', gains: [-2, -3, -1.5, 1.5, 3.5, 4, 3, 1, 0, -1.5]),
];

enum EqPresetSaveResult { ok, emptyName, builtInName, full }

List<double> normalizeEqGains(List<double> raw) {
  final out = List<double>.filled(kEqBandCount, 0);
  for (var i = 0; i < kEqBandCount && i < raw.length; i++) {
    final snapped = (raw[i] / 0.5).round() * 0.5;
    out[i] = snapped.clamp(kEqGainMin, kEqGainMax);
  }
  return out;
}

bool eqGainsEqual(List<double> a, List<double> b) {
  final na = normalizeEqGains(a);
  final nb = normalizeEqGains(b);
  for (var i = 0; i < kEqBandCount; i++) {
    if ((na[i] - nb[i]).abs() > 0.01) return false;
  }
  return true;
}

String? matchingEqPresetName(List<double> gains, List<EqPreset> user) {
  for (final p in kBuiltInEqPresets) {
    if (eqGainsEqual(gains, p.gains)) return p.name;
  }
  for (final p in user) {
    if (eqGainsEqual(gains, p.gains)) return p.name;
  }
  return null;
}

String? sanitizeEqPresetName(String raw) {
  var name = raw.trim();
  if (name.isEmpty) return null;
  if (name.length > kEqPresetNameMaxLen) {
    name = name.substring(0, kEqPresetNameMaxLen).trim();
  }
  if (name.isEmpty) return null;
  return name;
}

bool isBuiltInEqPresetName(String name) {
  final lower = name.toLowerCase();
  return kBuiltInEqPresets.any((p) => p.name.toLowerCase() == lower);
}

List<EqPreset>? upsertEqUserPreset(
  List<EqPreset> current, {
  required String name,
  required List<double> gains,
  int max = kMaxEqUserPresets,
}) {
  final next = List<EqPreset>.from(current);
  final preset = EqPreset(name: name, gains: normalizeEqGains(gains));
  final i = next.indexWhere((p) => p.name.toLowerCase() == name.toLowerCase());
  if (i >= 0) {
    next[i] = preset;
    return next;
  }
  if (next.length >= max) return null;
  next.add(preset);
  return next;
}

List<EqPreset> decodeEqUserPresets(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final out = <EqPreset>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final name = sanitizeEqPresetName('${item['name'] ?? ''}');
      if (name == null || isBuiltInEqPresetName(name)) continue;
      final gainsRaw = item['gains'];
      if (gainsRaw is! List) continue;
      final gains = <double>[
        for (final g in gainsRaw)
          if (g is num) g.toDouble(),
      ];
      if (gains.isEmpty) continue;
      out.add(EqPreset(name: name, gains: normalizeEqGains(gains)));
      if (out.length >= kMaxEqUserPresets) break;
    }
    return out;
  } catch (_) {
    return const [];
  }
}

String encodeEqUserPresets(List<EqPreset> presets) {
  return jsonEncode([
    for (final p in presets) {'name': p.name, 'gains': p.gains},
  ]);
}
