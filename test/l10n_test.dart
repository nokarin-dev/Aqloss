import 'dart:io';

import 'package:aqloss/l10n/english_copy.dart';
import 'package:aqloss/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AppCopy.apply(const {}));

  test('a translation file is keyed by its language code', () {
    final catalog = L10nCatalog.parse({
      'assets/l10n/de.json':
          '{"_name":"Deutsch","sidebar.library":"Bibliothek"}',
      'assets/l10n/en.json': '{}',
      'assets/l10n/it.json': '{',
      'assets/l10n/notes.txt': '{}',
    });

    expect(catalog.codes, {'de'});
    expect(catalog.nameOf('de'), 'Deutsch');
    expect(catalog.tableFor('de'), {'sidebar.library': 'Bibliothek'});
    expect(catalog.tableFor('en'), isEmpty);
  });

  test('system language is used only when a translation exists', () {
    const available = {'de', 'it'};
    expect(
      resolveLanguage(preference: '', systemCode: 'de', available: available),
      'de',
    );
    expect(
      resolveLanguage(preference: '', systemCode: 'fr', available: available),
      'en',
    );
    expect(
      resolveLanguage(preference: 'en', systemCode: 'de', available: available),
      'en',
    );
    expect(
      resolveLanguage(preference: 'it', systemCode: 'de', available: available),
      'it',
    );
    expect(
      resolveLanguage(preference: 'es', systemCode: 'de', available: available),
      'de',
    );
  });

  test('a bad line is dropped and the percent counts the rest', () {
    final catalog = L10nCatalog.parse({
      'assets/l10n/en.json':
          '{"sidebar.library":"Library","sidebar.albums":"Albums","library.scanned":"Scanned {count} tracks"}',
      'assets/l10n/de.json':
          '{"_name":"Deutsch","sidebar.library":" Bibliothek ","sidebar.albums":"","library.scanned":"Titel","extra":"Ja","broken":1}',
    });

    expect(catalog.englishKeys, {
      'sidebar.library',
      'sidebar.albums',
      'library.scanned',
    });
    expect(catalog.tableFor('de'), {
      'sidebar.library': 'Bibliothek',
      'extra': 'Ja',
    });
    expect(catalog.percentOf('de'), 33);
    expect(catalog.labelFor('de'), 'Deutsch (33%)');
    expect(catalog.tableFor('en'), {
      'sidebar.library': 'Library',
      'sidebar.albums': 'Albums',
      'library.scanned': 'Scanned {count} tracks',
    });
  });

  test('missing copy stays English and placeholders are filled', () {
    AppCopy.apply(
      const {
        'sidebar.library': 'Bibliothek',
        'library.scanned': '{count} Titel',
      },
      english: const {
        'sidebar.library': 'Library',
        'sidebar.albums': 'Albums',
        'library.scanned': 'Scanned {count} tracks',
      },
    );
    expect(tr('sidebar.library'), 'Bibliothek');
    expect(tr('sidebar.albums'), 'Albums');
    expect(tr(''), '');
    expect(trFill('library.scanned', {'count': '12'}), '12 Titel');
  });

  test('indonesian covers every english line', () {
    final catalog = L10nCatalog.parse({
      'assets/l10n/en.json': File('assets/l10n/en.json').readAsStringSync(),
      'assets/l10n/id.json': File('assets/l10n/id.json').readAsStringSync(),
    });
    expect(catalog.percentOf('id'), 100);
    expect(catalog.labelFor('id'), 'Bahasa Indonesia (100%)');
    expect(catalog.tableFor('id').length, catalog.englishKeys.length);
  });

  test('english fallback matches en.json', () {
    final catalog = L10nCatalog.parse({
      'assets/l10n/en.json': File('assets/l10n/en.json').readAsStringSync(),
    });
    expect(catalog.tableFor('en'), kEnglishCopy);
  });
}
