abstract final class M3Route {
  static const player = 0;
  static const library = 1;
  static const albums = 2;
  static const settings = 3;
  static const history = 4;
  static const artists = 5;
  static const playlistBase = 10;

  static int? railIndexFor(int route) {
    if (route >= playlistBase) return null;
    return switch (route) {
      player => 0,
      library => 1,
      albums => 2,
      artists => 3,
      history => 4,
      settings => 5,
      _ => 0,
    };
  }

  static int routeForRailIndex(int index) => switch (index) {
    0 => player,
    1 => library,
    2 => albums,
    3 => artists,
    4 => history,
    5 => settings,
    _ => player,
  };

  static String titleFor(int route) => switch (route) {
    player => 'Now Playing',
    library => 'Library',
    albums => 'Albums',
    settings => 'Settings',
    history => 'History',
    artists => 'Artists',
    _ when route >= playlistBase => 'Playlist',
    _ => 'Aqloss',
  };
}
