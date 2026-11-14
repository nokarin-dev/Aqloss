import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/ui/shell/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

const _artSlots = 2;
const _artCap = 256;

class MiniAlbumArt extends StatefulWidget {
  final String path;
  final double size;
  final double radius;

  const MiniAlbumArt({
    super.key,
    required this.path,
    this.size = 36,
    this.radius = 5,
  });

  @override
  State<MiniAlbumArt> createState() => _MiniAlbumArtState();
}

class _MiniAlbumArtState extends State<MiniAlbumArt> {
  Uint8List? _bytes;
  var _token = 0;

  @override
  void initState() {
    super.initState();
    _bind(widget.path);
  }

  @override
  void didUpdateWidget(MiniAlbumArt old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _bind(widget.path);
  }

  // Show a cached cover on this frame. Fetch the rest after layout.
  void _bind(String path) {
    final token = ++_token;
    if (_ArtStore.has(path)) {
      _bytes = _ArtStore.read(path);
      return;
    }
    _bytes = null;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || token != _token) return;
      _ArtStore.load(path).then((bytes) {
        if (!mounted || token != _token) return;
        setState(() => _bytes = bytes);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = (widget.size * 0.38).clamp(12.0, 18.0);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final px = widget.size.isFinite
        ? (widget.size * dpr).round().clamp(1, 480)
        : null;
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: ColoredBox(
            color: const Color(0x14FFFFFF),
            child: _bytes != null
                ? Image.memory(
                    _bytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    cacheWidth: px,
                  )
                : Icon(
                    CupertinoIcons.music_note,
                    size: iconSize,
                    color: textMuted,
                  ),
          ),
        ),
      ),
    );
  }
}

class _Job {
  final String path;
  final done = Completer<Uint8List?>();

  _Job(this.path);
}

class _ArtStore {
  static final _bytes = <String, Uint8List?>{};
  static final _inflight = <String, Future<Uint8List?>>{};
  static final _queue = Queue<_Job>();
  static var _running = 0;

  static bool has(String path) => _bytes.containsKey(path);

  static Uint8List? read(String path) {
    final value = _bytes.remove(path);
    _bytes[path] = value;
    return value;
  }

  static Future<Uint8List?> load(String path) {
    if (_bytes.containsKey(path)) return Future.value(read(path));
    final pending = _inflight[path];
    if (pending != null) return pending;
    final job = _Job(path);
    _inflight[path] = job.done.future;
    _queue.add(job);
    _pump();
    return job.done.future;
  }

  static void _put(String path, Uint8List? bytes) {
    _bytes.remove(path);
    _bytes[path] = bytes;
    while (_bytes.length > _artCap) {
      _bytes.remove(_bytes.keys.first);
    }
  }

  static void _pump() {
    while (_running < _artSlots && _queue.isNotEmpty) {
      final job = _queue.removeFirst();
      _running++;
      backend
          .readAlbumArtThumbnail(path: job.path)
          .then((bytes) {
            final stored = bytes == null ? null : Uint8List.fromList(bytes);
            _put(job.path, stored);
            if (!job.done.isCompleted) job.done.complete(stored);
          })
          .catchError((Object _) {
            if (!job.done.isCompleted) job.done.complete(null);
            return null;
          })
          .whenComplete(() {
            _running--;
            _inflight.remove(job.path);
            _pump();
          });
    }
  }
}
