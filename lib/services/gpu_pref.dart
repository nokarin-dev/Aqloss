import 'dart:io';

class GpuPref {
  static Directory dir() {
    if (Platform.isWindows) {
      final appdata = Platform.environment['APPDATA'] ?? '';
      return Directory('$appdata${Platform.pathSeparator}aqloss');
    }
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return Directory('$home/Library/Application Support/aqloss');
    }
    final xdg =
        Platform.environment['XDG_DATA_HOME'] ??
        '${Platform.environment['HOME']}/.local/share';
    return Directory('$xdg/xyz.nokarin.aqloss');
  }

  static File file() => File('${dir().path}${Platform.pathSeparator}hw_accel');

  static Future<void> write(bool enabled) async {
    final f = file();
    await f.parent.create(recursive: true);
    await f.writeAsString(enabled ? '1\n' : '0\n');
  }
}
