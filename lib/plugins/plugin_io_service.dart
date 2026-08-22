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

enum PluginImportStatus {
  ok,
  cancelled,
  invalidFormat,
  missingManifest,
  alreadyInstalled,
  extractError,
  permissionDenied,
  loadFailed,
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
    PluginImportStatus.ok =>
      'The “${manifest?.name}” plugin was successfully installed.',
    PluginImportStatus.cancelled => '',
    PluginImportStatus.invalidFormat =>
      'This is not a valid .aqx file. It may be corrupted or not a ZIP archive.',
    PluginImportStatus.missingManifest =>
      'plugin.json was not found in the .aqx file.',
    PluginImportStatus.alreadyInstalled =>
      '“${manifest?.name}” is already installed. Uninstall it first before reinstalling.',
    PluginImportStatus.extractError =>
      'Failed to extract plugin: ${errorDetail ?? "unknown error"}.',
    PluginImportStatus.permissionDenied =>
      'Unable to write to the plugins folder.',
    PluginImportStatus.loadFailed =>
      'The plugin was extracted but could not be loaded: ${errorDetail ?? "unknown error"}.',
  };
}

class PluginPreviewResult {
  final PluginImportStatus status;
  final Uint8List? bytes;
  final PluginManifest? manifest;
  final String? errorDetail;

  const PluginPreviewResult._({
    required this.status,
    this.bytes,
    this.manifest,
    this.errorDetail,
  });

  bool get ok => status == PluginImportStatus.ok;
  bool get cancelled => status == PluginImportStatus.cancelled;

  String get userMessage => PluginImportResult._(
    status: status,
    manifest: manifest,
    errorDetail: errorDetail,
  ).userMessage;
}

class PluginIOService {
  PluginIOService._();

  static Future<PluginImportResult> importFromPicker() async {
    final preview = await previewFromPicker();
    if (!preview.ok) {
      return PluginImportResult._(
        status: preview.status,
        manifest: preview.manifest,
        errorDetail: preview.errorDetail,
      );
    }
    return _install(preview.bytes!);
  }

  static Future<PluginImportResult> importFromBytes(Uint8List bytes) =>
      _install(bytes);

