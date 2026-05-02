import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/providers/settings_provider.dart';

class AudioDeviceEntry {
  final String id;
  final String name;
  final bool isDefault;
  final bool supportsExclusive;

  const AudioDeviceEntry({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.supportsExclusive,
  });
}

class AudioDeviceState {
  final List<AudioDeviceEntry> devices;
  final String? selectedId;
  final AudioOutputMode outputMode;
  final bool isSwitching;

  const AudioDeviceState({
    this.devices = const [],
    this.selectedId,
    this.outputMode = AudioOutputMode.exclusive,
    this.isSwitching = false,
  });

  AudioDeviceEntry? get selectedDevice =>
      devices.where((d) => d.id == selectedId).firstOrNull;

  AudioDeviceState copyWith({
    List<AudioDeviceEntry>? devices,
    String? selectedId,
    AudioOutputMode? outputMode,
    bool? isSwitching,
  }) => AudioDeviceState(
    devices: devices ?? this.devices,
    selectedId: selectedId ?? this.selectedId,
    outputMode: outputMode ?? this.outputMode,
    isSwitching: isSwitching ?? this.isSwitching,
  );
}

class AudioDeviceNotifier extends AsyncNotifier<AudioDeviceState> {
  @override
  Future<AudioDeviceState> build() async {
    final settings = ref.read(settingsProvider);
    return AudioDeviceState(
      selectedId: settings.selectedDeviceId,
      outputMode: settings.outputMode,
    );
  }

  Future<void> scan() async {
    final current = state.value ?? const AudioDeviceState();
    state = AsyncValue.data(current.copyWith(isSwitching: true));

    try {
      final raw = await Future(
        () => backend.enumerateAudioDevices(),
      ).timeout(const Duration(seconds: 10));

      final entries = raw
          .map(
            (d) => AudioDeviceEntry(
              id: d.id,
              name: d.name,
              isDefault: d.isDefault,
              supportsExclusive: d.supportsExclusive,
            ),
          )
          .toList();

      final savedId = ref.read(settingsProvider).selectedDeviceId;
      final found = entries.any((d) => d.id == savedId);
      final activeId = found
          ? savedId
          : entries.where((d) => d.isDefault).firstOrNull?.id;

      state = AsyncValue.data(
        current.copyWith(
          devices: entries,
          selectedId: activeId,
          isSwitching: false,
        ),
      );
    } catch (e, st) {
      debugPrint('[AudioDeviceProvider] scan error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> selectDevice(String deviceId, AudioOutputMode mode) async {
    final current = state.value ?? const AudioDeviceState();
    state = AsyncValue.data(current.copyWith(isSwitching: true));

    try {
      final exclusive = mode == AudioOutputMode.exclusive;
      await Future(
        () => backend.reinitEngine(deviceId: deviceId, exclusive: exclusive),
      ).timeout(const Duration(seconds: 8));

      ref.read(settingsProvider.notifier).setAudioDevice(deviceId, mode);

      state = AsyncValue.data(
        current.copyWith(
          selectedId: deviceId,
          outputMode: mode,
          isSwitching: false,
        ),
      );
    } catch (e) {
      debugPrint('[AudioDeviceProvider] selectDevice error: $e');
      state = AsyncValue.data(current.copyWith(isSwitching: false));
      rethrow;
    }
  }
}

final audioDeviceProvider =
    AsyncNotifierProvider<AudioDeviceNotifier, AudioDeviceState>(
      AudioDeviceNotifier.new,
    );
