import 'package:aqloss/providers/player_provider.dart';

String mprisLoopStatus(LoopMode mode) => switch (mode) {
  LoopMode.off => 'None',
  LoopMode.track => 'Track',
  LoopMode.album || LoopMode.playlist => 'Playlist',
};

LoopMode loopModeFromMpris(String status, LoopMode current) => switch (status) {
  'Track' => LoopMode.track,
  'Playlist' => current == LoopMode.album ? LoopMode.album : LoopMode.playlist,
  _ => LoopMode.off,
};
