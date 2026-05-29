import 'dart:convert';
import 'dart:io';

import 'package:aqloss/models/playlist.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _kFormatKey = 'aqloss-playlist';
const _kFormatVer = 1;
const _kExtension = 'aqp';

class PlaylistExportResult {
  final bool success;
  final String? savedPath;
  final String? error;
  const PlaylistExportResult.ok(this.savedPath) : success = true, error = null;
  const PlaylistExportResult.fail(this.error)
    : success = false,
      savedPath = null;
}

class PlaylistImportResult {
  final bool success;
  final Playlist? playlist;
  final String? error;
  const PlaylistImportResult.ok(this.playlist) : success = true, error = null;
  const PlaylistImportResult.fail(this.error)
    : success = false,
      playlist = null;
}

class PlaylistIOService {
  PlaylistIOService._();

  // Export
  static Future<PlaylistExportResult> export(Playlist playlist) async {
    try {
      final json = jsonEncode({
        'format': _kFormatKey,
        'version': _kFormatVer,
        'exported': DateTime.now().toUtc().toIso8601String(),
        'playlist': playlist.toJson(),
      });

      final safeName = playlist.name
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .trim();
      final fileName = '$safeName.$_kExtension';

      String? savePath;
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        savePath = await FilePicker.saveFile(
          dialogTitle: 'Export playlist',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: [_kExtension],
        );
      } else {
        final dir =
            await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
        savePath = p.join(dir.path, fileName);
      }

      if (savePath == null) {
        // User cancelled
        return const PlaylistExportResult.fail(null);
      }

      await File(savePath).writeAsString(json, flush: true);
      return PlaylistExportResult.ok(savePath);
    } catch (e) {
      return PlaylistExportResult.fail(e.toString());
    }
  }

  // Import
  static Future<PlaylistImportResult> import() async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Import playlist',
        type: FileType.custom,
        allowedExtensions: [_kExtension],
        withData: true,
      );

      final file = result?.files.firstOrNull;
      if (file == null) {
        return const PlaylistImportResult.fail(null);
      }

      final bytes = file.bytes;
      final String raw;
      if (bytes != null) {
        raw = utf8.decode(bytes);
      } else if (file.path != null) {
        raw = await File(file.path!).readAsString();
      } else {
        return const PlaylistImportResult.fail('Could not read file.');
      }

      final Map<String, dynamic> envelope;
      try {
        envelope = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return const PlaylistImportResult.fail('File is not valid JSON.');
      }

      // Validate format
      if (envelope['format'] != _kFormatKey) {
        return const PlaylistImportResult.fail(
          'Not a valid .aqp playlist file.',
        );
      }

      final version = envelope['version'] as int? ?? 0;
      if (version > _kFormatVer) {
        return PlaylistImportResult.fail(
          'This file was created with a newer version of Aqloss (v$version). '
          'Please update the app to import it.',
        );
      }

      final playlistJson = envelope['playlist'] as Map<String, dynamic>?;
      if (playlistJson == null) {
        return const PlaylistImportResult.fail('Playlist data missing.');
      }

      final imported = Playlist.fromJson({
        ...playlistJson,
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'createdAt': DateTime.now().toIso8601String(),
      });

      return PlaylistImportResult.ok(imported);
    } catch (e) {
      return PlaylistImportResult.fail(e.toString());
    }
  }
}
