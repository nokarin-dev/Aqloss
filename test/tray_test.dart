import 'package:aqloss/util/tray.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tray tooltip uses the track, then Aqloss', () {
    expect(trayTooltip(), 'Aqloss');
    expect(trayTooltip(title: '  '), 'Aqloss');
    expect(trayTooltip(title: 'Helplessness Blues'), 'Helplessness Blues');
    expect(
      trayTooltip(title: 'Helplessness Blues', artist: 'Fleet Foxes'),
      'Helplessness Blues — Fleet Foxes',
    );
  });

  test('play pause label follows playback', () {
    expect(trayPlayPauseLabel(true), 'Pause');
    expect(trayPlayPauseLabel(false), 'Play');
  });
}
