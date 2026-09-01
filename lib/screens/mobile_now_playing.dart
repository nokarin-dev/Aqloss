import 'dart:typed_data';
import 'dart:ui';

import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/accent_provider.dart';
import 'package:aqloss/providers/history_provider.dart';
import 'package:aqloss/providers/lyrics_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/widgets/lyrics_view.dart';
import 'package:aqloss/widgets/shared/custom_slider.dart';
import 'package:aqloss/widgets/shared/m3_playback_progress.dart';
import 'package:aqloss/widgets/sleep_timer_sheet.dart';
import 'package:aqloss/util/ab_loop.dart';
import 'package:aqloss/util/sleep_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MobileNowPlaying extends ConsumerStatefulWidget {
  const MobileNowPlaying({super.key});

  @override
  ConsumerState<MobileNowPlaying> createState() => _MobileNowPlayingState();
}

class _MobileNowPlayingState extends ConsumerState<MobileNowPlaying> {
  Uint8List? _art;
  String? _path;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final path = ref.read(playerProvider).currentTrack?.path;
    if (path != _path) _loadArt(path);
  }

  Future<void> _loadArt(String? path) async {
    if (path == null) {
      if (mounted) {
        setState(() {
          _art = null;
          _path = null;
        });
      }
      return;
    }
    _path = path;
    try {
      final bytes = await backend.readAlbumArt(path: path);
      if (mounted && _path == path) {
        setState(() => _art = bytes != null ? Uint8List.fromList(bytes) : null);
      }
    } catch (_) {
      if (mounted) setState(() => _art = null);
    }
  }

  Future<void> _openLyrics() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.isMaterial3Ui ? null : context.aq.surfaceVariant,
      builder: (ctx) {
        final h = MediaQuery.sizeOf(ctx).height;
        return SizedBox(height: h * 0.72, child: const LyricsView());
      },
    );
  }

  Future<void> _toggleLove(Track track) async {
    await ref.read(historyProvider.notifier).toggleLove(track);
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final track = player.currentTrack;
    final lyrics = ref.watch(lyricsProvider);
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final surface = isM3 ? cs.surface : aq.surface;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    final muted = isM3 ? cs.onSurfaceVariant : aq.onSurfaceMuted;

    ref.listen(playerProvider, (prev, next) {
      final nextPath = next.currentTrack?.path;
      if (nextPath != _path) _loadArt(nextPath);
    });

    final notifier = ref.read(playerProvider.notifier);
    final playing = player.status == PlayerStatus.playing;
    final loading = player.status == PlayerStatus.loading;
    final duration = track?.duration ?? Duration.zero;
    final progress = duration.inMilliseconds > 0
        ? (player.position.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    final accent = ref.watch(accentColorProvider);

    return Material(
      color: surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_art != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
                child: Opacity(
                  opacity: isM3 ? 0.28 : 0.22,
                  child: Image.memory(_art!, fit: BoxFit.cover),
                ),
              ),
            ),
          if (_art != null)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      surface.withValues(alpha: 0.55),
                      surface.withValues(alpha: 0.92),
                      surface,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 340),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: _Art(
                            bytes: _art,
                            empty: track == null,
                            placeholder: isM3
                                ? cs.surfaceContainerHighest
                                : aq.card,
                            iconColor: muted.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Meta(
                    track: track,
                    loved:
                        track != null &&
                        ref.watch(historyProvider).isLoved(track),
                    onLove: track == null ? null : () => _toggleLove(track),
                    onSurface: onSurface,
                    muted: muted,
                  ),
                  const SizedBox(height: 18),
                  if (isM3)
                    M3SeekBar(
                      progress: progress,
                      position: player.position,
                      duration: duration,
                      enabled: track != null,
                      playing: playing,
                      activeColor: accent ?? cs.primary,
                      onChanged: track == null
                          ? null
                          : (v) {
                              if (duration.inMilliseconds > 0) {
                                notifier.seekPreview(duration * v);
                              }
                            },
                      onChangeEnd: track == null
                          ? null
                          : (v) {
                              if (duration.inMilliseconds > 0) {
                                notifier.seekCommit(duration * v);
                              }
                            },
                    )
                  else
                    _DefaultSeek(
                      progress: progress,
                      position: player.position,
                      duration: duration,
                      enabled: track != null,
                      accent: accent ?? onSurface,
                      muted: muted,
                      onChanged: track == null
                          ? null
                          : (v) {
                              if (duration.inMilliseconds > 0) {
                                notifier.seekPreview(duration * v);
                              }
                            },
                      onChangeEnd: track == null
                          ? null
                          : (v) {
                              if (duration.inMilliseconds > 0) {
                                notifier.seekCommit(duration * v);
                              }
                            },
                    ),
                  const SizedBox(height: 8),
                  _Transport(
                    isM3: isM3,
                    playing: playing,
                    loading: loading,
                    hasTrack: track != null,
                    progress: progress,
                    shuffle: player.shuffle,
                    loopMode: player.loopMode,
                    sleepMode: player.sleepMode,
                    sleepUntil: player.sleepUntil,
                    abLoop: player.abLoop,
                    accent: accent,
                    onSurface: onSurface,
                    muted: muted,
                    surface: surface,
                    onShuffle: notifier.toggleShuffle,
                    onSleep: () => showSleepTimerSheet(context),
                    onAbLoop: track == null ? null : notifier.tapAbLoop,
                    onPrev: track == null ? null : notifier.skipPrevious,
                    onPlayPause: track == null
                        ? null
                        : playing
                        ? notifier.pause
                        : notifier.play,
                    onNext: track == null ? null : notifier.skipNext,
                    onLoop: notifier.cycleLoopMode,
                  ),
                  if (lyrics.hasLyrics) ...[
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: _openLyrics,
                      icon: Icon(Icons.lyrics_rounded, size: 18, color: muted),
                      label: Text('Lyrics', style: TextStyle(color: muted)),
                    ),
                  ] else
                    const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Art extends StatelessWidget {
  final Uint8List? bytes;
  final bool empty;
  final Color placeholder;
  final Color iconColor;

  const _Art({
    required this.bytes,
    required this.empty,
    required this.placeholder,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: bytes != null
            ? Image.memory(bytes!, fit: BoxFit.cover)
            : ColoredBox(
                color: placeholder,
                child: Center(
                  child: Icon(
                    empty ? Icons.music_note_rounded : Icons.album_rounded,
                    size: 56,
                    color: iconColor,
                  ),
                ),
              ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final Track? track;
  final bool loved;
  final VoidCallback? onLove;
  final Color onSurface;
  final Color muted;

  const _Meta({
    required this.track,
    required this.loved,
    required this.onSurface,
    required this.muted,
    this.onLove,
  });

  @override
  Widget build(BuildContext context) {
    final title = track?.displayTitle ?? 'Nothing playing';
    final artist = track?.displayArtist ?? '';
    final format = track == null
        ? null
        : [
            track!.format,
            if (track!.sampleRate > 0)
              '${(track!.sampleRate / 1000).toStringAsFixed(track!.sampleRate % 1000 == 0 ? 0 : 1)} kHz',
          ].join(' · ');

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: onLove != null ? 40 : 0),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              if (artist.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  artist,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: muted),
                ),
              ],
              if (format != null) ...[
                const SizedBox(height: 6),
                Text(
                  format,
                  style: TextStyle(
                    fontSize: 11,
                    color: muted.withValues(alpha: 0.75),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onLove != null)
          Positioned(
            top: -4,
            right: -8,
            child: IconButton(
              onPressed: onLove,
              icon: Icon(
                loved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: loved ? const Color(0xFFE85A7A) : muted,
              ),
            ),
          ),
      ],
    );
  }
}

