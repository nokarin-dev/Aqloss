import 'package:aqloss/plugins/plugin_api.dart';
import 'package:aqloss/plugins/plugin_io_service.dart';
import 'package:aqloss/plugins/plugin_registry.dart';
import 'package:flutter_riverpod/legacy.dart';

// State
class PluginState {
  final List<PluginManifest> manifests;
  final Map<String, bool> enabledMap;
  final bool installing;

  const PluginState({
    this.manifests = const [],
    this.enabledMap = const {},
    this.installing = false,
  });

  bool isEnabled(String id) => enabledMap[id] ?? true;

  PluginState copyWith({
    List<PluginManifest>? manifests,
    Map<String, bool>? enabledMap,
    bool? installing,
  }) => PluginState(
    manifests: manifests ?? this.manifests,
    enabledMap: enabledMap ?? this.enabledMap,
    installing: installing ?? this.installing,
  );
}

// Notifier
class PluginNotifier extends StateNotifier<PluginState> {
  PluginNotifier() : super(const PluginState()) {
    _sync();
  }

  void _sync() {
    final registry = PluginRegistry.instance;
    final manifests = registry.loadedManifests;
    final map = {for (final m in manifests) m.id: registry.isEnabled(m.id)};
    state = state.copyWith(
      manifests: manifests,
      enabledMap: map,
      installing: false,
    );
  }

  Future<void> setEnabled(String id, {required bool enabled}) async {
    await PluginRegistry.instance.setEnabled(id, enabled: enabled);
    final updated = Map<String, bool>.from(state.enabledMap);
    updated[id] = enabled;
    state = state.copyWith(enabledMap: updated);
  }

  Future<PluginImportResult> install() async {
    state = state.copyWith(installing: true);
    final result = await PluginIOService.importFromPicker(); 
    _sync();
    return result;
  }

  Future<void> uninstall(String pluginId) async {
    await PluginRegistry.instance.uninstall(pluginId);
    _sync();
  }

  void refresh() => _sync();
}

final pluginProvider = StateNotifierProvider<PluginNotifier, PluginState>(
  (ref) => PluginNotifier(),
);
