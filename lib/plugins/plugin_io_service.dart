import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aqloss/plugins/plugin_api.dart';
import 'package:aqloss/plugins/plugin_registry.dart';
import 'package:aqloss/util/logger.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _kExtension = 'aqx';

// Result type
enum PluginImportStatus {
  ok,
  cancelled,
  invalidFormat,
  missingManifest,
  alreadyInstalled,
  extractError,
  permissionDenied,
}

class PluginImportResult {
  final PluginImportStatus status;
  final PluginManifest? manifest;
  final String? errorDetail;

  const PluginImportResult._({
    required this.status,
    this.manifest,
    this.errorDetail,
  });

  bool get success => status == PluginImportStatus.ok;
  bool get cancelled => status == PluginImportStatus.cancelled;

  String get userMessage => switch (status) {
    PluginImportStatus.ok => 'The “${manifest?.name}” plugin was successfully installed.',
    PluginImportStatus.cancelled => '',
    PluginImportStatus.invalidFormat =>
      'This is not a valid .aqx file, it is not a ZIP file or corrupted.',
    PluginImportStatus.missingManifest =>
      'plugin.json was not found in the .aqx file.',
    PluginImportStatus.alreadyInstalled =>
      '“${manifest?.name}” is already installed. Please uninstall it first before reinstalling.',
    PluginImportStatus.extractError =>
      'Gagal mengekstrak plugin: ${errorDetail ?? "unknown error"}.',
    PluginImportStatus.permissionDenied =>
      'Unable to write to the plugins folder.',
  };
}

// Service
class PluginIOService {
  PluginIOService._();

  static Future<PluginImportResult> importFromPicker() async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.pickFiles(
        dialogTitle: 'Install plugin',
        type: FileType.custom,
        allowedExtensions: [_kExtension],
      );
    } catch (e) {
      return PluginImportResult._(
        status: PluginImportStatus.extractError,
        errorDetail: e.toString(),
      );
    }

    final file = picked?.files.firstOrNull;
    if (file == null) {
      return const PluginImportResult._(status: PluginImportStatus.cancelled);
    }

    final path = file.path;
    if (path == null) {
      return const PluginImportResult._(
        status: PluginImportStatus.extractError,
        errorDetail: 'The file path is not available.',
      );
    }

    Uint8List bytes;
    try {
      bytes = await File(path).readAsBytes();
    } catch (e) {
      return PluginImportResult._(
        status: PluginImportStatus.extractError,
        errorDetail: e.toString(),
      );
    }

    return _install(bytes);
  }

  static Future<PluginImportResult> importFromBytes(Uint8List bytes) =>
      _install(bytes);

  static Future<PluginImportResult> importFromPath(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      return _install(bytes);
    } catch (e) {
      return PluginImportResult._(
        status: PluginImportStatus.extractError,
        errorDetail: e.toString(),
      );
    }
  }

  // Core install
  static Future<PluginImportResult> _install(Uint8List bytes) async {
    // Decode zip
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      Logger.warnPlayerProvider('[plugins] aqx zip decode failed: $e');
      return const PluginImportResult._(
        status: PluginImportStatus.invalidFormat,
      );
    }

    final manifestEntry = archive.findFile('plugin.json');
    if (manifestEntry == null) {
      Logger.warnPlayerProvider('[plugins] plugin.json not found in .aqx');
      return const PluginImportResult._(
        status: PluginImportStatus.missingManifest,
      );
    }

    PluginManifest manifest;
    try {
      final raw =
          jsonDecode(utf8.decode(manifestEntry.content as List<int>))
              as Map<String, dynamic>;
      manifest = PluginManifest.fromJson(raw);
    } catch (e) {
      return PluginImportResult._(
        status: PluginImportStatus.invalidFormat,
        errorDetail: 'plugin.json parse error: $e',
      );
    }

    final alreadyLoaded = PluginRegistry.instance.loadedManifests.any(
      (m) => m.id == manifest.id,
    );
    if (alreadyLoaded) {
      return PluginImportResult._(
        status: PluginImportStatus.alreadyInstalled,
        manifest: manifest,
      );
    }

    final pluginsRoot = await PluginRegistry.instance.pluginsDir();
    final destDir = Directory(p.join(pluginsRoot.path, _safeName(manifest.id)));

    try {
      await destDir.create(recursive: true);
    } catch (e) {
      return PluginImportResult._(
        status: PluginImportStatus.permissionDenied,
        errorDetail: e.toString(),
      );
    }

    try {
      for (final entry in archive) {
        if (entry.name.isEmpty) continue;

        final resolved = p.normalize(p.join(destDir.path, entry.name));
        if (!resolved.startsWith(p.normalize(destDir.path))) continue;

        if (entry.isFile) {
          final outFile = File(resolved);
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(entry.content as List<int>);
        } else {
          await Directory(resolved).create(recursive: true);
        }
      }
    } catch (e) {
      try {
        await destDir.delete(recursive: true);
      } catch (_) {}
      Logger.errorPlayerProvider('[plugins] extract failed: $e');
      return PluginImportResult._(
        status: PluginImportStatus.extractError,
        errorDetail: e.toString(),
      );
    }

    Logger.debugFrontend(
      '[plugins] installed ${manifest.id} → ${destDir.path}',
    );

    await PluginRegistry.instance.loadFromDir(destDir);

    return PluginImportResult._(
      status: PluginImportStatus.ok,
      manifest: manifest,
    );
  }

  // Export
  static Future<bool> exportPlugin(String pluginId) async {
    try {
      final pluginsRoot = await PluginRegistry.instance.pluginsDir();
      final srcDir = Directory(p.join(pluginsRoot.path, _safeName(pluginId)));
      if (!await srcDir.exists()) return false;

      final manifest = PluginRegistry.instance.loadedManifests.firstWhere(
        (m) => m.id == pluginId,
      );

      final encoder = ZipFileEncoder();
      final tmp = await getTemporaryDirectory();
      final tmpPath = p.join(tmp.path, '${_safeName(pluginId)}.aqx');
      encoder.create(tmpPath);

      await _addDirToZip(encoder, srcDir, '');
      encoder.close();

      final outBytes = await File(tmpPath).readAsBytes();
      final savePath = await FilePicker.saveFile(
        dialogTitle: 'Export plugin',
        fileName: '${_safeName(manifest.id)}.$_kExtension',
        type: FileType.custom,
        allowedExtensions: [_kExtension],
        bytes: outBytes,
      );

      await File(tmpPath).delete();
      return savePath != null;
    } catch (e) {
      Logger.errorPlayerProvider('[plugins] export failed: $e');
      return false;
    }
  }

  static Future<void> _addDirToZip(
    ZipFileEncoder enc,
    Directory dir,
    String prefix,
  ) async {
    for (final e in dir.listSync()) {
      final name = p.basename(e.path);
      final entryName = prefix.isEmpty ? name : '$prefix/$name';
      if (e is File) {
        final bytes = await e.readAsBytes();
        enc.addArchiveFile(ArchiveFile(entryName, bytes.length, bytes));
      } else if (e is Directory) {
        await _addDirToZip(enc, e, entryName);
      }
    }
  }

  static String _safeName(String id) =>
      id.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
}