class _DefaultSeek extends StatelessWidget {
  final double progress;
  final Duration position;
  final Duration duration;
  final bool enabled;
  final Color accent;
  final Color muted;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  const _DefaultSeek({
    required this.progress,
    required this.position,
    required this.duration,
    required this.enabled,
    required this.accent,
    required this.muted,
    this.onChanged,
    this.onChangeEnd,
  });

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomSlider(
          value: progress,
          trackHeight: 2.5,
          thumbRadius: 5,
          activeColor: accent,
          inactiveColor: muted.withValues(alpha: 0.18),
          thumbColor: accent,
          onChanged: enabled ? onChanged : null,
          onChangeEnd: enabled ? onChangeEnd : null,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _fmt(position),
              style: TextStyle(
                fontSize: 11,
                color: muted.withValues(alpha: 0.7),
              ),
            ),
            Text(
              _fmt(duration),
              style: TextStyle(
                fontSize: 11,
                color: muted.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Transport extends StatelessWidget {
  final bool isM3;
  final bool playing;
  final bool loading;
  final bool hasTrack;
  final double progress;
  final bool shuffle;
  final LoopMode loopMode;
  final Color? accent;
  final Color onSurface;
  final Color muted;
  final Color surface;
  final SleepTimerMode sleepMode;
  final DateTime? sleepUntil;
  final AbLoopPhase abLoop;
  final VoidCallback onShuffle;
  final VoidCallback onSleep;
  final VoidCallback? onAbLoop;
  final VoidCallback? onPrev;
  final VoidCallback? onPlayPause;
  final VoidCallback? onNext;
  final VoidCallback onLoop;

  const _Transport({
    required this.isM3,
    required this.playing,
    required this.loading,
    required this.hasTrack,
    required this.progress,
    required this.shuffle,
    required this.loopMode,
    required this.accent,
    required this.onSurface,
    required this.muted,
    required this.surface,
    required this.sleepMode,
    required this.sleepUntil,
    required this.abLoop,
    required this.onShuffle,
    required this.onSleep,
    required this.onAbLoop,
    required this.onPrev,
    required this.onPlayPause,
    required this.onNext,
    required this.onLoop,
  });

  @override
  Widget build(BuildContext context) {
    final loopOn = loopMode != LoopMode.off;
    final loopIcon = switch (loopMode) {
      LoopMode.track => Icons.repeat_one_rounded,
      _ => Icons.repeat_rounded,
    };
    final active =
        accent ?? (isM3 ? Theme.of(context).colorScheme.primary : onSurface);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: onShuffle,
          icon: Icon(Icons.shuffle_rounded, color: shuffle ? active : muted),
        ),
        IconButton(
          onPressed: onSleep,
          tooltip: sleepTimerTooltip(mode: sleepMode, until: sleepUntil),
          icon: Icon(
            Icons.bedtime_rounded,
            color: sleepMode != SleepTimerMode.off ? active : muted,
          ),
        ),
        IconButton(
          onPressed: onAbLoop,
          tooltip: abLoopTooltip(abLoop),
          icon: Text(
            abLoopButtonLabel(abLoop),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: abLoop != AbLoopPhase.off ? active : muted,
            ),
          ),
        ),
        IconButton(
          onPressed: onPrev,
          icon: Icon(
            Icons.skip_previous_rounded,
            size: 36,
            color: hasTrack ? onSurface : onSurface.withValues(alpha: 0.25),
          ),
        ),
        if (isM3)
          M3PlayButton(
            isPlaying: playing,
            isLoading: loading,
            hasTrack: hasTrack,
            progress: progress,
            size: 64,
            accentColor: accent,
            onTap: onPlayPause,
          )
        else
          _DefaultPlay(
            playing: playing,
            loading: loading,
            hasTrack: hasTrack,
            accent: active,
            surface: surface,
            onTap: onPlayPause,
          ),
        IconButton(
          onPressed: onNext,
          icon: Icon(
            Icons.skip_next_rounded,
            size: 36,
            color: hasTrack ? onSurface : onSurface.withValues(alpha: 0.25),
          ),
        ),
        IconButton(
          onPressed: onLoop,
          icon: Icon(loopIcon, color: loopOn ? active : muted),
        ),
      ],
    );
  }
}

class _DefaultPlay extends StatefulWidget {
  final bool playing;
  final bool loading;
  final bool hasTrack;
  final Color accent;
  final Color surface;
  final VoidCallback? onTap;

  const _DefaultPlay({
    required this.playing,
    required this.loading,
    required this.hasTrack,
    required this.accent,
    required this.surface,
    this.onTap,
  });

  @override
  State<_DefaultPlay> createState() => _DefaultPlayState();
}

class _DefaultPlayState extends State<_DefaultPlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const sz = 64.0;
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: sz,
          height: sz,
          decoration: BoxDecoration(
            color: widget.hasTrack
                ? widget.accent
                : widget.accent.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            boxShadow: widget.hasTrack
                ? [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: widget.loading
              ? Padding(
                  padding: const EdgeInsets.all(18),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.surface,
                  ),
                )
              : Icon(
                  widget.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 32,
                  color: widget.hasTrack
                      ? widget.surface
                      : widget.accent.withValues(alpha: 0.25),
                ),
        ),
      ),
    );
  }
}
