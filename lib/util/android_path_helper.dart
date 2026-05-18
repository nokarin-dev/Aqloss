import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// Request storage read permission on Android.
Future<bool> requestAndroidStoragePermission() async {
  if (!Platform.isAndroid) return true;

  final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;

  final permission = sdk >= 33 ? Permission.audio : Permission.storage;

  if (await permission.isGranted) return true;
  final status = await permission.request();
  return status.isGranted;
}

// Convert Android content
String resolveAndroidPath(String raw) {
  if (!Platform.isAndroid) return raw;
  if (!raw.startsWith('content://')) return raw;

  try {
    final uri = Uri.parse(raw);
    final segments = uri.pathSegments;
    final encoded = segments.last;
    final decoded = Uri.decodeComponent(encoded);

    if (decoded.contains(':')) {
      final parts = decoded.split(':');
      final volume = parts[0];
      final relative = parts.length > 1 ? parts[1] : '';

      final base = volume.toLowerCase() == 'primary'
          ? '/storage/emulated/0'
          : '/storage/$volume';

      return relative.isEmpty ? base : '$base/$relative';
    }
  } catch (_) {}

  return raw;
}
