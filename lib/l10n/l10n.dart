import 'dart:convert';

import 'package:aqloss/l10n/english_copy.dart';
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
    final rawByCode = <String, Map<String, String>>{};
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
        if (value.trim().isEmpty) continue;
        raw[key] = value;
      }
      rawByCode[code] = raw;
    }

    final english = rawByCode['en'] ?? const <String, String>{};
    final englishKeys = english.keys
        .where((key) => !key.startsWith('_'))
        .toSet();
    final byCode = <String, Map<String, String>>{};
    for (final entry in rawByCode.entries) {
      final kept = <String, String>{};
      for (final item in entry.value.entries) {
        if (item.key.startsWith('_')) {
          final meta = item.value.trim();
          if (meta.isNotEmpty) kept[item.key] = meta;
          continue;
        }
        final source = entry.key == 'en' ? item.value : english[item.key];
        final text = _storedText(item.value, source);
        if (text == null) continue;
        final expected = source == null ? _tokens(item.key) : _tokens(source);
        if (!_sameTokens(expected, _tokens(text))) continue;
        kept[item.key] = text;
      }
      byCode[entry.key] = kept;
    }
    return L10nCatalog(byCode, englishKeys: englishKeys);
  }
}

// Keep edge spaces from the English line
String? _storedText(String value, String? english) {
  if (value.trim().isEmpty) return null;
  if (english != null && english != english.trim()) return value;
  return value.trim();
}

final _placeholder = RegExp(r'\{[A-Za-z0-9_]+\}');

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
  static Map<String, String> _english = kEnglishCopy;

  static void apply(Map<String, String> table, {Map<String, String>? english}) {
    _table = table;
    _english = english == null || english.isEmpty ? kEnglishCopy : english;
  }

  static String tr(String key) {
    final value = _table[key];
    if (value != null && value.isNotEmpty) return value;
    final english = _english[key];
    if (english != null && english.isNotEmpty) return english;
    return key;
  }

  static String trFill(String key, Map<String, String> args) {
    var text = tr(key);
    for (final arg in args.entries) {
      text = text.replaceAll('{${arg.key}}', arg.value);
    }
    return text;
  }
}

String tr(String key) => AppCopy.tr(key);

String trFill(String key, Map<String, String> args) =>
    AppCopy.trFill(key, args);

// Empty-tag names
String trMeta(String text) {
  switch (text) {
    case 'Unknown Artist':
      return tr('library.unknown_artist');
    case 'Unknown Album':
      return tr('library.unknown_album');
    case 'Singles':
      return tr('albums.singles');
    default:
      return text;
  }
}
