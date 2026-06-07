import 'dart:convert';
import 'dart:io';

import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/gestures.dart';

final miniPlayerActiveProvider = StateProvider<bool>((ref) => false);

const kMiniPlayerW = 340.0;
const kMiniPlayerH = 104.0;

const _kCmdChannel = 'aqloss_mini_cmd';
const _kDragChannel = MethodChannel('aqloss/drag');

// Main-side state
WindowController? _ctrl;
bool _visible = false;

// Art cache
String? _cachedArtPath;
String? _cachedArtB64;

Future<String?> _artForPath(String? path) async {
  if (path == null || path.isEmpty) return null;
  if (path == _cachedArtPath) return _cachedArtB64;
  _cachedArtPath = path;
  try {
    final bytes = await backend.readAlbumArtThumbnail(path: path);
    _cachedArtB64 = bytes != null ? base64Encode(bytes) : null;
  } catch (_) {
    _cachedArtB64 = null;
  }
  return _cachedArtB64;
}

Future<void> pushMiniPlayerState(PlayerState player) async {
  if (_ctrl == null || !_visible) return;
  final track = player.currentTrack;
  try {
    await _ctrl!.invokeMethod(
      'state',
      jsonEncode({
        'title': track?.displayTitle ?? '',
        'artist': track?.displayArtist ?? '',
        'isPlaying': player.status == PlayerStatus.playing,
        'positionMs': player.position.inMilliseconds,
        'durationMs': track?.duration.inMilliseconds ?? 0,
        'hasNext': player.hasNext,
        'hasPrev': player.hasPrevious,
      }),
    );
  } catch (_) {}
}

Future<void> _pushArt(String? path) async {
  if (_ctrl == null || !_visible) return;
  final b64 = await _artForPath(path);
  try {
    await _ctrl!.invokeMethod('art', b64 ?? '');
  } catch (_) {}
}

class MiniPlayerWindow {
  MiniPlayerWindow._();

  static bool _busy = false;
  static String? _lastArtPath;

  static Future<void> toggle(BuildContext context) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    if (_busy) return;
    _busy = true;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final notifier = container.read(miniPlayerActiveProvider.notifier);

      if (_visible) {
        await _hide(notifier);
      } else {
        await _show(container, notifier);
      }
    } finally {
      _busy = false;
    }
  }

  static Future<void> _hide(StateController<bool> notifier) async {
    _visible = false;
    notifier.state = false;
    try {
      await _ctrl?.hide();
    } catch (_) {}
    try {
      await WindowMethodChannel(
        _kCmdChannel,
        mode: ChannelMode.unidirectional,
      ).setMethodCallHandler(null);
    } catch (_) {}
  }

  static Future<void> _show(
    ProviderContainer container,
    StateController<bool> notifier,
  ) async {
    if (_ctrl == null) {
      _ctrl = await WindowController.create(
        WindowConfiguration(hiddenAtLaunch: true, arguments: 'mini_player'),
      );

      onWindowsChanged.listen((_) async {
        if (_ctrl == null) return;
        final all = await WindowController.getAll();
        if (!all.any((c) => c.windowId == _ctrl!.windowId)) {
          _ctrl = null;
          _visible = false;
          _lastArtPath = null;
          notifier.state = false;
          try {
            await WindowMethodChannel(
              _kCmdChannel,
              mode: ChannelMode.unidirectional,
            ).setMethodCallHandler(null);
          } catch (_) {}
        }
      });
    }

    await WindowMethodChannel(
      _kCmdChannel,
      mode: ChannelMode.unidirectional,
    ).setMethodCallHandler((call) async {
      final n = container.read(playerProvider.notifier);
      switch (call.method) {
        case 'play':
          n.play();
        case 'pause':
          n.pause();
        case 'next':
          n.skipNext();
        case 'previous':
          n.skipPrevious();
        case 'close':
          await _hide(notifier);
      }
      return null;
    });

    _visible = true;
    notifier.state = true;

    await Future.delayed(const Duration(milliseconds: 300));

    final player = container.read(playerProvider);
    final track = player.currentTrack;
    try {
      await _ctrl!.invokeMethod(
        'state',
        jsonEncode({
          'title': track?.displayTitle ?? '',
          'artist': track?.displayArtist ?? '',
          'isPlaying': player.status == PlayerStatus.playing,
          'positionMs': player.position.inMilliseconds,
          'durationMs': track?.duration.inMilliseconds ?? 0,
          'hasNext': player.hasNext,
          'hasPrev': player.hasPrevious,
        }),
      );
    } catch (_) {}

    _lastArtPath = track?.path;
    await _pushArt(track?.path);

    try {
      await _ctrl!.show();
    } catch (_) {}
  }

  static Future<void> onTrackChanged(String? path) async {
    if (path == _lastArtPath) return;
    _lastArtPath = path;
    await _pushArt(path);
  }
}