  static Future<PluginImportResult> importFromPath(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      return await _install(bytes);
    } catch (e) {
      return PluginImportResult._(
        status: PluginImportStatus.extractError,
        errorDetail: e.toString(),
      );
    }
  }

  static Future<PluginImportResult> installBytes(Uint8List bytes) =>
      _install(bytes);

  static Future<PluginPreviewResult> previewFromPicker() async {
    PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(
        dialogTitle: 'Install plugin',
        type: FileType.custom,
        allowedExtensions: [_kExtension],
      );
    } catch (e) {
      return PluginPreviewResult._(
        status: PluginImportStatus.extractError,
        errorDetail: e.toString(),
      );
    }

    if (picked == null) {
      return const PluginPreviewResult._(status: PluginImportStatus.cancelled);
    }

    Uint8List bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (e) {
      return PluginPreviewResult._(
        status: PluginImportStatus.extractError,
        errorDetail: e.toString(),
      );
    }

    final manifest = _manifestFromArchive(bytes);
    if (manifest == null) {
      Archive? archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes);
      } catch (_) {
        return const PluginPreviewResult._(
          status: PluginImportStatus.invalidFormat,
        );
      }
      if (_findManifestEntry(archive) == null) {
        return const PluginPreviewResult._(
          status: PluginImportStatus.missingManifest,
        );
      }
      return const PluginPreviewResult._(
        status: PluginImportStatus.invalidFormat,
        errorDetail: 'plugin.json parse error',
      );
    }

    return PluginPreviewResult._(
      status: PluginImportStatus.ok,
      bytes: bytes,
      manifest: manifest,
    );
  }

  static PluginManifest? _manifestFromArchive(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final manifestEntry = _findManifestEntry(archive);
      if (manifestEntry == null) return null;
      final raw =
          jsonDecode(utf8.decode(manifestEntry.content as List<int>))
              as Map<String, dynamic>;
      return PluginManifest.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  static ArchiveFile? _findManifestEntry(Archive archive) {
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name.replaceAll('\\', '/');
      if (name == 'plugin.json' || name.endsWith('/plugin.json')) {
        if (name.contains('__MACOSX')) continue;
        return entry;
      }
    }
    return null;
  }

  // Flatten zip root
  static String? _commonRootPrefix(Archive archive) {
    String? root;
    for (final entry in archive) {
      if (entry.name.isEmpty) continue;
      final name = entry.name.replaceAll('\\', '/');
      if (name.startsWith('__MACOSX')) continue;
      final parts = name.split('/').where((s) => s.isNotEmpty).toList();
      if (parts.isEmpty) continue;
      if (parts.length == 1) return null;
      root ??= parts.first;
      if (parts.first != root) return null;
    }
    return root;
  }

  static Future<PluginImportResult> _install(Uint8List bytes) async {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      Logger.warnPlayerProvider('[plugins] aqx zip decode failed: $e');
      return const PluginImportResult._(
        status: PluginImportStatus.invalidFormat,
      );
    }

    final manifestEntry = _findManifestEntry(archive);
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
    final existingDir = await PluginRegistry.instance.findInstallDir(
      manifest.id,
    );
    if (alreadyLoaded || existingDir != null) {
      return PluginImportResult._(
        status: PluginImportStatus.alreadyInstalled,
        manifest: manifest,
      );
    }

    final pluginsRoot = await PluginRegistry.instance.pluginsDir();
    final destDir = Directory(p.join(pluginsRoot.path, _safeName(manifest.id)));

    try {
      if (await destDir.exists()) {
        await destDir.delete(recursive: true);
      }
      await destDir.create(recursive: true);
    } catch (e) {
      return PluginImportResult._(
        status: PluginImportStatus.permissionDenied,
        errorDetail: e.toString(),
      );
    }

    final stripRoot = _commonRootPrefix(archive);

    try {
      for (final entry in archive) {
        if (entry.name.isEmpty) continue;
        var relative = entry.name.replaceAll('\\', '/');
        if (relative.startsWith('__MACOSX')) continue;

        if (stripRoot != null) {
          if (relative == stripRoot || relative == '$stripRoot/') continue;
          if (relative.startsWith('$stripRoot/')) {
            relative = relative.substring(stripRoot.length + 1);
          } else {
            continue;
          }
        }
        if (relative.isEmpty) continue;

        final resolved = p.normalize(p.join(destDir.path, relative));
        if (!p.isWithin(destDir.path, resolved) && resolved != destDir.path) {
          continue;
        }

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

    final manifestOnDisk = File(p.join(destDir.path, 'plugin.json'));
    if (!await manifestOnDisk.exists()) {
      try {
        await destDir.delete(recursive: true);
      } catch (_) {}
      return const PluginImportResult._(
        status: PluginImportStatus.extractError,
        errorDetail: 'plugin.json missing after extract',
      );
    }

    Logger.debugFrontend(
      '[plugins] installed ${manifest.id} → ${destDir.path}',
    );

    final loaded = await PluginRegistry.instance.loadFromDir(destDir);
    if (!loaded) {
      try {
        await destDir.delete(recursive: true);
      } catch (_) {}
      return PluginImportResult._(
        status: PluginImportStatus.loadFailed,
        manifest: manifest,
        errorDetail: 'registry rejected ${manifest.id}',
      );
    }

    return PluginImportResult._(
      status: PluginImportStatus.ok,
      manifest: manifest,
    );
  }

  static Future<bool> exportPlugin(String pluginId) async {
    try {
      final srcDir = await PluginRegistry.instance.findInstallDir(pluginId);
      if (srcDir == null || !await srcDir.exists()) return false;

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
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Export plugin',
        fileName: '${_safeName(manifest.id)}.$_kExtension',
        type: FileType.custom,
        allowedExtensions: [_kExtension],
        bytes: outBytes,
      );

      await File(tmpPath).delete();
      return saved != null;
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
