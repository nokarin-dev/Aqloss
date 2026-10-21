import 'package:aqloss/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AppCopy.apply(const {}));

  test('a translation file is keyed by its language code', () {
    final catalog = L10nCatalog.parse({
      'assets/l10n/de.json': '{"_name":"Deutsch","Library":"Bibliothek"}',
      'assets/l10n/en.json': '{}',
      'assets/l10n/it.json': '{',
      'assets/l10n/notes.txt': '{}',
    });

    expect(catalog.codes, {'de'});
    expect(catalog.nameOf('de'), 'Deutsch');
    expect(catalog.tableFor('de'), {'Library': 'Bibliothek'});
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
          '{"Library":"","Albums":"","Scanned {count} tracks":""}',
      'assets/l10n/de.json':
          '{"_name":"Deutsch","Library":" Bibliothek ","Albums":"","Scanned {count} tracks":"Titel","Extra":"Ja","Broken":1}',
    });

    expect(catalog.englishKeys, {
      'Library',
      'Albums',
      'Scanned {count} tracks',
    });
    expect(catalog.tableFor('de'), {'Library': 'Bibliothek', 'Extra': 'Ja'});
    expect(catalog.percentOf('de'), 33);
    expect(catalog.labelFor('de'), 'Deutsch (33%)');
    expect(catalog.tableFor('en'), isEmpty);
  });

  test('missing copy stays English and placeholders are filled', () {
    AppCopy.apply(const {
      'Library': 'Bibliothek',
      'Scanned {count} tracks': '{count} Titel',
    });
    expect(tr('Library'), 'Bibliothek');
    expect(tr('Albums'), 'Albums');
    expect(tr(''), '');
    expect(trFill('Scanned {count} tracks', {'count': '12'}), '12 Titel');
  });
}
