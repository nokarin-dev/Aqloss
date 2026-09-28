import 'package:aqloss/plugins/plugin_api.dart';
import 'package:aqloss/plugins/plugin_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plugin.json theme permission is kept', () {
    final m = PluginManifest.fromJson({
      'id': 'xyz.test.theme',
      'name': 'Theme',
      'version': '1.0.0',
      'author': 't',
      'permissions': ['theme', 'nope'],
    });
    expect(m.permissions, {PluginPermission.theme});
    expect(PluginPermission.theme.jsonName, 'theme');
  });

  test('plugin hex color parses rgb and argb', () {
    expect(parsePluginHexColor(null), isNull);
    expect(parsePluginHexColor(''), isNull);
    expect(parsePluginHexColor('nope'), isNull);
    expect(parsePluginHexColor('#1a1'), const Color(0xFF11AA11));
    expect(parsePluginHexColor('#1A1A1A'), const Color(0xFF1A1A1A));
    expect(parsePluginHexColor('#801A1A1A'), const Color(0x801A1A1A));
  });
}
