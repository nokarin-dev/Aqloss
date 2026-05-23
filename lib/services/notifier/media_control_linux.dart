import 'dart:io';
import 'dart:typed_data';
import 'package:dbus/dbus.dart';

class MediaControlPlatform {
  static DBusClient? _client;
  static _MprisObject? _obj;
  static String _artPath = '/tmp/aqloss_mpris_cover.jpg';

  static Future<void> init({
    required void Function() onPlay,
    required void Function() onPause,
    required void Function() onNext,
    required void Function() onPrevious,
    required void Function(Duration) onSeek,
  }) async {
    try {
      _client = DBusClient.session();
      _obj = _MprisObject(
        onPlay: onPlay,
        onPause: onPause,
        onNext: onNext,
        onPrevious: onPrevious,
        onSeek: onSeek,
      );
      await _client!.registerObject(_obj!);
      await _client!.requestName('org.mpris.MediaPlayer2.aqloss');
    } catch (e) {
      _client = null;
      _obj = null;
    }
  }

  static Future<void> update({
    required String title,
    required String artist,
    required String album,
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    Uint8List? artBytes,
  }) async {
    final obj = _obj;
    if (obj == null) return;

    String artUrl = '';
    if (artBytes != null) {
      try {
        final hash = (title + artist).hashCode.abs();
        _artPath = '/tmp/aqloss_cover_$hash.jpg';
        await File(_artPath).writeAsBytes(artBytes);
        artUrl = Uri.file(_artPath).toString();
      } catch (_) {}
    }

    await obj.updatePlayback(
      title: title,
      artist: artist,
      album: album,
      isPlaying: isPlaying,
      position: position,
      duration: duration,
      artUrl: artUrl,
    );
  }

  static void clear() {
    _obj?.clearPlayback();
  }

  static void dispose() {
    _obj = null;
    _client?.close();
    _client = null;
  }
}

// D-Bus object
class _MprisObject extends DBusObject {
  final void Function() onPlay;
  final void Function() onPause;
  final void Function() onNext;
  final void Function() onPrevious;
  final void Function(Duration) onSeek;

  // Internal state
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Map<String, DBusValue> _metadata = {
    'mpris:trackid': DBusObjectPath('/org/aqloss/track/0'),
  };

  _MprisObject({
    required this.onPlay,
    required this.onPause,
    required this.onNext,
    required this.onPrevious,
    required this.onSeek,
  }) : super(DBusObjectPath('/org/mpris/MediaPlayer2'));

