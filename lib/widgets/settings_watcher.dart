import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/services/audio_service.dart';

class SettingsWatcher extends ConsumerStatefulWidget {
  final Widget child;
  const SettingsWatcher({super.key, required this.child});

  @override
  ConsumerState<SettingsWatcher> createState() => _SettingsWatcherState();
}

class _SettingsWatcherState extends ConsumerState<SettingsWatcher> {
  SettingsState? _prev;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSettings(s));
    return widget.child;
  }

  Future<void> _onSettings(SettingsState s) async {
    if (!s.loaded) return;
    final prev = _prev;
    _prev = s;

    // Soft clip limiter
    if (prev == null || prev.notchFilter != s.notchFilter) {
      await AudioService.applyDspSettings(s);
    }

    // Skip silence
    if (prev == null || prev.skipSilence != s.skipSilence) {
      await AudioService.applyDspSettings(s);
    }

    // ReplayGain mode & preamp
    if (prev == null ||
        prev.replayGainMode != s.replayGainMode ||
        prev.replayGainPreamp != s.replayGainPreamp) {
      final track = ref.read(playerProvider).currentTrack;
      if (track != null && s.replayGainEnabled) {
        await AudioService.applyReplayGainForTrack(
          mode: s.replayGainMode,
          preampDb: s.replayGainPreamp,
          trackGainDb: track.replayGainTrack,
          albumGainDb: track.replayGainAlbum,
        );
      } else if (!s.replayGainEnabled) {
        await AudioService.applyReplayGainForTrack(
          mode: ReplayGainMode.off,
          preampDb: 0,
        );
      }
    }
  }
}
