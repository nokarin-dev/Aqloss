import 'dart:io';

import 'package:aqloss/util/logger.dart';
import 'package:aqloss/widgets/folder_browser_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

// Linux: zenity/kdialog, then in-app on Hyprland
Future<String?> pickDirectory(
  BuildContext context, {
  String dialogTitle = 'Select folder',
  String? initialDirectory,
}) async {
  if (Platform.isLinux) {
    final cli = await _pickDirectoryLinuxCli(dialogTitle, initialDirectory);
    if (cli.handled) return cli.path;
  }

  final skipPortal = Platform.isLinux && _isTilingWayland;
  if (!skipPortal) {
    try {
      return await FilePicker.getDirectoryPath(
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
      );
    } catch (e, st) {
      Logger.errorFrontend('Native directory picker failed: $e\n$st');
      if (Platform.isAndroid || Platform.isIOS) return null;
    }
  }

  if (!context.mounted) return null;
  if (Platform.isAndroid || Platform.isIOS) return null;

  return FolderBrowserDialog.show(
    context,
    title: dialogTitle,
    initialDirectory: initialDirectory,
  );
}

bool get _isTilingWayland {
  final hypr = Platform.environment['HYPRLAND_INSTANCE_SIGNATURE'];
  if (hypr != null && hypr.isNotEmpty) return true;
  final desktop = (Platform.environment['XDG_CURRENT_DESKTOP'] ?? '')
      .toLowerCase();
  return desktop.contains('hyprland') ||
      desktop.contains('niri') ||
      desktop.contains('sway') ||
      desktop.contains('river');
}

class _CliResult {
  final bool handled;
  final String? path;

  const _CliResult.miss() : handled = false, path = null;
  const _CliResult.done(this.path) : handled = true;
}

Future<_CliResult> _pickDirectoryLinuxCli(
  String title,
  String? initialDirectory,
) async {
  final start = _linuxStartDir(initialDirectory);

  final zenity = _which('zenity') ?? _which('qarma');
  if (zenity != null) {
    final result = await _runCli(zenity, [
      '--file-selection',
      '--directory',
      '--title=$title',
      if (start != null) '--filename=$start',
    ]);
    if (result.handled) return result;
  }

  final yad = _which('yad');
  if (yad != null) {
    final result = await _runCli(yad, [
      '--file-selection',
      '--directory',
      '--title=$title',
      if (start != null) '--filename=$start',
    ]);
    if (result.handled) return result;
  }

  final kdialog = _which('kdialog');
  if (kdialog != null) {
    final home = Platform.environment['HOME'] ?? '.';
    final result = await _runCli(kdialog, [
      '--getexistingdirectory',
      initialDirectory ?? home,
      title,
    ]);
    if (result.handled) return result;
  }

  return const _CliResult.miss();
}

String? _linuxStartDir(String? initialDirectory) {
  final raw = initialDirectory ?? Platform.environment['HOME'];
  if (raw == null || raw.isEmpty) return null;
  return raw.endsWith('/') ? raw : '$raw/';
}

Future<_CliResult> _runCli(String executable, List<String> arguments) async {
  try {
    final result = await Process.run(executable, arguments);
    if (result.exitCode == 0) {
      final path = (result.stdout as String).trim();
      if (path.isEmpty) return const _CliResult.done(null);
      return _CliResult.done(path);
    }
    if (result.exitCode == 1) return const _CliResult.done(null);
    Logger.warnFrontend(
      'Directory picker $executable exited ${result.exitCode}: '
      '${result.stderr}',
    );
  } catch (e) {
    Logger.warnFrontend('Directory picker $executable failed: $e');
  }
  return const _CliResult.miss();
}

String? _which(String name) {
  final dirs = <String>{
    ...((Platform.environment['PATH'] ?? '').split(':')),
    '/usr/bin',
    '/usr/local/bin',
    '/bin',
  };
  for (final dir in dirs) {
    if (dir.isEmpty) continue;
    final candidate = File('$dir/$name');
    if (candidate.existsSync()) return candidate.path;
  }
  return null;
}
