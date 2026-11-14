import 'dart:io';

import 'package:android_file_picker/android_file_picker.dart';
import 'package:aqloss/services/ios_folder_access.dart';
import 'package:aqloss/util/android_path_helper.dart';
import 'package:aqloss/util/logger.dart';
import 'package:aqloss/l10n/l10n.dart';
import 'package:aqloss/util/notices.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class DirectoryPickerException implements Exception {
  final String message;
  const DirectoryPickerException(this.message);

  @override
  String toString() => message;
}

Future<void> addMusicFolderFromPicker(
  BuildContext context, {
  required Future<void> Function(String path) onAdded,
}) async {
  if (Platform.isAndroid) {
    final granted = await requestAndroidStoragePermission();
    if (!granted) {
      if (context.mounted) {
        _tell(context, tr(kStoragePermissionRequiredMessage));
      }
      return;
    }
  }
  if (!context.mounted) return;
  try {
    final path = await pickLibraryFolder(context);
    if (path == null) return;
    await onAdded(path);
  } on DirectoryPickerException catch (e) {
    if (context.mounted) _tell(context, tr(e.message));
  }
}

const kFirstMusicFolderPref = 'aqloss_first_music_folder_prompted';

bool shouldPromptFirstMusicFolder({
  required bool prompted,
  required bool initDone,
  required bool foldersEmpty,
}) => !prompted && initDone && foldersEmpty;

Future<String?> pickLibraryFolder(BuildContext context) async {
  final raw = await pickDirectory(context, dialogTitle: 'Select music folder');
  if (raw == null) return null;
  final path = resolveAndroidPath(raw);
  if (!isScannableFolderPath(path)) {
    throw const DirectoryPickerException(kAndroidFolderUnusableMessage);
  }
  return path;
}

Future<String?> pickDirectory(
  BuildContext context, {
  String dialogTitle = 'Select folder',
  String? initialDirectory,
}) async {
  if (Platform.isIOS) {
    return IosFolderAccess.pickFolder();
  }
  if (!context.mounted) return null;

  try {
    return await FilePicker.getDirectoryPath(
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
      androidOptions: const FilePickerAndroidOptions(
        safOptions: AndroidSAFOptions(
          grant: AndroidSAFGrant.lifetime,
          persistGrant: true,
        ),
      ),
    );
  } catch (e, st) {
    Logger.errorFrontend('Native directory picker failed: $e\n$st');
    if (Platform.isAndroid) {
      throw const DirectoryPickerException(kFolderPickFailedMessage);
    }
  }
  return null;
}

void _tell(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));
}
