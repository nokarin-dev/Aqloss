import 'dart:io';

import 'package:build_tool/src/build_pod.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('vendored-lua');
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  String staticLib() {
    final lib = File(path.join(root.path, 'libaqloss_rust_core.a'));
    lib.createSync();
    return lib.path;
  }

  void archive(List<String> parts) {
    final file = File(path.joinAll([root.path, 'build', ...parts]));
    file.parent.createSync(recursive: true);
    file.createSync();
  }

  test('classic cargo layout', () {
    archive(['mlua-sys-abc', 'out', 'lib', 'liblua5.4.a']);
    expect(
      findVendoredLuaStaticLib(staticLib()),
      path.join(
          root.path, 'build', 'mlua-sys-abc', 'out', 'lib', 'liblua5.4.a'),
    );
  });

  test('cargo 1.100 unit layout', () {
    archive(['mlua-sys', 'deadbeef', 'out', 'lib', 'liblua5.4.a']);
    expect(
      findVendoredLuaStaticLib(staticLib()),
      path.join(
        root.path,
        'build',
        'mlua-sys',
        'deadbeef',
        'out',
        'lib',
        'liblua5.4.a',
      ),
    );
  });

  test('cargo unit run directory', () {
    archive(['mlua-sys', 'deadbeef', 'run', 'out', 'lib', 'liblua.a']);
    expect(
      findVendoredLuaStaticLib(staticLib()),
      path.join(
        root.path,
        'build',
        'mlua-sys',
        'deadbeef',
        'run',
        'out',
        'lib',
        'liblua.a',
      ),
    );
  });

  test('missing archive', () {
    expect(findVendoredLuaStaticLib(staticLib()), isNull);
  });
}
