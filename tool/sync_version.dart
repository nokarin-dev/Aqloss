// Syncs version.yaml to every file that embeds the app version.

import 'dart:io';

void main() {
  final root = Directory.current;
  if (!File('${root.path}/pubspec.yaml').existsSync()) {
    stderr.writeln('Run this from the repository root.');
    exit(1);
  }

  final versionFile = File('${root.path}/version.yaml');
  if (!versionFile.existsSync()) {
    stderr.writeln('Missing version.yaml');
    exit(1);
  }

  final lines = versionFile.readAsLinesSync();
  String? version;
  String? build;
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('version:')) {
      version = trimmed.split(':').last.trim();
    } else if (trimmed.startsWith('build:')) {
      build = trimmed.split(':').last.trim();
    }
  }

  if (version == null || build == null) {
    stderr.writeln('version.yaml must define version and build.');
    exit(1);
  }

  final parts = version.split('.');
  final major = parts.isNotEmpty ? parts[0] : '0';
  final minor = parts.length > 1 ? parts[1] : '0';
  final patch = parts.length > 2 ? parts[2] : '0';
  final buildNum = build;
  final pubspecVersion = '$version+$build';

  // Flutter app + installer
  _replaceInFile(
    '${root.path}/pubspec.yaml',
    RegExp(r'^version:\s*.+$', multiLine: true),
    'version: $pubspecVersion',
  );
  _replaceInFile(
    '${root.path}/installer/pubspec.yaml',
    RegExp(r'^version:\s*.+$', multiLine: true),
    'version: $pubspecVersion',
  );

  // Rust audio engine
  _replaceInFile(
    '${root.path}/rust/Cargo.toml',
    RegExp(r'^version\s*=\s*".+"$', multiLine: true),
    'version = "$version"',
  );

  // rust_builder
  _replaceInFile(
    '${root.path}/rust_builder/pubspec.yaml',
    RegExp(r'^version:\s*.+$', multiLine: true),
    'version: $pubspecVersion',
  );
  for (final platform in ['ios', 'macos']) {
    _replaceInFile(
      '${root.path}/rust_builder/$platform/aqloss_rust_core.podspec',
      RegExp(r"s\.version\s*=\s*'[^']+'"),
      "s.version          = '$version'",
    );
  }

  // Windows
  _replaceInFile(
    '${root.path}/windows/runner/Runner.rc',
    RegExp(r'#define VERSION_AS_NUMBER \d+,\d+,\d+,\d+'),
    '#define VERSION_AS_NUMBER $major,$minor,$patch,$buildNum',
  );
  _replaceInFile(
    '${root.path}/windows/runner/Runner.rc',
    RegExp(r'#define VERSION_AS_STRING "[^"]+"'),
    '#define VERSION_AS_STRING "$version"',
  );

  // Linux Flathub
  _syncLinuxMetainfo(root.path, version);

  final dartConst =
      '''
const String kAppVersion = '$version';
const int kAppBuildNumber = $build;
''';

  File('${root.path}/lib/app_version.dart').writeAsStringSync(dartConst);
  File(
    '${root.path}/installer/lib/app_version.dart',
  ).writeAsStringSync(dartConst);

  stdout.writeln('Synced Aqloss $pubspecVersion');
}

void _syncLinuxMetainfo(String root, String version) {
  final path = '$root/linux/xyz.nokarin.aqloss.metainfo.xml';
  final file = File(path);
  if (!file.existsSync()) {
    stdout.writeln('skip (missing): $path');
    return;
  }

  var content = file.readAsStringSync();
  final releasePattern = RegExp(
    r'(<release version=")[^"]+(" date="[^"]+">)',
  );
  if (!releasePattern.hasMatch(content)) {
    stderr.writeln('No <release version="..."> found in metainfo.xml');
    exit(1);
  }
  content = content.replaceFirstMapped(
    releasePattern,
    (m) => '${m.group(1)}$version${m.group(2)}',
  );

  final urlPattern = RegExp(
    r'(<url type="details">https://github\.com/nokarin-dev/aqloss/releases/tag/v)[^<]+(</url>)',
  );
  if (urlPattern.hasMatch(content)) {
    content = content.replaceFirstMapped(
      urlPattern,
      (m) => '${m.group(1)}$version${m.group(2)}',
    );
  }

  file.writeAsStringSync(content);
}

void _replaceInFile(String path, RegExp pattern, String replacement) {
  final file = File(path);
  if (!file.existsSync()) {
    stdout.writeln('skip (missing): $path');
    return;
  }
  final content = file.readAsStringSync();
  if (!pattern.hasMatch(content)) {
    stderr.writeln('No version field found in $path');
    exit(1);
  }
  file.writeAsStringSync(content.replaceFirst(pattern, replacement));
}
