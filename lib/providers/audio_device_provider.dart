import 'package:aqloss/util/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/services/audio_service.dart';
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
      Logger.errorDeviceProvider('scan error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> selectDevice(String deviceId, AudioOutputMode mode) async {
    final current = state.value ?? const AudioDeviceState();
    state = AsyncValue.data(current.copyWith(isSwitching: true));

    try {
      final exclusive = mode == AudioOutputMode.exclusive;
      final ok = await AudioService.reinitToDevice(
        deviceId: deviceId,
        exclusive: exclusive,
      );
      if (!ok) throw Exception('reinitToDevice returned false');

      ref.read(settingsProvider.notifier).setAudioDevice(deviceId, mode);

      state = AsyncValue.data(
        current.copyWith(
          selectedId: deviceId,
          outputMode: mode,
          isSwitching: false,
        ),
      );
    } catch (e) {
      Logger.errorDeviceProvider('selectDevice error: $e');
      state = AsyncValue.data(current.copyWith(isSwitching: false));
      rethrow;
    }
  }

  Future<void> refreshAfterDeviceChange(String? newDefaultId) async {
    try {
      await scan();
      final s = state.value;
      final savedId = ref.read(settingsProvider).selectedDeviceId;
      if (savedId == null && newDefaultId != null && s != null) {
        final found = s.devices.any((d) => d.id == newDefaultId);
        if (found) {
          state = AsyncValue.data(s.copyWith(selectedId: newDefaultId));
        }
      }
    } catch (e) {
      Logger.errorDeviceProvider('refreshAfterDeviceChange: $e');
    }
  }
}

final audioDeviceProvider =
    AsyncNotifierProvider<AudioDeviceNotifier, AudioDeviceState>(
      AudioDeviceNotifier.new,
    );
