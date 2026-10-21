import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final l10nCatalogProvider = FutureProvider<L10nCatalog>((ref) async {
  return loadL10nCatalog(rootBundle);
});

class L10nCatalog {
  final Map<String, Map<String, String>> byCode;
  final Set<String> englishKeys;

  const L10nCatalog(this.byCode, {this.englishKeys = const {}});

  static const empty = L10nCatalog({});

  Set<String> get codes => byCode.keys.where((code) => code != 'en').toSet();

  String nameOf(String code) {
    final name = byCode[code]?['_name']?.trim();
    if (name != null && name.isNotEmpty) return name;
    return code;
  }

  int percentOf(String code) {
    final total = englishKeys.length;
    if (total == 0) return 0;
    final table = byCode[code];
    if (table == null) return 0;
    var hit = 0;
    for (final key in englishKeys) {
      final value = table[key];
      if (value != null && value.isNotEmpty) hit++;
    }
    return ((hit * 100) / total).round();
  }

  String labelFor(String code) {
    final name = nameOf(code);
    if (englishKeys.isEmpty) return name;
    return '$name (${percentOf(code)}%)';
  }

  Map<String, String> tableFor(String code) {
    final raw = byCode[code];
    if (raw == null) return const {};
    return Map.unmodifiable(
      Map.fromEntries(raw.entries.where((e) => !e.key.startsWith('_'))),
    );
  }

  static L10nCatalog parse(Map<String, String> jsonByAssetPath) {
    final byCode = <String, Map<String, String>>{};
    final englishKeys = <String>{};
    for (final entry in jsonByAssetPath.entries) {
      final code = languageCodeFromAsset(entry.key);
      if (code == null) continue;
      final Object? decoded;
      try {
        decoded = jsonDecode(entry.value);
      } catch (_) {
        continue;
      }
      if (decoded is! Map) continue;
      final raw = <String, String>{};
      for (final item in decoded.entries) {
        final key = '${item.key}';
        final value = item.value;
        if (value is! String) continue;
        if (key.startsWith('_')) {
          final meta = value.trim();
          if (meta.isNotEmpty) raw[key] = meta;
          continue;
        }
        if (code == 'en') {
          englishKeys.add(key);
          continue;
        }
        final accepted = acceptedTranslation(key, value);
        if (accepted == null) {
          continue;
        }
        raw[key] = accepted;
      }
      byCode[code] = raw;
    }
    return L10nCatalog(byCode, englishKeys: englishKeys);
  }
}

final _placeholder = RegExp(r'\{[A-Za-z0-9_]+\}');

String? acceptedTranslation(String key, String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (!_sameTokens(_tokens(key), _tokens(trimmed))) return null;
  return trimmed;
}

bool _sameTokens(Set<String> a, Set<String> b) {
  if (a.length != b.length) return false;
  for (final token in a) {
    if (!b.contains(token)) return false;
  }
  return true;
}

Set<String> _tokens(String text) =>
    _placeholder.allMatches(text).map((match) => match.group(0)!).toSet();

String? languageCodeFromAsset(String path) {
  final name = path.split('/').last;
  if (!name.endsWith('.json')) return null;
  final code = name.substring(0, name.length - 5);
  if (!RegExp(r'^[a-z]{2,8}$').hasMatch(code)) return null;
  return code;
}

String resolveLanguage({
  required String preference,
  required String systemCode,
  required Set<String> available,
}) {
  if (preference == 'en') return 'en';
  if (preference.isNotEmpty && available.contains(preference)) {
    return preference;
  }
  final system = systemCode.toLowerCase();
  if (available.contains(system)) return system;
  return 'en';
}

Future<L10nCatalog> loadL10nCatalog(AssetBundle bundle) async {
  final manifest = await AssetManifest.loadFromAssetBundle(bundle);
  final paths = manifest.listAssets().where(
    (path) => path.startsWith('assets/l10n/') && path.endsWith('.json'),
  );
  final files = <String, String>{};
  for (final path in paths) {
    try {
      files[path] = await bundle.loadString(path);
    } catch (_) {}
  }
  return L10nCatalog.parse(files);
}

class AppCopy {
  static Map<String, String> _table = const {};

  static void apply(Map<String, String> table) {
    _table = table;
  }

  static String tr(String english) {
    final value = _table[english];
    if (value == null || value.isEmpty) return english;
    return value;
  }

  static String trFill(String english, Map<String, String> args) {
    var text = tr(english);
    for (final arg in args.entries) {
      text = text.replaceAll('{${arg.key}}', arg.value);
    }
    return text;
  }
}

String tr(String english) => AppCopy.tr(english);

String trFill(String english, Map<String, String> args) =>
    AppCopy.trFill(english, args);
