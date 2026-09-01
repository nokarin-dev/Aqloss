import 'dart:convert';
import 'dart:io';

import 'package:aqloss/models/playlist.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/util/notices.dart';
import 'package:aqloss/util/settings_backup.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _kExtension = 'json';
const _kFileName = 'aqloss-backup.json';

class BackupExportResult {
  final bool success;
  final String? savedPath;
  final String? error;
  const BackupExportResult.ok(this.savedPath) : success = true, error = null;
  const BackupExportResult.fail(this.error) : success = false, savedPath = null;
}

class BackupImportResult {
  final bool success;
  final SettingsBackupPayload? payload;
  final String? error;
  const BackupImportResult.ok(this.payload) : success = true, error = null;
  const BackupImportResult.fail(this.error) : success = false, payload = null;
}

class SettingsBackupService {
  SettingsBackupService._();

  static Future<BackupExportResult> export({
    required SettingsState settings,
    required List<Playlist> playlists,
    required List<String> folders,
  }) async {
    try {
      final json = jsonEncode(
        encodeBackup(
          settings: settings,
          playlists: playlists,
          folders: folders,
        ),
      );

      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final uri = await FilePicker.saveFile(
          bytes: utf8.encode(json),
          dialogTitle: 'Export backup',
          fileName: _kFileName,
          type: FileType.custom,
          allowedExtensions: [_kExtension],
        );
        if (uri == null) {
          return const BackupExportResult.fail(null);
        }
        final savePath = uri.scheme == 'file'
            ? uri.toFilePath()
            : uri.toString();
        return BackupExportResult.ok(savePath);
      }

      final dir =
          await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final savePath = p.join(dir.path, _kFileName);
      await File(savePath).writeAsString(json, flush: true);
      return BackupExportResult.ok(savePath);
    } catch (_) {
      return const BackupExportResult.fail(kBackupSaveFailedMessage);
    }
  }

  static Future<BackupImportResult> import() async {
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Restore backup',
        type: FileType.custom,
        allowedExtensions: [_kExtension],
      );
      if (file == null) {
        return const BackupImportResult.fail(null);
      }
      final raw = utf8.decode(await file.readAsBytes());
      return parseBackupText(raw);
    } catch (_) {
      return const BackupImportResult.fail(kBackupFailedMessage);
    }
  }

  static BackupImportResult parseBackupText(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const BackupImportResult.fail(kBackupFailedMessage);
    }
    final payload = decodeBackup(decoded);
    if (payload == null) {
      return const BackupImportResult.fail(kBackupInvalidMessage);
    }
    return BackupImportResult.ok(payload);
  }
}
