import 'dart:convert';
import 'dart:io';

import 'package:aqloss/plugins/plugin_api.dart';
import 'package:aqloss/plugins/webhook_dispatcher.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/util/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PluginRegistry {
  PluginRegistry._();
  static final PluginRegistry instance = PluginRegistry._();

  final List<_WebhookEntry> _webhooks = [];
  final List<PluginManifest> _luaPlugins = [];
  final Map<String, Directory> _installDirs = {};
  DateTime? _lastPositionDispatch;

  List<PluginManifest> get loadedManifests => [
    ..._webhooks.map((e) => e.manifest),
    ..._luaPlugins,
  ];

  bool isEnabled(String id) {
    final w = _webhooks.firstWhere(
      (e) => e.manifest.id == id,
      orElse: () => _WebhookEntry.sentinel,
    );
    if (!identical(w, _WebhookEntry.sentinel)) return w.enabled;
    if (_luaPlugins.any((m) => m.id == id)) {
      try {
        return backend.pluginIsEnabled(id: id);
      } catch (e) {
        Logger.errorPlayerProvider('[plugins/lua] isEnabled($id): $e');
        return false;
      }
    }
    return false;
  }

  Future<void> init() async {
    await _discoverInstalled();
    Logger.debugFrontend(
      '[plugins] ready - ${_webhooks.length} webhook, ${_luaPlugins.length} lua',
    );
  }

  Future<void> _discoverInstalled() async {
    final dir = await pluginsDir();
    if (!await dir.exists()) return;

    for (final entry in dir.listSync()) {
      if (entry is! Directory) continue;
      await _tryLoadFromDir(entry);
    }
  }

  Future<void> _tryLoadFromDir(Directory dir) async {
    final manifestFile = await _locateManifest(dir);
    if (manifestFile == null) return;

    final loadDir = Directory(p.dirname(manifestFile.path));

    try {
      final raw = jsonDecode(await manifestFile.readAsString());
      final manifest = PluginManifest.fromJson(raw as Map<String, dynamic>);

      if (loadedManifests.any((m) => m.id == manifest.id)) return;

      switch (manifest.type) {
        case PluginType.webhook:
          await _loadWebhook(manifest, loadDir);
        case PluginType.lua:
          await _loadLua(manifest, loadDir);
      }
    } catch (e) {
      Logger.errorPlayerProvider('[plugins] load error ${dir.path}: $e');
    }
  }

  Future<File?> _locateManifest(Directory dir) async {
    final root = File('${dir.path}/plugin.json');
    if (await root.exists()) return root;

    try {
      for (final entry in dir.listSync()) {
        if (entry is! Directory) continue;
        final nested = File('${entry.path}/plugin.json');
        if (await nested.exists()) return nested;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadWebhook(PluginManifest manifest, Directory dir) async {
    if (manifest.webhookUrl == null || manifest.webhookUrl!.isEmpty) {
      Logger.warnPlayerProvider(
        '[plugins] ${manifest.id}: webhook_url is empty - skipped.',
      );
      return;
    }

    final enabled = await _isEnabled(manifest.id);
    _webhooks.add(_WebhookEntry(manifest: manifest, enabled: enabled));
    _installDirs[manifest.id] = dir;
    Logger.debugFrontend('[plugins] webhook loaded: ${manifest.id}');
  }

  Future<void> _loadLua(PluginManifest manifest, Directory dir) async {
    try {
      final loadedId = await backend.pluginLoad(dirPath: dir.path);
      final enabled = await _isEnabled(manifest.id);
      backend.pluginSetEnabled(id: loadedId, enabled: enabled);
      _luaPlugins.add(manifest);
      _installDirs[manifest.id] = dir;
      Logger.debugFrontend('[plugins] lua loaded: $loadedId');
    } catch (e) {
      Logger.errorPlayerProvider('[plugins] lua load error ${manifest.id}: $e');
    }
  }

  Future<bool> loadFromDir(Directory dir) async {
    final before = loadedManifests.length;
    await _tryLoadFromDir(dir);
    return loadedManifests.length > before;
  }

  Future<void> setEnabled(String pluginId, {required bool enabled}) async {
    final wIdx = _webhooks.indexWhere((e) => e.manifest.id == pluginId);
    if (wIdx != -1) {
      _webhooks[wIdx].enabled = enabled;
      await _persistEnabled(pluginId, enabled);
      return;
    }

    if (_luaPlugins.any((m) => m.id == pluginId)) {
      try {
        backend.pluginSetEnabled(id: pluginId, enabled: enabled);
        await _persistEnabled(pluginId, enabled);
      } catch (e) {
        Logger.errorPlayerProvider('[plugins/lua] setEnabled($pluginId): $e');
      }
    }
  }

  Future<bool> uninstall(String pluginId) async {
    final wIdx = _webhooks.indexWhere((e) => e.manifest.id == pluginId);
    final isLua = _luaPlugins.any((m) => m.id == pluginId);
    if (wIdx == -1 && !isLua) return false;

    if (wIdx != -1) {
      _webhooks.removeAt(wIdx);
    } else {
      try {
        backend.pluginUnload(id: pluginId);
      } catch (e) {
        Logger.errorPlayerProvider('[plugins/lua] unload($pluginId): $e');
      }
      _luaPlugins.removeWhere((m) => m.id == pluginId);
    }

    final dir = await findInstallDir(pluginId);
    _installDirs.remove(pluginId);
    await _removeEnabled(pluginId);

    var deleted = false;
    if (dir != null) {
      try {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          deleted = true;
        }
      } catch (e) {
        Logger.errorPlayerProvider('[plugins] uninstall delete failed: $e');
      }
    }

    try {
      final root = await pluginsDir();
      final safeName = pluginId.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final conventional = Directory('${root.path}/$safeName');
      if (await conventional.exists()) {
        await conventional.delete(recursive: true);
        deleted = true;
      }
    } catch (e) {
      Logger.errorPlayerProvider('[plugins] uninstall cleanup failed: $e');
    }

    Logger.debugFrontend(
      '[plugins] uninstalled: $pluginId (disk=${deleted ? "ok" : "miss"})',
    );
    return true;
  }

  Future<Directory?> findInstallDir(String pluginId) async {
    final cached = _installDirs[pluginId];
    if (cached != null && await cached.exists()) return cached;

    final root = await pluginsDir();
    if (!await root.exists()) return null;

    try {
      for (final entry in root.listSync()) {
        if (entry is! Directory) continue;
        final manifestFile = await _locateManifest(entry);
        if (manifestFile == null) continue;
        try {
          final raw = jsonDecode(await manifestFile.readAsString());
          final id = (raw as Map<String, dynamic>)['id'] as String?;
          if (id == pluginId) {
            return Directory(p.dirname(manifestFile.path));
          }
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  Future<void> dispose() async {
    for (final m in _luaPlugins) {
      try {
        backend.pluginUnload(id: m.id);
      } catch (e) {
        Logger.errorPlayerProvider('[plugins/lua] dispose(${m.id}): $e');
      }
    }
    _webhooks.clear();
    _luaPlugins.clear();
    _installDirs.clear();
  }

  Future<void> dispatchTrackStart(TrackStartEvent event) async {
    await _dispatchWebhook(
      WebhookEvent.trackStart,
      WebhookDispatcher.trackPayload(event.track),
    );
    await _dispatchLua(
      () => backend.pluginDispatchTrackStart(
        title: event.track.displayTitle,
        artist: event.track.displayArtist,
        album: event.track.album,
        durationSecs: event.track.durationSecs,
        path: event.track.path,
      ),
    );
  }

  Future<void> dispatchTrackStop(TrackStopEvent event) async {
    if (event.track != null) {
      await _dispatchWebhook(
        WebhookEvent.trackStop,
        WebhookDispatcher.trackPayload(event.track!),
      );
    } else {
      await _dispatchWebhook(WebhookEvent.trackStop, {});
    }
    await _dispatchLua(
      () => backend.pluginDispatchTrackStop(
        title: event.track?.displayTitle,
        artist: event.track?.displayArtist,
      ),
    );
  }

  Future<void> dispatchPlayPause(PlayPauseEvent event) async {
    await _dispatchWebhook(
      WebhookEvent.playPause,
      WebhookDispatcher.playPausePayload(event.isPlaying, event.position),
    );
    await _dispatchLua(
      () => backend.pluginDispatchPlayPause(
        isPlaying: event.isPlaying,
        positionSecs: event.position.inMilliseconds / 1000.0,
      ),
    );
  }

  Future<void> dispatchPositionUpdate(PositionUpdateEvent event) async {
    final now = DateTime.now();
    if (_lastPositionDispatch != null &&
        now.difference(_lastPositionDispatch!) < const Duration(seconds: 1)) {
      return;
    }
    _lastPositionDispatch = now;

    await _dispatchWebhook(
      WebhookEvent.positionUpdate,
      WebhookDispatcher.positionPayload(event.position, event.duration),
    );
    final durationMs = event.duration.inMilliseconds;
    await _dispatchLua(
      () => backend.pluginDispatchPositionUpdate(
        positionSecs: event.position.inMilliseconds / 1000.0,
        durationSecs: durationMs / 1000.0,
        progress: durationMs > 0
            ? event.position.inMilliseconds / durationMs
            : 0.0,
      ),
    );
  }

  Future<void> dispatchTrackComplete(TrackCompleteEvent event) async {
    await _dispatchWebhook(
      WebhookEvent.trackComplete,
      WebhookDispatcher.trackPayload(event.track),
    );
    await _dispatchLua(
      () => backend.pluginDispatchTrackComplete(
        title: event.track.displayTitle,
        artist: event.track.displayArtist,
        durationSecs: event.track.durationSecs,
        path: event.track.path,
      ),
    );
  }

  Future<void> dispatchLibraryScan(LibraryScanEvent event) async {
    switch (event.phase) {
      case LibraryScanPhase.started:
        await _dispatchLua(backend.pluginDispatchLibraryScanStart);
      case LibraryScanPhase.complete:
        await _dispatchLua(
          () => backend.pluginDispatchLibraryScanComplete(
            total: event.count ?? 0,
          ),
        );
    }
  }

  Future<void> dispatchTrackLoved(TrackLovedEvent event) async {
    await _dispatchWebhook(
      WebhookEvent.trackLoved,
      WebhookDispatcher.lovedPayload(event.track, event.loved),
    );
    await _dispatchLua(
      () => backend.pluginDispatchTrackLoved(
        title: event.track.displayTitle,
        artist: event.track.displayArtist,
        loved: event.loved,
      ),
    );
  }

  Future<void> dispatchAppForeground(AppForegroundEvent event) async {
    await _dispatchLua(backend.pluginDispatchAppForeground);
  }

  Future<void> _dispatchWebhook(
    WebhookEvent event,
    Map<String, dynamic> payload,
  ) async {
    for (final e in _webhooks.where((e) => e.enabled)) {
      WebhookDispatcher.instance.dispatch(e.manifest, event, payload);
    }
  }

  Future<void> _dispatchLua(Future<void> Function() call) async {
    if (_luaPlugins.isEmpty) return;
    try {
      await call();
    } catch (e) {
      Logger.errorPlayerProvider('[plugins/lua] dispatch failed: $e');
    }
  }

  Future<Directory> pluginsDir() async {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      final home =
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      return Directory('$home/.aqloss/plugins');
    }
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/plugins');
  }

  Future<bool> _isEnabled(String id) async {
    try {
      final f = await _stateFile();
      if (!await f.exists()) return true;
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return (raw[id] as bool?) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _persistEnabled(String id, bool enabled) async {
    try {
      final f = await _stateFile();
      Map<String, dynamic> raw = {};
      if (await f.exists()) {
        raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      }
      raw[id] = enabled;
      await f.writeAsString(jsonEncode(raw));
    } catch (_) {}
  }

  Future<void> _removeEnabled(String id) async {
    try {
      final f = await _stateFile();
      if (!await f.exists()) return;
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      raw.remove(id);
      await f.writeAsString(jsonEncode(raw));
    } catch (_) {}
  }

  Future<File> _stateFile() async {
    final support = await getApplicationSupportDirectory();
    return File('${support.path}/plugin_state.json');
  }
}

class _WebhookEntry {
  final PluginManifest manifest;
  bool enabled;
  _WebhookEntry({required this.manifest, required this.enabled});

  static final sentinel = _WebhookEntry(
    manifest: PluginManifest(
      id: '',
      name: '',
      version: '',
      author: '',
      minAqlossVersion: '',
    ),
    enabled: false,
  );
}
