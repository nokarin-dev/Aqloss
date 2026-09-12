import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/util/mpris_loop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('album and playlist loop both report Playlist', () {
    expect(mprisLoopStatus(LoopMode.off), 'None');
    expect(mprisLoopStatus(LoopMode.track), 'Track');
    expect(mprisLoopStatus(LoopMode.album), 'Playlist');
    expect(mprisLoopStatus(LoopMode.playlist), 'Playlist');
  });

  test('MPRIS Playlist keeps album loop', () {
    expect(loopModeFromMpris('Playlist', LoopMode.album), LoopMode.album);
    expect(loopModeFromMpris('Playlist', LoopMode.off), LoopMode.playlist);
    expect(loopModeFromMpris('Track', LoopMode.album), LoopMode.track);
    expect(loopModeFromMpris('None', LoopMode.track), LoopMode.off);
  });
}
