import 'package:aqloss/plugins/plugin_api.dart';
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
}
