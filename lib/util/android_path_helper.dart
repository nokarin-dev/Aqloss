import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestAndroidStoragePermission() async {
  if (!Platform.isAndroid) return true;

  final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;

  final permission = sdk >= 33 ? Permission.audio : Permission.storage;

  if (await permission.isGranted) return true;
  final status = await permission.request();
  return status.isGranted;
}

bool isScannableFolderPath(String path) {
  final value = path.trim();
  if (value.isEmpty) return false;
  if (value.startsWith('content://')) return false;
  return true;
}

// content:// and file:// → filesystem path. Test without Platform.
String decodeAndroidContentUri(String raw) {
  final value = raw.trim();
  if (value.startsWith('file:')) {
    try {
      return Uri.parse(value).toFilePath();
    } catch (_) {
      return value;
    }
  }
  if (!value.startsWith('content://')) return value;

  try {
    final uri = Uri.parse(value);
    final segments = uri.pathSegments;
    String? id;
    for (var i = 0; i < segments.length; i++) {
      if ((segments[i] == 'tree' || segments[i] == 'document') &&
          i + 1 < segments.length) {
        id = segments[i + 1];
      }
    }
    id ??= segments.isEmpty ? null : segments.last;
    if (id == null) return value;

    final decoded = Uri.decodeComponent(id);
    final colon = decoded.indexOf(':');
    if (colon < 0) return value;

    final volume = decoded.substring(0, colon);
    final relative = decoded.substring(colon + 1);
    final base = volume.toLowerCase() == 'primary'
        ? '/storage/emulated/0'
        : '/storage/$volume';
    return relative.isEmpty ? base : '$base/$relative';
  } catch (_) {
    return value;
  }
}

String resolveAndroidPath(String raw) {
  if (!Platform.isAndroid) return raw;
  return decodeAndroidContentUri(raw);
}
