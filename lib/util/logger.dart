import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

enum LogLevel {
  debug,
  info,
  warn,
  error;

  String get label => name.toUpperCase();
}

enum LogTarget {
  scrobble('scrobble.log'),
  audioService('audio_service.log'),
  lastfm('lastfm.log'),
  deviceProdiver('device_provider.log'),
  playerProvider('player_provider.log'),
  frontend('frontend.log');

  final String fileName;
  const LogTarget(this.fileName);
}

class Logger {
  static final Logger _instance = Logger._internal();
  factory Logger() => _instance;
  Logger._internal();

  static bool _isInitialized = false;
  static late final Map<LogTarget, File> _files;

  static Future<void> init() async {
    if (_isInitialized) return;

    final appDir = await getApplicationSupportDirectory();
    final logDirPath = p.join(appDir.path, 'logs/frontend');
    final logDir = Directory(logDirPath);

    backend.setLogPath(path: appDir.path);

    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    _files = {
      for (var target in LogTarget.values)
        target: File(p.join(logDirPath, target.fileName)),
    };

    final startSession =
        """
\n──────────────────────────────────────────────────────
[${_timestamp()}] SESSION START
──────────────────────────────────────────────────────\n""";

    for (var file in _files.values) {
      await file.writeAsString(startSession, mode: FileMode.write, flush: true);
    }

    _isInitialized = true;
  }

  static String _timestamp() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} "
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}";
  }

  Future<void> _log(LogTarget target, LogLevel level, String msg) async {
    if (!_isInitialized) await init();

    final line = "[${_timestamp()}] [FRONTEND] [${level.label}] $msg\n";

    stdout.write(line);

    final file = _files[target];
    if (file != null) {
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    }
  }

  // Public API

  // Scrobble
  static void debugScrobble(String msg) =>
      _instance._log(LogTarget.scrobble, LogLevel.debug, msg);
  static void infoScrobble(String msg) =>
      _instance._log(LogTarget.scrobble, LogLevel.info, msg);
  static void warnScrobble(String msg) =>
      _instance._log(LogTarget.scrobble, LogLevel.warn, msg);
  static void errorScrobble(String msg) =>
      _instance._log(LogTarget.scrobble, LogLevel.error, msg);

  // AudioService
  static void debugAudioService(String msg) =>
      _instance._log(LogTarget.audioService, LogLevel.debug, msg);
  static void infoAudioService(String msg) =>
      _instance._log(LogTarget.audioService, LogLevel.info, msg);
  static void warnAudioService(String msg) =>
      _instance._log(LogTarget.audioService, LogLevel.warn, msg);
  static void errorAudioService(String msg) =>
      _instance._log(LogTarget.audioService, LogLevel.error, msg);

  // Lastfm
  static void debugLastfm(String msg) =>
      _instance._log(LogTarget.lastfm, LogLevel.debug, msg);
  static void infoLastfm(String msg) =>
      _instance._log(LogTarget.lastfm, LogLevel.info, msg);
  static void warnLastfm(String msg) =>
      _instance._log(LogTarget.lastfm, LogLevel.warn, msg);
  static void errorLastfm(String msg) =>
      _instance._log(LogTarget.lastfm, LogLevel.error, msg);

  // DeviceProviuder
  static void debugDeviceProvider(String msg) =>
      _instance._log(LogTarget.deviceProdiver, LogLevel.debug, msg);
  static void infoDeviceProvider(String msg) =>
      _instance._log(LogTarget.deviceProdiver, LogLevel.info, msg);
  static void warnDeviceProvider(String msg) =>
      _instance._log(LogTarget.deviceProdiver, LogLevel.warn, msg);
  static void errorDeviceProvider(String msg) =>
      _instance._log(LogTarget.deviceProdiver, LogLevel.error, msg);

  // PlayerProviuder
  static void debugPlayerProvider(String msg) =>
      _instance._log(LogTarget.playerProvider, LogLevel.debug, msg);
  static void infoPlayerProvider(String msg) =>
      _instance._log(LogTarget.playerProvider, LogLevel.info, msg);
  static void warnPlayerProvider(String msg) =>
      _instance._log(LogTarget.playerProvider, LogLevel.warn, msg);
  static void errorPlayerProvider(String msg) =>
      _instance._log(LogTarget.playerProvider, LogLevel.error, msg);

  // Frontend
  static void debugFrontend(String msg) =>
      _instance._log(LogTarget.frontend, LogLevel.debug, msg);
  static void infoFrontend(String msg) =>
      _instance._log(LogTarget.frontend, LogLevel.info, msg);
  static void warnFrontend(String msg) =>
      _instance._log(LogTarget.frontend, LogLevel.warn, msg);
  static void errorFrontend(String msg) =>
      _instance._log(LogTarget.frontend, LogLevel.error, msg);
}
