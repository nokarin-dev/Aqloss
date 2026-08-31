import 'dart:ui';

import 'package:aqloss/util/support_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Indonesian locale lists Trakteer first', () {
    final groups = supportGroups(
      indonesiaFirst: preferIndonesianSupport(const Locale('id')),
    );
    expect(groups.first.title, 'Indonesia');
    expect(groups.first.links.first.name, 'Trakteer');
    expect(groups.last.title, 'International');
  });

  test('other locales list Ko-fi first', () {
    final groups = supportGroups(
      indonesiaFirst: preferIndonesianSupport(const Locale('en')),
    );
    expect(groups.first.title, 'International');
    expect(groups.first.links.first.name, 'Ko-fi');
    expect(groups.last.links.map((l) => l.name), ['Trakteer', 'Tako']);
  });
}
