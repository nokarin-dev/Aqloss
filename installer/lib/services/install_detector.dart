import 'dart:io';

import 'package:aqloss_installer/app_version.dart';
import 'package:aqloss_installer/services/registry_service.dart';

enum InstallMode { install, repair, update }

class DetectedInstall {
  const DetectedInstall({
    required this.mode,
    this.installedVersion,
    this.installPath,
  });

  final InstallMode mode;
  final String? installedVersion;
  final String? installPath;

  String get title => switch (mode) {
    InstallMode.install => 'Welcome',
    InstallMode.update => 'Update Aqloss',
    InstallMode.repair => 'Repair Aqloss',
  };

  String get subtitle => switch (mode) {
    InstallMode.install =>
      'This will install Aqloss on your computer.\nContinue to choose where to install it.',
    InstallMode.update =>
      'Aqloss $installedVersion is installed. This package will update it to $kAppVersion.',
    InstallMode.repair =>
      'Aqloss $kAppVersion is already installed. You can repair the installation.',
  };

  String get primaryAction => switch (mode) {
    InstallMode.install => 'Install',
    InstallMode.update => 'Update',
    InstallMode.repair => 'Repair',
  };

  String get progressTitle => switch (mode) {
    InstallMode.install => 'Installing...',
    InstallMode.update => 'Updating...',
    InstallMode.repair => 'Repairing...',
  };

  String get progressSubtitle => switch (mode) {
    InstallMode.install => 'Please wait while Aqloss is being installed.',
    InstallMode.update => 'Please wait while Aqloss is being updated.',
    InstallMode.repair => 'Please wait while Aqloss is being repaired.',
  };

  String get doneTitle => switch (mode) {
    InstallMode.install => 'Installation complete',
    InstallMode.update => 'Update complete',
    InstallMode.repair => 'Repair complete',
  };

  String get doneSubtitle => switch (mode) {
    InstallMode.install =>
      'Aqloss has been installed successfully.\nYou can launch it from the desktop or Start Menu shortcut.',
    InstallMode.update =>
      'Aqloss has been updated to $kAppVersion.\nYou can launch it from the desktop or Start Menu shortcut.',
    InstallMode.repair =>
      'Aqloss $kAppVersion has been repaired.\nYou can launch it from the desktop or Start Menu shortcut.',
  };
}

class InstallDetector {
  InstallDetector._();

  static Future<DetectedInstall> detect() async {
    if (!Platform.isWindows) {
      return const DetectedInstall(mode: InstallMode.install);
    }

    final installedVersion = await RegistryService.readDisplayVersion();
    final installPath = await RegistryService.readInstallLocation();

    if (installedVersion == null ||
        installPath == null ||
        installPath.isEmpty ||
        !Directory(installPath).existsSync()) {
      return const DetectedInstall(mode: InstallMode.install);
    }

    final exe = File('$installPath${Platform.pathSeparator}aqloss.exe');
    if (!exe.existsSync()) {
      return DetectedInstall(
        mode: InstallMode.repair,
        installedVersion: installedVersion,
        installPath: installPath,
      );
    }

    final cmp = compareVersions(kAppVersion, installedVersion);
    if (cmp == 0) {
      return DetectedInstall(
        mode: InstallMode.repair,
        installedVersion: installedVersion,
        installPath: installPath,
      );
    }
    if (cmp > 0) {
      return DetectedInstall(
        mode: InstallMode.update,
        installedVersion: installedVersion,
        installPath: installPath,
      );
    }

    return DetectedInstall(
      mode: InstallMode.repair,
      installedVersion: installedVersion,
      installPath: installPath,
    );
  }

  static int compareVersions(String a, String b) {
    List<int> parse(String v) {
      final core = v.split(RegExp(r'[-+]')).first;
      return core
          .split('.')
          .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
          .toList();
    }

    final pa = parse(a);
    final pb = parse(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }
}