class MiniPlayerStandalone extends StatefulWidget {
  const MiniPlayerStandalone({super.key});
  @override
  State<MiniPlayerStandalone> createState() => _MiniState();
}

class _MiniState extends State<MiniPlayerStandalone> {
  // Playback state
  String _title = '';
  String _artist = '';
  bool _playing = false;
  int _posMs = 0;
  int _durMs = 0;
  bool _hasNext = false;
  bool _hasPrev = false;
  PointerDownEvent? _lastPointer;

  // Art
  Uint8List? _art;

  final _cmd = WindowMethodChannel(
    _kCmdChannel,
    mode: ChannelMode.unidirectional,
  );

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ctrl = await WindowController.fromCurrentEngine();
    await ctrl.setWindowMethodHandler((call) async {
      switch (call.method) {
        case 'state':
          _applyState(
            jsonDecode(call.arguments as String) as Map<String, dynamic>,
          );
        case 'art':
          _applyArt(call.arguments as String);
      }
      return null;
    });
  }

  void _applyState(Map<String, dynamic> m) {
    if (!mounted) return;
    setState(() {
      _title = m['title'] as String? ?? '';
      _artist = m['artist'] as String? ?? '';
      _playing = m['isPlaying'] as bool? ?? false;
      _posMs = (m['positionMs'] as num?)?.toInt() ?? 0;
      _durMs = (m['durationMs'] as num?)?.toInt() ?? 0;
      _hasNext = m['hasNext'] as bool? ?? false;
      _hasPrev = m['hasPrev'] as bool? ?? false;
    });
  }

  void _applyArt(String b64) {
    if (!mounted) return;
    Uint8List? bytes;
    if (b64.isNotEmpty) {
      try {
        bytes = base64Decode(b64);
      } catch (_) {}
    }
    if (bytes?.length != _art?.length) {
      setState(() => _art = bytes);
    }
  }

  Future<void> _send(String method) async {
    try {
      await _cmd.invokeMethod(method);
    } catch (_) {}
  }

  Future<void> _drag() async {
    if (Platform.isLinux) {
      try {
        await _kDragChannel.invokeMethod('startDragging');
      } catch (_) {}
    } else {
      try {
        const wm = MethodChannel('com.leanflutter.plugins/window_manager');
        await wm.invokeMethod('startDragging');
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Listener(
          onPointerDown: (e) => _lastPointer = e,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (_) {
              _drag();

              if (Platform.isLinux && _lastPointer != null) {
                Future.microtask(() {
                  GestureBinding.instance.handlePointerEvent(
                    PointerCancelEvent(
                      pointer: _lastPointer!.pointer,
                      position: _lastPointer!.position,
                    ),
                  );
                });
              }
            },
            child: _MiniCard(
              title: _title,
              artist: _artist,
              playing: _playing,
              posMs: _posMs,
              durMs: _durMs,
              hasNext: _hasNext,
              hasPrev: _hasPrev,
              art: _art,
              onSend: _send,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String title;
  final String artist;
  final bool playing;
  final int posMs;
  final int durMs;
  final bool hasNext;
  final bool hasPrev;
  final Uint8List? art;
  final Future<void> Function(String) onSend;

  const _MiniCard({
    required this.title,
    required this.artist,
    required this.playing,
    required this.posMs,
    required this.durMs,
    required this.hasNext,
    required this.hasPrev,
    required this.art,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF111114);

    return Container(
      width: kMiniPlayerW,
      height: kMiniPlayerH,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 28,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Row(
          children: [
            // Album art
            RepaintBoundary(
              child: SizedBox(
                width: kMiniPlayerH,
                height: kMiniPlayerH,
                child: art != null
                    ? Image.memory(
                        art!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : Container(
                        color: Colors.white.withValues(alpha: 0.04),
                        child: Icon(
                          Icons.music_note_rounded,
                          size: 28,
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
              ),
            ),
            // Info + controls
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + close
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.isEmpty ? 'Not playing' : title,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _Btn(
                          icon: Icons.close_rounded,
                          onTap: () => onSend('close'),
                          size: 14,
                          opacity: 0.35,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      artist,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.40),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Progress bars
                    RepaintBoundary(
                      child: _Progress(posMs: posMs, durMs: durMs),
                    ),
                    const SizedBox(height: 7),
                    // Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _Btn(
                          icon: Icons.skip_previous_rounded,
                          onTap: () => onSend('previous'),
                          opacity: hasPrev ? 0.70 : 0.18,
                          size: 20,
                        ),
                        _Btn(
                          icon: playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          onTap: () => onSend(playing ? 'pause' : 'play'),
                          size: 22,
                          opacity: 0.92,
                        ),
                        _Btn(
                          icon: Icons.skip_next_rounded,
                          onTap: () => onSend('next'),
                          opacity: hasNext ? 0.70 : 0.18,
                          size: 20,
                        ),
                        _Btn(
                          icon: Icons.open_in_full_rounded,
                          onTap: () => onSend('close'),
                          size: 13,
                          opacity: 0.26,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  final int posMs;
  final int durMs;
  const _Progress({required this.posMs, required this.durMs});

  @override
  Widget build(BuildContext context) {
    final p = (durMs > 0 ? posMs / durMs : 0.0).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (_, c) => Stack(
        children: [
          Container(
            height: 2.5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            height: 2.5,
            width: c.maxWidth * p,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double opacity;
  const _Btn({
    required this.icon,
    required this.onTap,
    this.size = 18,
    this.opacity = 0.70,
  });
  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 80),
          opacity: _h ? 1.0 : widget.opacity,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(widget.icon, size: widget.size, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class MiniPlayerOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const MiniPlayerOverlay({super.key, required this.child});
  @override
  ConsumerState<MiniPlayerOverlay> createState() => _OverlayState();
}

class _OverlayState extends ConsumerState<MiniPlayerOverlay> {
  PlayerState? _last;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!ref.read(miniPlayerActiveProvider)) return false;
    final pressed = _toKeyString(event);
    if (pressed == null) return false;
    if (ref.read(settingsProvider).binding(ShortcutAction.miniPlayer) !=
        pressed) {
      return false;
    }
    MiniPlayerWindow.toggle(context);
    return true;
  }

  static String? _toKeyString(KeyEvent event) {
    final ctrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;

    final mods = {
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.meta,
      LogicalKeyboardKey.shift,
      LogicalKeyboardKey.alt,
    };
    if (mods.contains(key)) return null;

    String? name;
    if (ctrl) {
      final lbl = event.physicalKey.debugName ?? '';
      if (lbl.startsWith('Key ')) {
        name = lbl.substring(4).toUpperCase();
      } else if (lbl.startsWith('Digit ')) {
        name = lbl.substring(6);
      }
    }
    name ??=
        {
          LogicalKeyboardKey.space: 'Space',
          LogicalKeyboardKey.arrowLeft: 'ArrowLeft',
          LogicalKeyboardKey.arrowRight: 'ArrowRight',
          LogicalKeyboardKey.arrowUp: 'ArrowUp',
          LogicalKeyboardKey.arrowDown: 'ArrowDown',
          LogicalKeyboardKey.enter: 'Enter',
          LogicalKeyboardKey.tab: 'Tab',
          LogicalKeyboardKey.backspace: 'Backspace',
          LogicalKeyboardKey.delete: 'Delete',
          LogicalKeyboardKey.home: 'Home',
          LogicalKeyboardKey.end: 'End',
          LogicalKeyboardKey.pageUp: 'PageUp',
          LogicalKeyboardKey.pageDown: 'PageDown',
        }[key] ??
        (key.keyLabel.isNotEmpty ? key.keyLabel.toUpperCase() : null);

    if (name == null) return null;
    return [if (ctrl) 'Ctrl', if (shift) 'Shift', name].join('+');
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final isMini = ref.watch(miniPlayerActiveProvider);

    if (isMini && player != _last) {
      final prevPath = _last?.currentTrack?.path;
      final currPath = player.currentTrack?.path;
      _last = player;

      Future.microtask(() async {
        await pushMiniPlayerState(player);
        if (currPath != prevPath) {
          await MiniPlayerWindow.onTrackChanged(currPath);
        }
      });
    }

    return widget.child;
  }
}
