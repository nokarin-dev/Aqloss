import 'dart:typed_data';

import 'package:aqloss/l10n/l10n.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/lyrics_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/services/metadata_service.dart';
import 'package:aqloss/ui/shell/albums_page.dart';
import 'package:aqloss/ui/shell/glyphs.dart';
import 'package:aqloss/ui/shell/tokens.dart';
import 'package:aqloss/ui/shell/library_page.dart';
import 'package:aqloss/ui/shell/love_button.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/ui/shell/browse_bar.dart';
import 'package:aqloss/ui/shell/window_buttons.dart';
import 'package:aqloss/util/ab_loop.dart';
import 'package:aqloss/util/sleep_timer.dart';
import 'package:aqloss/ui/shell/sleep_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aqloss/ui/shell/glass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

const _muted = textMuted;

class HomePage extends ConsumerStatefulWidget {
  final HomeBrowse browse;
  final Uint8List? art;
  final ValueChanged<HomeBrowse> onBrowse;
  final Widget? queue;
  final bool queueOpen;

  const HomePage({
    super.key,
    required this.browse,
    required this.art,
    required this.onBrowse,
    this.queue,
    this.queueOpen = false,
  });

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  bool _searching = false;
  LibraryLayout _layout = LibraryLayout.details;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.browse == widget.browse) return;
    _searching = false;
    _query.clear();
    _focus.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(libraryProvider.notifier).setQuery('');
    });
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_searching || _focus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focus.hasFocus || !_searching) return;
      setState(() => _searching = false);
    });
  }

  void _onQuery(String value) {
    setState(() {});
  }

  void _openSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _closeSearch() {
    if (!_searching || !mounted) return;
    _searching = false;
    _focus.unfocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final browse = widget.browse;
    final track = ref.watch(
      playerProvider.select((player) => player.currentTrack),
    );
    final query = _query.text;
    final page = switch (browse) {
      HomeBrowse.library => LibraryPage(query: query, layout: _layout),
      HomeBrowse.albums => AlbumsPage(query: query, layout: _layout),
      HomeBrowse.nowPlaying =>
        track == null
            ? EmptyNote(tr('player.nothing'))
            : _Stage(art: widget.art),
    };

    final queue = widget.queue;
    final now = browse == HomeBrowse.nowPlaying;
    final stage = Crossfade(
      child: KeyedSubtree(
        key: ValueKey(
          browse == HomeBrowse.nowPlaying
              ? (track == null ? 'now-empty' : 'now-stage')
              : browse.name,
        ),
        child: page,
      ),
    );
    const headerHeight = 36.0;
    final header = BrowseBar(
      browse: browse,
      searching: _searching,
      query: _query,
      focus: _focus,
      hint: browse == HomeBrowse.albums
          ? tr('albums.search')
          : tr('library.search'),
      onBrowse: widget.onBrowse,
      onOpenSearch: _openSearch,
      onCloseSearch: _closeSearch,
      onQuery: _onQuery,
      layout: _layout,
      onLayout: (next) => setState(() => _layout = next),
    );
    final column = Column(
      children: [
        const SizedBox(height: headerHeight),
        const SizedBox(height: 16),
        Expanded(child: stage),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: GestureDetector(
        onTap: () {
          if (_searching) _focus.unfocus();
        },
        behavior: widget.queueOpen && now
            ? HitTestBehavior.deferToChild
            : HitTestBehavior.translucent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Behind the transport on Now Playing, over the list on Library.
            if (queue != null && now) queue,
            column,
            if (queue != null && !now) queue,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: headerHeight,
              child: Stack(
                children: [
                  header,
                  const Align(
                    alignment: Alignment.centerRight,
                    child: WindowButtons(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stage extends ConsumerWidget {
  final Uint8List? art;

  const _Stage({required this.art});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final track = player.currentTrack!;
    final notifier = ref.read(playerProvider.notifier);
    final playing = player.status == PlayerStatus.playing;
    final duration = track.duration;
    final position = player.position > duration ? duration : player.position;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 840;
        final artSize = _fit(wide ? 280 : 220, constraints.maxWidth);
        Widget controls(bool roomy, double button) {
          final style = roomy
              ? null
              : IconButton.styleFrom(
                  fixedSize: Size(button, 44),
                  minimumSize: Size(button, 44),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
          return Row(
            mainAxisAlignment: roomy
                ? MainAxisAlignment.center
                : MainAxisAlignment.spaceEvenly,
            mainAxisSize: roomy ? MainAxisSize.min : MainAxisSize.max,
            children: [
              _SleepButton(style: style),
              _Mark(
                style: style,
                tooltip: tr('player.shuffle'),
                on: player.shuffle,
                onPressed: notifier.toggleShuffle,
                glyph: ShellGlyph.shuffle,
              ),
              IconButton(
                style: style,
                tooltip: tr('player.previous_track'),
                onPressed: notifier.previous,
                icon: const ShellIcon(
                  glyph: ShellGlyph.previous,
                  color: Colors.white,
                ),
              ),
              IconButton(
                style: style,
                tooltip: tr('player.play_pause'),
                onPressed: playing ? notifier.pause : notifier.play,
                icon: IconFade(
                  child: ShellIcon(
                    key: ValueKey(playing),
                    glyph: playing ? ShellGlyph.pause : ShellGlyph.play,
                    color: Colors.white,
                    size: roomy ? 28 : 22,
                  ),
                ),
              ),
              IconButton(
                style: style,
                tooltip: tr('player.next_track'),
                onPressed: notifier.next,
                icon: const ShellIcon(
                  glyph: ShellGlyph.next,
                  color: Colors.white,
                ),
              ),
              _Mark(
                style: style,
                tooltip: switch (player.loopMode) {
                  LoopMode.off => tr('player.repeat'),
                  LoopMode.track => tr('player.repeat_track'),
                  LoopMode.album => tr('player.repeat_album'),
                  LoopMode.playlist => tr('player.repeat_all'),
                },
                on: player.loopMode != LoopMode.off,
                onPressed: notifier.cycleLoopMode,
                glyph: player.loopMode == LoopMode.track
                    ? ShellGlyph.repeatOne
                    : ShellGlyph.repeat,
              ),
              TextButton(
                style: roomy
                    ? null
                    : TextButton.styleFrom(
                        fixedSize: Size(button, 44),
                        minimumSize: Size(button, 44),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                onPressed: notifier.tapAbLoop,
                child: AnimatedDefaultTextStyle(
                  duration: motionOf(context),
                  curve: motionCurve,
                  style: TextStyle(
                    color: player.abLoop == AbLoopPhase.off
                        ? _muted
                        : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: roomy ? null : 13,
                  ),
                  child: const Text('A-B'),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Expanded(
              child: wide
                  ? Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _Song(track: track, art: art, artSize: artSize),
                          _LyricSlot(
                            wide: true,
                            width: _fit(
                              360,
                              constraints.maxWidth - artSize - 36,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _PhoneBody(track: track, art: art, artSize: artSize),
            ),
            const SizedBox(height: 12),
            ShellLens(
              radius: 14,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  wide
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            final side = (constraints.maxWidth * 0.34).clamp(
                              0.0,
                              156.0,
                            );
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: side,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: controls(true, 48),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: SizedBox(
                                    width: side,
                                    child: const _Volume(),
                                  ),
                                ),
                              ],
                            );
                          },
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final button = (constraints.maxWidth / 7).clamp(
                              36.0,
                              48.0,
                            );
                            return Column(
                              children: [
                                controls(false, button),
                                const SizedBox(height: 8),
                                const _Volume(),
                              ],
                            );
                          },
                        ),
                  Row(
                    children: [
                      Text(
                        MetadataService.formatDuration(position),
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5,
                            ),
                            overlayShape: SliderComponentShape.noOverlay,
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white.withValues(
                              alpha: 0.18,
                            ),
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: progress,
                            onChanged: (value) {
                              notifier.seekPreview(duration * value);
                            },
                            onChangeEnd: (value) {
                              notifier.seekCommit(duration * value);
                            },
                          ),
                        ),
                      ),
                      Text(
                        MetadataService.formatDuration(duration),
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

double _fit(double want, double room) {
  if (room <= 0) return want;
  return want > room ? room : want;
}

// Volume on the right of the transport row
class _Volume extends ConsumerWidget {
  const _Volume();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(playerProvider.select((player) => player.volume));
    final exclusive = ref.watch(
      settingsProvider.select(
        (settings) => settings.outputMode == AudioOutputMode.exclusive,
      ),
    );
    final level = volume.clamp(0.0, 1.0);
    final controls = Row(
      children: [
        ShellIcon(
          glyph: level == 0 ? ShellGlyph.volumeMute : ShellGlyph.volume,
          color: level == 0 ? _muted : Colors.white,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              if (width < 48) return const SizedBox.shrink();
              return IgnorePointer(
                ignoring: exclusive,
                child: LiquidGlassSlider(
                  value: level,
                  width: width,
                  activeColor: Colors.white,
                  inactiveColor: const Color(0x2EFFFFFF),
                  thumbColor: Colors.white,
                  motion: const LiquidGlassLensMotionSpec(maxDeformation: 0),
                  layout: const LiquidGlassSliderLayout(
                    trackHeight: 3,
                    thumbWidth: 22,
                    thumbHeight: 14,
                    liftedThumbWidth: 34,
                    liftedThumbHeight: 22,
                  ),
                  onChanged: (value) {
                    ref.read(playerProvider.notifier).setVolume(value);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
    final row = MouseRegion(
      cursor: exclusive ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: exclusive ? Opacity(opacity: 0.4, child: controls) : controls,
    );
    if (!exclusive) return row;
    return Tooltip(message: tr('player.exclusive_blocked'), child: row);
  }
}

class _Mark extends StatelessWidget {
  final String tooltip;
  final bool on;
  final VoidCallback onPressed;
  final ShellGlyph glyph;
  final ButtonStyle? style;

  const _Mark({
    required this.tooltip,
    required this.on,
    required this.onPressed,
    required this.glyph,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      style: style,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: IconFade(
        child: ShellIcon(
          key: ValueKey('$glyph$on'),
          glyph: glyph,
          color: on ? Colors.white : _muted,
        ),
      ),
    );
  }
}

class _SleepButton extends ConsumerWidget {
  final ButtonStyle? style;

  const _SleepButton({this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final ticking =
        player.sleepActive && player.sleepMode != SleepTimerMode.endOfTrack;
    if (!ticking) return _sleep(context, player);
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, _) => _sleep(context, player),
    );
  }

  Widget _sleep(BuildContext context, PlayerState player) {
    return IconButton(
      style: style,
      tooltip: sleepTimerTooltip(
        mode: player.sleepMode,
        until: player.sleepUntil,
      ),
      onPressed: () {
        final box = context.findRenderObject() as RenderBox?;
        final origin = box == null
            ? Offset.zero
            : box.localToGlobal(box.size.center(Offset.zero));
        showSleepTimerSheet(context, origin);
      },
      icon: ShellIcon(
        glyph: ShellGlyph.moon,
        color: player.sleepActive ? Colors.white : _muted,
      ),
    );
  }
}

class _Song extends StatelessWidget {
  final Track track;
  final Uint8List? art;
  final double artSize;
  final bool showArt;

  const _Song({
    required this.track,
    required this.art,
    required this.artSize,
    this.showArt = true,
  });

  @override
  Widget build(BuildContext context) {
    final size = artSize;
    return SizedBox(
      width: showArt ? size : double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: motionOf(context),
            switchInCurve: motionCurve,
            switchOutCurve: motionCurve,
            child: Column(
              key: ValueKey(track.path),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  track.displayTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  track.uiArtist,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 14),
                ),
                LoveButton(track: track),
              ],
            ),
          ),
          if (showArt) ...[
            const SizedBox(height: 16),
            _Cover(art: art, size: size),
          ],
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final Uint8List? art;
  final double size;

  const _Cover({required this.art, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: Crossfade(
          child: art == null
              ? const ColoredBox(
                  key: ValueKey('art-empty'),
                  color: Color(0xFF1A1A1A),
                  child: Icon(
                    CupertinoIcons.music_note,
                    color: _muted,
                    size: 36,
                  ),
                )
              : Image.memory(
                  art!,
                  key: ValueKey(identityHashCode(art)),
                  fit: BoxFit.cover,
                ),
        ),
      ),
    );
  }
}

// Phone swaps the cover for the lyric list.
class _PhoneBody extends ConsumerStatefulWidget {
  final Track track;
  final Uint8List? art;
  final double artSize;

  const _PhoneBody({
    required this.track,
    required this.art,
    required this.artSize,
  });

  @override
  ConsumerState<_PhoneBody> createState() => _PhoneBodyState();
}

class _PhoneBodyState extends ConsumerState<_PhoneBody> {
  bool _lyrics = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Song(
          track: widget.track,
          art: widget.art,
          artSize: widget.artSize,
          showArt: false,
        ),
        TextButton(
          onPressed: () => setState(() => _lyrics = !_lyrics),
          style: TextButton.styleFrom(
            foregroundColor: _lyrics ? Colors.white : _muted,
            minimumSize: const Size(64, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Text(
            tr('player.lyrics'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: _lyrics ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: _lyrics
              ? const _LyricFill()
              : Center(
                  child: _Cover(art: widget.art, size: widget.artSize),
                ),
        ),
      ],
    );
  }
}

class _LyricFill extends ConsumerStatefulWidget {
  const _LyricFill();

  @override
  ConsumerState<_LyricFill> createState() => _LyricFillState();
}

class _LyricFillState extends ConsumerState<_LyricFill> {
  static const _line = 36.0;

  LyricsState _shown = const LyricsState();
  final ScrollController _scroll = ScrollController();
  int _followed = -1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _keepLine(int index, [int attempt = 0]) {
    if (attempt == 0) {
      if (index == _followed) return;
      _followed = index;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if (max == 0 && attempt < 1) {
        _keepLine(index, attempt + 1);
        return;
      }
      final view = _scroll.position.viewportDimension;
      final top = index * _line;
      final start = _scroll.offset;
      if (top >= start && top + _line <= start + view) return;
      final target = (top - view / 2 + _line / 2).clamp(0.0, max);
      _scroll.animateTo(
        target,
        duration: motionOf(context),
        curve: motionCurve,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(lyricsProvider);
    final path = ref.watch(
      playerProvider.select((player) => player.currentTrack?.path),
    );
    final position = ref.watch(
      playerProvider.select((state) => state.position),
    );
    _shown = pickShownLyrics(_shown, live, path);
    final doc = _shown.document;
    if (doc != null && doc.lines.isNotEmpty) {
      final current = doc.currentIndex(position);
      _keepLine(current < 0 ? 0 : current);
      return ListView.builder(
        controller: _scroll,
        itemExtent: _line,
        itemCount: doc.lines.length,
        itemBuilder: (context, index) {
          final active = index == current;
          return Align(
            alignment: Alignment.center,
            child: Text(
              doc.lines[index].text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? Colors.white : _muted,
                fontSize: active ? 18 : 15,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          );
        },
      );
    }
    if (_shown.isLoading) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: _muted),
        ),
      );
    }
    if (_shown.rawText != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          _shown.rawText!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 15, height: 1.5),
        ),
      );
    }
    return Center(
      child: Text(
        tr('player.no_lyrics'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: _muted, fontSize: 14),
      ),
    );
  }
}

class _LyricSlot extends ConsumerStatefulWidget {
  final bool wide;
  final double width;

  const _LyricSlot({required this.wide, required this.width});

  @override
  ConsumerState<_LyricSlot> createState() => _LyricSlotState();
}

class _LyricSlotState extends ConsumerState<_LyricSlot> {
  LyricsState _shown = const LyricsState();

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(lyricsProvider);
    final path = ref.watch(
      playerProvider.select((player) => player.currentTrack?.path),
    );
    _shown = pickShownLyrics(_shown, live, path);
    final show = _shown.hasLyrics || _shown.isLoading;
    final wide = widget.wide;
    return AnimatedSize(
      duration: motionOf(context),
      curve: motionCurve,
      alignment: wide ? Alignment.centerLeft : Alignment.topCenter,
      child: show
          ? Padding(
              padding: EdgeInsets.only(left: wide ? 28 : 0, top: wide ? 0 : 16),
              child: SizedBox(
                width: widget.width,
                height: wide ? 230 : 180,
                child: _Lyrics(_shown),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _Lyrics extends ConsumerWidget {
  final LyricsState lyrics;

  const _Lyrics(this.lyrics);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(
      playerProvider.select((state) => state.position),
    );

    final doc = lyrics.document;
    if (doc != null && doc.lines.isNotEmpty) {
      final current = doc.currentIndex(position);
      final window = lyricLineWindow(current, doc.lines.length);
      final active = current < window.start || current >= window.end
          ? window.start
          : current;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = window.start; i < window.end; i++)
            Padding(
              key: ValueKey(i),
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: AnimatedDefaultTextStyle(
                duration: motionOf(context),
                curve: motionCurve,
                style: TextStyle(
                  color: i == active ? Colors.white : _muted,
                  fontSize: i == active ? 18 : 14,
                  fontWeight: i == active ? FontWeight.w600 : FontWeight.w400,
                ),
                child: Text(doc.lines[i].text, textAlign: TextAlign.center),
              ),
            ),
        ],
      );
    }

    if (lyrics.isLoading) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: _muted),
        ),
      );
    }

    if (lyrics.rawText != null) {
      return SingleChildScrollView(
        child: Text(
          lyrics.rawText!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 14, height: 1.5),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
