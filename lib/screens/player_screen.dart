import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/lyrics_provider.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/screens/mobile_now_playing.dart';
import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/widgets/player_controls.dart';
import 'package:aqloss/providers/history_provider.dart';
import 'package:aqloss/services/lastfm_service.dart';
import 'package:aqloss/widgets/spectrum_display.dart';
import 'package:aqloss/widgets/lyrics_view.dart';
import 'package:aqloss/widgets/ui/ui_kit.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

// Cover layout breakpoint
const _coverLayoutMaxWidth = 640.0;

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final track = player.currentTrack;
    final isWide = MediaQuery.of(context).size.width > 700;

    if (!isWide) return const MobileNowPlaying();

    return LayoutBuilder(
      builder: (context, constraints) {
        final body = _DesktopNowPlaying(
          track: track,
          maxWidth: constraints.maxWidth,
          m3: context.isMaterial3Ui,
        );
        if (context.isMaterial3Ui) {
          return ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: body,
          );
        }
        return UiPage(body: body);
      },
    );
  }
}

class _DesktopNowPlaying extends ConsumerWidget {
  final Track? track;
  final double maxWidth;
  final bool m3;
  const _DesktopNowPlaying({
    required this.track,
    required this.maxWidth,
    required this.m3,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(lyricsProvider);
    if (maxWidth < _coverLayoutMaxWidth) {
      return _CoverNowPlaying(track: track, m3: m3);
    }

    final settings = ref.watch(settingsProvider);
    final showLyrics = track != null;
    final artPad = m3
        ? const EdgeInsets.fromLTRB(28, 28, 14, 20)
        : const EdgeInsets.fromLTRB(24, 26, 12, 18);
    final mainPad = m3
        ? const EdgeInsets.fromLTRB(16, 36, 36, 24)
        : const EdgeInsets.fromLTRB(14, 30, 30, 22);
    final leftW = showLyrics
        ? (maxWidth * 0.36).clamp(260.0, 400.0)
        : (maxWidth * 0.40).clamp(240.0, 420.0);

    final artCard = _AlbumArtCard(
      track: track,
      showBackground: settings.showAlbumArtBackground,
      m3: m3,
    );

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: leftW,
          child: Padding(
            padding: artPad,
            child: Column(
              children: [
                if (showLyrics) ...[
                  Flexible(
                    flex: 4,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        var side = c.maxWidth < c.maxHeight
                            ? c.maxWidth
                            : c.maxHeight;
                        if (side > 380) side = 380;
                        return Center(
                          child: SizedBox(
                            width: side,
                            height: side,
                            child: artCard,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(flex: 5, child: _LyricsPane(m3: m3)),
                ] else
                  AspectRatio(aspectRatio: 1, child: artCard),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: mainPad,
            child: _PlaybackColumn(
              track: track,
              m3: m3,
              spectrumEnabled: settings.spectrumEnabled,
            ),
          ),
        ),
      ],
    );
  }
}

class _LyricsPane extends StatelessWidget {
  final bool m3;
  const _LyricsPane({required this.m3});

  @override
  Widget build(BuildContext context) {
    if (!m3) {
      return const ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        child: LyricsView(compact: true),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: const LyricsView(compact: true),
    );
  }
}

class _PlaybackColumn extends StatelessWidget {
  final Track? track;
  final bool m3;
  final bool spectrumEnabled;
  const _PlaybackColumn({
    required this.track,
    required this.m3,
    required this.spectrumEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (m3)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Column(
              key: ValueKey(track?.path),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track?.displayTitle ?? 'Nothing playing',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        () {
                          final parts = [
                            if (track?.artist != null) track!.artist!,
                            if (track?.album != null) track!.album!,
                          ];
                          return parts.isEmpty ? '-' : parts.join(' · ');
                        }(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (track != null) _PlayerLoveBtn(track: track!),
                  ],
                ),
              ],
            ),
          )
        else ...[
          _TrackInfo(track: track),
          const SizedBox(height: 6),
        ],
        if (track != null) ...[
          if (m3) const SizedBox(height: 12),
          _FormatRow(track: track!, soft: m3),
        ],
        const Spacer(),
        if (spectrumEnabled) ...[
          SpectrumDisplay(
            height: m3 ? 64 : 72,
            barCount: 48,
            color: m3
                ? cs.primary.withValues(alpha: 0.14)
                : cs.onSurface.withValues(alpha: 0.09),
          ),
          SizedBox(height: m3 ? 24 : 20),
        ],
        const PlayerControls(),
      ],
    );
  }
}

class _CoverNowPlaying extends ConsumerStatefulWidget {
  final Track? track;
  final bool m3;
  const _CoverNowPlaying({required this.track, required this.m3});

  @override
  ConsumerState<_CoverNowPlaying> createState() => _CoverNowPlayingState();
}

class _CoverNowPlayingState extends ConsumerState<_CoverNowPlaying> {
  bool _lyricsOpen = false;