  // Interface declarations
  @override
  List<DBusIntrospectInterface> introspect() => [
    DBusIntrospectInterface(
      'org.mpris.MediaPlayer2',
      properties: [
        DBusIntrospectProperty(
          'CanQuit',
          DBusSignature('b'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'CanRaise',
          DBusSignature('b'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'HasTrackList',
          DBusSignature('b'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'Identity',
          DBusSignature('s'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'DesktopEntry',
          DBusSignature('s'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'SupportedUriSchemes',
          DBusSignature('as'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'SupportedMimeTypes',
          DBusSignature('as'),
          access: DBusPropertyAccess.read,
        ),
      ],
      methods: [DBusIntrospectMethod('Raise'), DBusIntrospectMethod('Quit')],
    ),
    DBusIntrospectInterface(
      'org.mpris.MediaPlayer2.Player',
      properties: [
        DBusIntrospectProperty(
          'PlaybackStatus',
          DBusSignature('s'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'LoopStatus',
          DBusSignature('s'),
          access: DBusPropertyAccess.readwrite,
        ),
        DBusIntrospectProperty(
          'Rate',
          DBusSignature('d'),
          access: DBusPropertyAccess.readwrite,
        ),
        DBusIntrospectProperty(
          'Shuffle',
          DBusSignature('b'),
          access: DBusPropertyAccess.readwrite,
        ),
        DBusIntrospectProperty(
          'Metadata',
          DBusSignature('a{sv}'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'Volume',
          DBusSignature('d'),
          access: DBusPropertyAccess.readwrite,
        ),
        DBusIntrospectProperty(
          'Position',
          DBusSignature('x'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'MinimumRate',
          DBusSignature('d'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'MaximumRate',
          DBusSignature('d'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'CanGoNext',
          DBusSignature('b'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'CanGoPrevious',
          DBusSignature('b'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'CanPlay',
          DBusSignature('b'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'CanPause',
          DBusSignature('b'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'CanSeek',
          DBusSignature('b'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'CanControl',
          DBusSignature('b'),
          access: DBusPropertyAccess.read,
        ),
      ],
      methods: [
        DBusIntrospectMethod('Next'),
        DBusIntrospectMethod('Previous'),
        DBusIntrospectMethod('Pause'),
        DBusIntrospectMethod('PlayPause'),
        DBusIntrospectMethod('Stop'),
        DBusIntrospectMethod('Play'),
        DBusIntrospectMethod(
          'Seek',
          args: [
            DBusIntrospectArgument(
              DBusSignature('x'),
              DBusArgumentDirection.in_,
              name: 'Offset',
            ),
          ],
        ),
        DBusIntrospectMethod(
          'SetPosition',
          args: [
            DBusIntrospectArgument(
              DBusSignature('o'),
              DBusArgumentDirection.in_,
              name: 'TrackId',
            ),
            DBusIntrospectArgument(
              DBusSignature('x'),
              DBusArgumentDirection.in_,
              name: 'Position',
            ),
          ],
        ),
        DBusIntrospectMethod(
          'OpenUri',
          args: [
            DBusIntrospectArgument(
              DBusSignature('s'),
              DBusArgumentDirection.in_,
              name: 'Uri',
            ),
          ],
        ),
      ],
    ),
  ];

  // Property reads
  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    if (interface == 'org.mpris.MediaPlayer2') {
      return switch (name) {
        'CanQuit' => DBusGetPropertyResponse(DBusBoolean(false)),
        'CanRaise' => DBusGetPropertyResponse(DBusBoolean(false)),
        'HasTrackList' => DBusGetPropertyResponse(DBusBoolean(false)),
        'Identity' => DBusGetPropertyResponse(DBusString('Aqloss')),
        'DesktopEntry' => DBusGetPropertyResponse(
          DBusString('xyz.nokarin.aqloss'),
        ),
        'SupportedUriSchemes' => DBusGetPropertyResponse(DBusArray.string([])),
        'SupportedMimeTypes' => DBusGetPropertyResponse(DBusArray.string([])),
        _ => DBusMethodErrorResponse.failed(),
      };
    }

    if (interface == 'org.mpris.MediaPlayer2.Player') {
      return switch (name) {
        'PlaybackStatus' => DBusGetPropertyResponse(
          DBusString(_isPlaying ? 'Playing' : 'Paused'),
        ),
        'LoopStatus' => DBusGetPropertyResponse(DBusString('None')),
        'Rate' => DBusGetPropertyResponse(DBusDouble(1.0)),
        'Shuffle' => DBusGetPropertyResponse(DBusBoolean(false)),
        'Metadata' => DBusGetPropertyResponse(_buildMetadata()),
        'Volume' => DBusGetPropertyResponse(DBusDouble(1.0)),
        'Position' => DBusGetPropertyResponse(
          DBusInt64(_position.inMicroseconds),
        ),
        'MinimumRate' => DBusGetPropertyResponse(DBusDouble(1.0)),
        'MaximumRate' => DBusGetPropertyResponse(DBusDouble(1.0)),
        'CanGoNext' => DBusGetPropertyResponse(DBusBoolean(true)),
        'CanGoPrevious' => DBusGetPropertyResponse(DBusBoolean(true)),
        'CanPlay' => DBusGetPropertyResponse(DBusBoolean(true)),
        'CanPause' => DBusGetPropertyResponse(DBusBoolean(true)),
        'CanSeek' => DBusGetPropertyResponse(DBusBoolean(true)),
        'CanControl' => DBusGetPropertyResponse(DBusBoolean(true)),
        _ => DBusMethodErrorResponse.failed(),
      };
    }

    return DBusMethodErrorResponse.unknownInterface();
  }

  @override
  Future<DBusMethodResponse> setProperty(
    String interface,
    String name,
    DBusValue value,
  ) async {
    if (interface == 'org.mpris.MediaPlayer2.Player') {
      if (name == 'Volume') return DBusMethodSuccessResponse();
      if (name == 'LoopStatus') return DBusMethodSuccessResponse();
      if (name == 'Shuffle') return DBusMethodSuccessResponse();
      if (name == 'Rate') return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.failed();
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    if (interface == 'org.mpris.MediaPlayer2') {
      return DBusGetAllPropertiesResponse({
        'CanQuit': DBusBoolean(false),
        'CanRaise': DBusBoolean(false),
        'HasTrackList': DBusBoolean(false),
        'Identity': DBusString('Aqloss'),
        'DesktopEntry': DBusString('xyz.nokarin.aqloss'),
        'SupportedUriSchemes': DBusArray.string([]),
        'SupportedMimeTypes': DBusArray.string([]),
      });
    }

    if (interface == 'org.mpris.MediaPlayer2.Player') {
      return DBusGetAllPropertiesResponse({
        'PlaybackStatus': DBusString(_isPlaying ? 'Playing' : 'Paused'),
        'LoopStatus': DBusString('None'),
        'Rate': DBusDouble(1.0),
        'Shuffle': DBusBoolean(false),
        'Metadata': _buildMetadata(),
        'Volume': DBusDouble(1.0),
        'Position': DBusInt64(_position.inMicroseconds),
        'MinimumRate': DBusDouble(1.0),
        'MaximumRate': DBusDouble(1.0),
        'CanGoNext': DBusBoolean(true),
        'CanGoPrevious': DBusBoolean(true),
        'CanPlay': DBusBoolean(true),
        'CanPause': DBusBoolean(true),
        'CanSeek': DBusBoolean(true),
        'CanControl': DBusBoolean(true),
      });
    }

    return DBusMethodErrorResponse.unknownInterface();
  }

  // Method calls
  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface == 'org.mpris.MediaPlayer2') {
      if (methodCall.name == 'Raise') return DBusMethodSuccessResponse();
      if (methodCall.name == 'Quit') return DBusMethodSuccessResponse();
    }

    if (methodCall.interface == 'org.mpris.MediaPlayer2.Player') {
      switch (methodCall.name) {
        case 'Play':
          onPlay();
          return DBusMethodSuccessResponse();
        case 'Pause':
          onPause();
          return DBusMethodSuccessResponse();
        case 'PlayPause':
          if (_isPlaying) {
            onPause();
          } else {
            onPlay();
          }
          return DBusMethodSuccessResponse();
        case 'Stop':
          onPause();
          return DBusMethodSuccessResponse();
        case 'Next':
          onNext();
          return DBusMethodSuccessResponse();
        case 'Previous':
          onPrevious();
          return DBusMethodSuccessResponse();
        case 'Seek':
          final offsetUs = (methodCall.values.first as DBusInt64).value;
          final newUs = (_position.inMicroseconds + offsetUs).clamp(
            0,
            _duration.inMicroseconds,
          );
          onSeek(Duration(microseconds: newUs));
          return DBusMethodSuccessResponse();
        case 'SetPosition':
          final posUs = (methodCall.values[1] as DBusInt64).value;
          onSeek(
            Duration(microseconds: posUs.clamp(0, _duration.inMicroseconds)),
          );
          return DBusMethodSuccessResponse();
        case 'OpenUri':
          return DBusMethodSuccessResponse();
      }
    }

    return DBusMethodErrorResponse.unknownMethod();
  }

  // State updates
  Future<void> updatePlayback({
    required String title,
    required String artist,
    required String album,
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    required String artUrl,
  }) async {
    final wasPlaying = _isPlaying;
    _isPlaying = isPlaying;
    _position = position;
    _duration = duration;
    _metadata = {
      'mpris:trackid': DBusObjectPath('/org/aqloss/track/1'),
      'mpris:length': DBusInt64(duration.inMicroseconds),
      'xesam:title': DBusString(title),
      'xesam:artist': DBusArray.string([artist]),
      'xesam:album': DBusString(album),
      if (artUrl.isNotEmpty) 'mpris:artUrl': DBusString(artUrl),
    };

    await emitPropertiesChanged(
      'org.mpris.MediaPlayer2.Player',
      changedProperties: {
        'PlaybackStatus': DBusString(_isPlaying ? 'Playing' : 'Paused'),
        'Metadata': _buildMetadata(),
        'Position': DBusInt64(_position.inMicroseconds),
      },
    );

    if (wasPlaying != isPlaying) {
      await emitSignal('org.mpris.MediaPlayer2.Player', 'Seeked', [
        DBusInt64(position.inMicroseconds),
      ]);
    }
  }

  Future<void> clearPlayback() async {
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _metadata = {'mpris:trackid': DBusObjectPath('/org/aqloss/track/0')};
    await emitPropertiesChanged(
      'org.mpris.MediaPlayer2.Player',
      changedProperties: {
        'PlaybackStatus': DBusString('Stopped'),
        'Metadata': _buildMetadata(),
      },
    );
  }

  // Build a{sv} dict for Metadata property
  DBusDict _buildMetadata() {
    return DBusDict(
      DBusSignature('s'),
      DBusSignature('v'),
      _metadata.map((k, v) => MapEntry(DBusString(k), DBusVariant(v))),
    );
  }
}
