import 'dart:convert';
import 'dart:io';

import 'package:aqloss/models/track.dart';
import 'package:aqloss/plugins/plugin_api.dart';
import 'package:aqloss/plugins/webhook_dispatcher.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/util/logger.dart';
import 'package:path_provider/path_provider.dart';

// Registry
class PluginRegistry {
  PluginRegistry._();
  static final PluginRegistry instance = PluginRegistry._();

  final List<_BuiltinEntry> _builtins = [];
  final List<_WebhookEntry> _webhooks = [];
  final List<PluginManifest> _luaPlugins = [];
  _AppContextImpl? _appContext;

  // Public queries
  List<PluginManifest> get loadedManifests => [
    ..._builtins.map((e) => e.manifest),
    ..._webhooks.map((e) => e.manifest),
    ..._luaPlugins,
  ];

  bool isEnabled(String id) {
    final b = _builtins.firstWhere(
      (e) => e.manifest.id == id,
      orElse: () => _BuiltinEntry.sentinel,
    );
    if (!identical(b, _BuiltinEntry.sentinel)) return b.enabled;
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

  // Init
  Future<void> init(_AppContextBridge bridge) async {
    _appContext = _AppContextImpl(bridge: bridge);
    await _discoverInstalled();
    Logger.debugFrontend(
      '[plugins] ready - ${_builtins.length} builtin, '
      '${_webhooks.length} webhook, ${_luaPlugins.length} lua',
    );
  }

  // Plugin registration
  void registerBuiltin(
    String id,
    BuiltinPlugin Function() factory,
    PluginManifest manifest,
  ) {
    _builtinFactories[id] = (factory: factory, manifest: manifest);
  }

  Future<void> activateBuiltins() async {
    for (final entry in _builtinFactories.entries) {
      final enabled = await _isEnabled(entry.key);
      final plugin = entry.value.factory();
      final manifest = entry.value.manifest;
      plugin.context = _appContext!;
      plugin.manifest = manifest;
      _builtins.add(
        _BuiltinEntry(plugin: plugin, manifest: manifest, enabled: enabled),
      );
      if (enabled) {
        await _safeCall(entry.key, plugin.onLoad);
        Logger.debugFrontend('[plugins] builtin loaded: ${entry.key}');
      }
    }
  }

  // Discovery
  Future<void> _discoverInstalled() async {
    final dir = await pluginsDir();
    if (!await dir.exists()) return;

    for (final entry in dir.listSync()) {
      if (entry is! Directory) continue;
      await _tryLoadFromDir(entry);
    }
  }

  Future<void> _tryLoadFromDir(Directory dir) async {
    final manifestFile = File('${dir.path}/plugin.json');
    if (!await manifestFile.exists()) return;

    try {
      final raw = jsonDecode(await manifestFile.readAsString());
      final manifest = PluginManifest.fromJson(raw as Map<String, dynamic>);

      if (_builtinFactories.containsKey(manifest.id)) return;

      if (loadedManifests.any((m) => m.id == manifest.id)) return;

      switch (manifest.type) {
        case PluginType.webhook:
          await _loadWebhook(manifest);
        case PluginType.lua:
          await _loadLua(manifest, dir);
        case PluginType.builtin:
          Logger.warnPlayerProvider(
            '[plugins] ${manifest.id}: type "builtin" requires registerBuiltin() '
            'and cannot be loaded from disk - skipped.',
          );
      }
    } catch (e) {
      Logger.errorPlayerProvider('[plugins] load error ${dir.path}: $e');
    }
  }

  Future<void> _loadWebhook(PluginManifest manifest) async {
    if (manifest.webhookUrl == null || manifest.webhookUrl!.isEmpty) {
      Logger.warnPlayerProvider(
        '[plugins] ${manifest.id}: webhook_url kosong - dilewati.',
      );
      return;
    }

    final enabled = await _isEnabled(manifest.id);
    _webhooks.add(_WebhookEntry(manifest: manifest, enabled: enabled));
    Logger.debugFrontend('[plugins] webhook loaded: ${manifest.id}');
  }

  Future<void> _loadLua(PluginManifest manifest, Directory dir) async {
    try {
      final loadedId = await backend.pluginLoad(dirPath: dir.path);
      final enabled = await _isEnabled(manifest.id);
      backend.pluginSetEnabled(id: loadedId, enabled: enabled);
      _luaPlugins.add(manifest);
      Logger.debugFrontend('[plugins] lua loaded: $loadedId');
    } catch (e) {
      Logger.errorPlayerProvider('[plugins] lua load error ${manifest.id}: $e');
    }
  }

  // ─── Hot-load setelah install ─────────────────────────────────────────────

  Future<bool> loadFromDir(Directory dir) async {
    final before = loadedManifests.length;
    await _tryLoadFromDir(dir);
    return loadedManifests.length > before;
  }

  // Enable / disable
  Future<void> setEnabled(String pluginId, {required bool enabled}) async {
    // Builtin
    final bIdx = _builtins.indexWhere((e) => e.manifest.id == pluginId);
    if (bIdx != -1) {
      final entry = _builtins[bIdx];
      if (entry.enabled == enabled) return;
      entry.enabled = enabled;
      await _persistEnabled(pluginId, enabled);
      if (enabled) {
        await _safeCall(pluginId, entry.plugin.onLoad);
      } else {
        await _safeCall(pluginId, entry.plugin.onUnload);
      }
      return;
    }

    // Webhook
    final wIdx = _webhooks.indexWhere((e) => e.manifest.id == pluginId);
    if (wIdx != -1) {
      _webhooks[wIdx].enabled = enabled;
      await _persistEnabled(pluginId, enabled);
      return;
    }

    // Lua
    if (_luaPlugins.any((m) => m.id == pluginId)) {
      try {
        backend.pluginSetEnabled(id: pluginId, enabled: enabled);
        await _persistEnabled(pluginId, enabled);
      } catch (e) {
        Logger.errorPlayerProvider('[plugins/lua] setEnabled($pluginId): $e');
      }
    }
  }

  // Uninstall
  Future<void> uninstall(String pluginId) async {
    final wIdx = _webhooks.indexWhere((e) => e.manifest.id == pluginId);
    final isLua = _luaPlugins.any((m) => m.id == pluginId);
    if (wIdx == -1 && !isLua) return;

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
    await _persistEnabled(pluginId, false);

    try {
      final root = await pluginsDir();
      final safeName = pluginId.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final dir = Directory('${root.path}/$safeName');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      Logger.errorPlayerProvider('[plugins] uninstall delete failed: $e');
    }
    Logger.debugFrontend('[plugins] uninstalled: $pluginId');
  }

  Future<void> dispose() async {
    for (final e in _builtins.where((e) => e.enabled)) {
      await _safeCall(e.manifest.id, e.plugin.onUnload);
    }
    for (final m in _luaPlugins) {
      try {
        backend.pluginUnload(id: m.id);
      } catch (e) {
        Logger.errorPlayerProvider('[plugins/lua] dispose(${m.id}): $e');
      }
    }
    _builtins.clear();
    _webhooks.clear();
    _luaPlugins.clear();
  }

  // Hook dispatch
  Future<void> dispatchTrackStart(TrackStartEvent event) async {
    await _dispatchBuiltin((p) => p.onTrackStart(event));
    await _dispatchWebhook(
      WebhookEvent.trackStart,
      WebhookDispatcher.trackPayload(event.track),
    );
    _dispatchLua(
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
    await _dispatchBuiltin((p) => p.onTrackStop(event));
    if (event.track != null) {
      await _dispatchWebhook(
        WebhookEvent.trackStop,
        WebhookDispatcher.trackPayload(event.track!),
      );
    } else {
      await _dispatchWebhook(WebhookEvent.trackStop, {});
    }
    _dispatchLua(
      () => backend.pluginDispatchTrackStop(
        title: event.track?.displayTitle,
        artist: event.track?.displayArtist,
      ),
    );
  }

  Future<void> dispatchPlayPause(PlayPauseEvent event) async {
    await _dispatchBuiltin((p) => p.onPlayPause(event));
    await _dispatchWebhook(
      WebhookEvent.playPause,
      WebhookDispatcher.playPausePayload(event.isPlaying, event.position),
    );
    _dispatchLua(
      () => backend.pluginDispatchPlayPause(
        isPlaying: event.isPlaying,
        positionSecs: event.position.inMilliseconds / 1000.0,
      ),
    );
  }

  Future<void> dispatchPositionUpdate(PositionUpdateEvent event) async {
    await _dispatchBuiltin((p) => p.onPositionUpdate(event));
    await _dispatchWebhook(
      WebhookEvent.positionUpdate,
      WebhookDispatcher.positionPayload(event.position, event.duration),
    );
    final durationMs = event.duration.inMilliseconds;
    _dispatchLua(
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
    await _dispatchBuiltin((p) => p.onTrackComplete(event));
    await _dispatchWebhook(
      WebhookEvent.trackComplete,
      WebhookDispatcher.trackPayload(event.track),
    );
    _dispatchLua(
      () => backend.pluginDispatchTrackComplete(
        title: event.track.displayTitle,
        artist: event.track.displayArtist,
        durationSecs: event.track.durationSecs,
        path: event.track.path,
      ),
    );
  }

  Future<void> dispatchLibraryScan(LibraryScanEvent event) async {
    await _dispatchBuiltin((p) => p.onLibraryScan(event));
    switch (event.phase) {
      case LibraryScanPhase.started:
        _dispatchLua(backend.pluginDispatchLibraryScanStart);
      case LibraryScanPhase.complete:
        _dispatchLua(
          () => backend.pluginDispatchLibraryScanComplete(
            total: event.count ?? 0,
          ),
        );
    }
  }

  Future<void> dispatchTrackLoved(TrackLovedEvent event) async {
    await _dispatchBuiltin((p) => p.onTrackLoved(event));
    await _dispatchWebhook(
      WebhookEvent.trackLoved,
      WebhookDispatcher.lovedPayload(event.track, event.loved),
    );
    _dispatchLua(
      () => backend.pluginDispatchTrackLoved(
        title: event.track.displayTitle,
        artist: event.track.displayArtist,
        loved: event.loved,
      ),
    );
  }

  Future<void> dispatchAppForeground(AppForegroundEvent event) async {
    await _dispatchBuiltin((p) => p.onAppForeground(event));
    _dispatchLua(backend.pluginDispatchAppForeground);
  }

  Future<void> _dispatchBuiltin(
    Future<void> Function(BuiltinPlugin) hook,
  ) async {
    for (final e in _builtins.where((e) => e.enabled)) {
      await _safeCall(e.manifest.id, () => hook(e.plugin));
    }
  }

  Future<void> _dispatchWebhook(
    WebhookEvent event,
    Map<String, dynamic> payload,
  ) async {
    for (final e in _webhooks.where((e) => e.enabled)) {
      WebhookDispatcher.instance.dispatch(e.manifest, event, payload);
    }
  }

  void _dispatchLua(void Function() call) {
    if (_luaPlugins.isEmpty) return;
    try {
      call();
    } catch (e) {
      Logger.errorPlayerProvider('[plugins/lua] dispatch failed: $e');
    }
  }

  // UI registrations
  List<PluginSidebarItem> get sidebarItems => _appContext?._sidebarItems ?? [];
  List<PluginSettingsPage> get settingsPages =>
      _appContext?._settingsPages ?? [];
  List<PluginContextMenuItem> get contextMenuItems =>
      _appContext?._contextMenuItems ?? [];

  // Persistence
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

  Future<File> _stateFile() async {
    final support = await getApplicationSupportDirectory();
    return File('${support.path}/plugin_state.json');
  }

  Future<void> _safeCall(String id, Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      Logger.errorPlayerProvider('[plugins] error in $id: $e');
    }
  }
}

// Entries
class _BuiltinEntry {
  final BuiltinPlugin plugin;
  final PluginManifest manifest;
  bool enabled;
  _BuiltinEntry({
    required this.plugin,
    required this.manifest,
    required this.enabled,
  });

  static final sentinel = _BuiltinEntry(
    plugin: _SentinelPlugin(),
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

class _SentinelPlugin extends BuiltinPlugin {}

// Factory map
final Map<String, ({BuiltinPlugin Function() factory, PluginManifest manifest})>
_builtinFactories = {};

// App context bridge
abstract class _AppContextBridge {
  Track? getCurrentTrack();
  Duration getPosition();
  List<Track> getQueue();
  void addToQueue(Track track);
  List<Track> getAllTracks();
  Set<String> getLovedPaths();
  int getPlayCount(String path);
  void showToast(String message);
}

class _AppContextImpl implements PluginContext {
  final _AppContextBridge bridge;
  final List<PluginSidebarItem> _sidebarItems = [];
  final List<PluginSettingsPage> _settingsPages = [];
  final List<PluginContextMenuItem> _contextMenuItems = [];

  _AppContextImpl({required this.bridge});

  @override
  Track? getCurrentTrack() => bridge.getCurrentTrack();
  @override
  Duration getPosition() => bridge.getPosition();
  @override
  List<Track> getQueue() => bridge.getQueue();
  @override
  void addToQueue(Track t) => bridge.addToQueue(t);
  @override
  List<Track> queryTracks(bool Function(Track) p) =>
      bridge.getAllTracks().where(p).toList();
  @override
  List<Track> getLovedTracks() {
    final loved = bridge.getLovedPaths();
    return bridge.getAllTracks().where((t) => loved.contains(t.path)).toList();
  }

  @override
  int getPlayCount(String path) => bridge.getPlayCount(path);
  @override
  void showToast(String msg) => bridge.showToast(msg);

  @override
  void registerSidebarItem(PluginSidebarItem item) {
    _sidebarItems.removeWhere((i) => i.id == item.id);
    _sidebarItems.add(item);
  }

  @override
  void registerSettingsPage(PluginSettingsPage page) {
    _settingsPages.removeWhere((p) => p.id == page.id);
    _settingsPages.add(page);
  }

  @override
  void registerContextMenuItem(PluginContextMenuItem item) {
    _contextMenuItems.removeWhere((i) => i.id == item.id);
    _contextMenuItems.add(item);
  }
}

// Public bridge class
class AppContextBridge implements _AppContextBridge {
  final Track? Function() _getCurrentTrack;
  final Duration Function() _getPosition;
  final List<Track> Function() _getQueue;
  final void Function(Track) _addToQueue;
  final List<Track> Function() _getAllTracks;
  final Set<String> Function() _getLovedPaths;
  final int Function(String) _getPlayCount;
  final void Function(String) _showToast;

  const AppContextBridge({
    required Track? Function() getCurrentTrack,
    required Duration Function() getPosition,
    required List<Track> Function() getQueue,
    required void Function(Track) addToQueue,
    required List<Track> Function() getAllTracks,
    required Set<String> Function() getLovedPaths,
    required int Function(String) getPlayCount,
    required void Function(String) showToast,
  }) : _getCurrentTrack = getCurrentTrack,
       _getPosition = getPosition,
       _getQueue = getQueue,
       _addToQueue = addToQueue,
       _getAllTracks = getAllTracks,
       _getLovedPaths = getLovedPaths,
       _getPlayCount = getPlayCount,
       _showToast = showToast;

  @override
  Track? getCurrentTrack() => _getCurrentTrack();
  @override
  Duration getPosition() => _getPosition();
  @override
  List<Track> getQueue() => _getQueue();
  @override
  void addToQueue(Track t) => _addToQueue(t);
  @override
  List<Track> getAllTracks() => _getAllTracks();
  @override
  Set<String> getLovedPaths() => _getLovedPaths();
  @override
  int getPlayCount(String p) => _getPlayCount(p);
  @override
  void showToast(String msg) => _showToast(msg);
}