  @override
  void didUpdateWidget(_CoverNowPlaying old) {
    super.didUpdateWidget(old);
    if (old.track?.path != widget.track?.path) {
      _lyricsOpen = false;
    }
  }

  void _toggleLyrics() => setState(() => _lyricsOpen = !_lyricsOpen);

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final track = widget.track;
    final pad = widget.m3
        ? const EdgeInsets.fromLTRB(20, 16, 20, 14)
        : const EdgeInsets.fromLTRB(16, 14, 16, 12);

    final subtitle = [
      if (track?.artist != null) track!.artist!,
      if (track?.album != null) track!.album!,
    ].join(widget.m3 ? ' · ' : ' - ');

    Widget artStage(double side) => SizedBox(
      width: side,
      height: side,
      child: _ArtStage(
        track: track,
        m3: widget.m3,
        showBackground: settings.showAlbumArtBackground,
        lyricsOpen: _lyricsOpen,
        onToggleLyrics: track == null ? null : _toggleLyrics,
      ),
    );

    final meta = Column(
      children: [
        Stack(
          alignment: Alignment.topCenter,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: track != null ? 32 : 0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Column(
                  key: ValueKey(track?.path),
                  children: [
                    Text(
                      track?.displayTitle ?? 'Nothing playing',
                      textAlign: TextAlign.center,
                      style: widget.m3
                          ? theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.3,
                            )
                          : TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurface,
                              letterSpacing: -0.4,
                            ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle.isEmpty ? '-' : subtitle,
                      textAlign: TextAlign.center,
                      style: widget.m3
                          ? theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            )
                          : TextStyle(
                              fontSize: 12.5,
                              color: cs.onSurface.withValues(alpha: 0.34),
                              fontWeight: FontWeight.w300,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            if (track != null)
              Positioned(right: 0, top: 0, child: _PlayerLoveBtn(track: track)),
          ],
        ),
        if (track != null) ...[
          const SizedBox(height: 8),
          _FormatRow(
            track: track,
            soft: widget.m3,
            alignment: WrapAlignment.center,
          ),
        ],
      ],
    );

    const controls = PlayerControls(dense: true);

    return Padding(
      padding: pad,
      child: LayoutBuilder(
        builder: (context, c) {
          const minArt = 128.0;
          const reserved = 292.0;
          final fits = c.maxHeight >= minArt + reserved;

          if (!fits) {
            final side = c.maxWidth > 240 ? 240.0 : c.maxWidth;
            return SingleChildScrollView(
              child: Column(
                children: [
                  artStage(side),
                  const SizedBox(height: 14),
                  meta,
                  const SizedBox(height: 8),
                  controls,
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, inner) {
                    final side = inner.maxWidth < inner.maxHeight
                        ? inner.maxWidth
                        : inner.maxHeight;
                    return Center(child: artStage(side));
                  },
                ),
              ),
              const SizedBox(height: 14),
              meta,
              const SizedBox(height: 8),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _ArtStage extends StatelessWidget {
  final Track? track;
  final bool m3;
  final bool showBackground;
  final bool lyricsOpen;
  final VoidCallback? onToggleLyrics;

  const _ArtStage({
    required this.track,
    required this.m3,
    required this.showBackground,
    required this.lyricsOpen,
    required this.onToggleLyrics,
  });

  @override
  Widget build(BuildContext context) {
    final radius = m3 ? 24.0 : 16.0;
    return Stack(
      children: [
        Positioned.fill(
          child: _AlbumArtCard(
            track: track,
            showBackground: showBackground,
            m3: m3,
            compact: true,
          ),
        ),
        if (lyricsOpen)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: const ColoredBox(
                color: Color(0xD1000000),
                child: LyricsView(onDark: true),
              ),
            ),
          ),
        if (onToggleLyrics != null)
          Positioned(
            top: 8,
            right: 8,
            child: _LyricsChip(open: lyricsOpen, onTap: onToggleLyrics!),
          ),
      ],
    );
  }
}

class _LyricsChip extends StatelessWidget {
  final bool open;
  final VoidCallback onTap;
  const _LyricsChip({required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: open ? 'Hide lyrics' : 'Lyrics',
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  open ? Icons.close_rounded : Icons.lyrics_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  open ? 'Close' : 'Lyrics',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Album art card
class _AlbumArtCard extends ConsumerStatefulWidget {
  final Track? track;
  final bool showBackground;
  final bool m3;
  final bool compact;
  const _AlbumArtCard({
    this.track,
    required this.showBackground,
    this.m3 = false,
    this.compact = false,
  });

  @override
  ConsumerState<_AlbumArtCard> createState() => _AlbumArtCardState();
}

class _AlbumArtCardState extends ConsumerState<_AlbumArtCard> {
  Uint8List? _artBytes;
  String? _loadedPath;

  @override
  void initState() {
    super.initState();
    _loadArt();
  }

  @override
  void didUpdateWidget(_AlbumArtCard old) {
    super.didUpdateWidget(old);
    if (widget.track?.path != _loadedPath) _loadArt();
  }

  Future<void> _loadArt() async {
    final path = widget.track?.path;
    if (path == null) {
      setState(() {
        _artBytes = null;
        _loadedPath = null;
      });
      return;
    }
    _loadedPath = path;
    try {
      final bytes = await backend.readAlbumArt(path: path);
      if (mounted && _loadedPath == path) {
        setState(
          () => _artBytes = bytes != null ? Uint8List.fromList(bytes) : null,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _artBytes = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = widget.m3 ? 24.0 : 16.0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(anim),
          child: child,
        ),
      ),
      child: Stack(
        key: ValueKey('${widget.track?.path}_${widget.showBackground}'),
        children: [
          if (widget.showBackground && _artBytes != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.memory(_artBytes!, fit: BoxFit.cover),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.25),
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: widget.showBackground && _artBytes != null
                  ? Colors.transparent
                  : widget.m3
                  ? cs.surfaceContainerHighest
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(radius),
              border: widget.m3
                  ? null
                  : Border.all(color: cs.onSurface.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: widget.compact
                        ? 0.32
                        : widget.m3
                        ? 0.28
                        : 0.60,
                  ),
                  blurRadius: widget.compact
                      ? 18
                      : widget.m3
                      ? 28
                      : 50,
                  offset: Offset(0, widget.compact ? 8 : (widget.m3 ? 12 : 20)),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _artBytes != null
                ? Image.memory(_artBytes!, fit: BoxFit.cover)
                : Center(
                    child: Icon(
                      Icons.music_note_rounded,
                      size: widget.compact ? 48 : 64,
                      color: cs.onSurface.withValues(alpha: 0.07),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// Track info
class _TrackInfo extends ConsumerWidget {
  final Track? track;
  const _TrackInfo({this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width > 700;
    final artist = track?.artist;
    final album = track?.album;
    final subtitle = [?artist, ?album].join(' - ');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOut,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Column(
        key: ValueKey(track?.path),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            track?.displayTitle ?? 'Nothing playing',
            style: TextStyle(
              fontSize: isWide ? 21 : 19,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
              letterSpacing: -0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitle.isEmpty ? '-' : subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: cs.onSurface.withValues(alpha: 0.34),
                    fontWeight: FontWeight.w300,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (track != null) _PlayerLoveBtn(track: track!),
            ],
          ),
        ],
      ),
    );
  }
}

// Format row
class _FormatRow extends StatelessWidget {
  final Track track;
  final bool soft;
  final WrapAlignment alignment;
  const _FormatRow({
    required this.track,
    this.soft = false,
    this.alignment = WrapAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final isExclusive = backend.isExclusiveMode();
    return Wrap(
      spacing: 5,
      runSpacing: 4,
      alignment: alignment,
      children: [
        _Badge(track.format, soft: soft),
        if (track.sampleRate > 0)
          _Badge(
            '${(track.sampleRate / 1000).toStringAsFixed(track.sampleRate % 1000 == 0 ? 0 : 1)} kHz',
            soft: soft,
          ),
        if (track.bitDepth != null) _Badge('${track.bitDepth}-bit', soft: soft),
        if (isExclusive)
          _Badge(
            'BIT-PERFECT',
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.06),
            soft: soft,
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color? color;
  final bool soft;
  const _Badge(this.label, {this.color, this.soft = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (soft) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color ?? cs.secondaryContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: cs.onSecondaryContainer,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.09)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: cs.onSurface.withValues(alpha: 0.25),
          letterSpacing: 0.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Love button
class _PlayerLoveBtn extends ConsumerStatefulWidget {
  final Track track;
  const _PlayerLoveBtn({required this.track});

  @override
  ConsumerState<_PlayerLoveBtn> createState() => _PlayerLoveBtnState();
}

class _PlayerLoveBtnState extends ConsumerState<_PlayerLoveBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    _busy = true;
    await _anim.forward();
    await _anim.reverse();
    final newLoved = await ref
        .read(historyProvider.notifier)
        .toggleLove(widget.track);
    final settings = ref.read(settingsProvider);
    if (settings.scrobbleReady) {
      final creds = LastFmService.resolve(
        userApiKey: settings.lastFmApiKey,
        userApiSecret: settings.lastFmApiSecret,
      );
      LastFmService.setLoved(
        sessionKey: settings.lastFmSessionKey!,
        creds: creds,
        artist: widget.track.displayArtist,
        track: widget.track.displayTitle,
        loved: newLoved,
      );
    }
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLoved = ref.watch(historyProvider).isLoved(widget.track);
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Icon(
              isLoved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 18,
              color: isLoved
                  ? const Color(0xFFFF6B8A)
                  : cs.onSurface.withValues(alpha: 0.28),
            ),
          ),
        ),
      ),
    );
  }
}
