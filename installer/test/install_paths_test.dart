import 'dart:io';

import 'package:aqloss_installer/services/install_paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('default folder is Local AppData', () {
    expect(
      defaultInstallPath({'LOCALAPPDATA': r'C:\Users\sam\AppData\Local'}),
      r'C:\Users\sam\AppData\Local\Aqloss',
    );
  });

  test('falls back to roaming AppData', () {
    expect(
      defaultInstallPath({'APPDATA': r'C:\Users\sam\AppData\Roaming'}),
      r'C:\Users\sam\AppData\Roaming\Aqloss',
    );
  });

  test('prefers Local AppData over roaming', () {
    expect(
      defaultInstallPath({
        'LOCALAPPDATA': r'C:\Users\sam\AppData\Local',
        'APPDATA': r'C:\Users\Administrator\AppData\Roaming',
      }),
      r'C:\Users\sam\AppData\Local\Aqloss',
    );
  });

  test('user data dirs sit under roaming AppData', () {
    expect(
      userDataDirs({'APPDATA': r'C:\Users\sam\AppData\Roaming'}),
      [
        r'C:\Users\sam\AppData\Roaming\aqloss',
        r'C:\Users\sam\AppData\Roaming\xyz.nokarin\aqloss',
      ],
    );
  });

  test('installer manifest asks for asInvoker', () {
    final file = File(p.join('windows', 'runner', 'runner.exe.manifest'));
    expect(file.readAsStringSync(), contains('asInvoker'));
  });
}
