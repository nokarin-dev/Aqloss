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

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final track = player.currentTrack;
    final isWide = MediaQuery.of(context).size.width > 700;

    if (!isWide) return const MobileNowPlaying();

    if (context.isMaterial3Ui) {
      return _M3WideLayout(track: track, player: player);
    }

    return UiPage(
      body: _WideLayout(track: track, player: player),
    );
  }
}

class _M3WideLayout extends ConsumerWidget {
  final Track? track;
  final PlayerState player;
  const _M3WideLayout({required this.track, required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(lyricsProvider);
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final showLyricsPanel = track != null;

    return ColoredBox(
      color: cs.surface,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: showLyricsPanel ? width * 0.32 : width * 0.42,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(36, 36, 20, 28),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: _AlbumArtCard(
                      track: track,
                      showBackground: settings.showAlbumArtBackground,
                      m3: true,
                    ),
                  ),
                  if (showLyricsPanel) ...[
                    const SizedBox(height: 20),
                    Expanded(
                      child: Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        color: cs.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: const LyricsView(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 40, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                  return parts.isEmpty
                                      ? '-'
                                      : parts.join(' · ');
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
                  ),
                  if (track != null) ...[
                    const SizedBox(height: 12),
                    _FormatRow(track: track!, soft: true),
                  ],
                  const Spacer(),
                  if (settings.spectrumEnabled) ...[
                    SpectrumDisplay(
                      height: 64,
                      barCount: 48,
                      color: cs.primary.withValues(alpha: 0.14),
                    ),
                    const SizedBox(height: 24),
                  ],
                  const PlayerControls(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Wide layout
class _WideLayout extends ConsumerWidget {
  final Track? track;
  final PlayerState player;
  const _WideLayout({required this.track, required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(lyricsProvider);
    final settings = ref.watch(settingsProvider);
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    final showLyricsPanel = track != null;

    return Row(
      children: [
        // Left
        AnimatedContainer(
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeInOutCubic,
          width: showLyricsPanel ? width * 0.28 : width * 0.44,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 34, 18, 26),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: _AlbumArtCard(
                    track: track,
                    showBackground: settings.showAlbumArtBackground,
                  ),
                ),
                if (showLyricsPanel) ...[
                  const SizedBox(height: 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: const LyricsView(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Right
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 34, 34, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TrackInfo(track: track),
                const SizedBox(height: 6),
                if (track != null) _FormatRow(track: track!),
                const Spacer(),
                // Spectrum
                if (settings.spectrumEnabled) ...[
                  SpectrumDisplay(
                    height: 72,
                    barCount: 48,
                    color: cs.onSurface.withValues(alpha: 0.09),
                  ),
                  const SizedBox(height: 20),
                ],
                const PlayerControls(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Album art card
class _AlbumArtCard extends ConsumerStatefulWidget {
  final Track? track;
  final bool showBackground;
  final bool m3;
  const _AlbumArtCard({
    this.track,
    required this.showBackground,
    this.m3 = false,
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
                    alpha: widget.m3 ? 0.28 : 0.60,
                  ),
                  blurRadius: widget.m3 ? 28 : 50,
                  offset: Offset(0, widget.m3 ? 12 : 20),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _artBytes != null
                ? Image.memory(_artBytes!, fit: BoxFit.cover)
                : Center(
                    child: Icon(
                      Icons.music_note_rounded,
                      size: 64,
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
  const _FormatRow({required this.track, this.soft = false});

  @override
  Widget build(BuildContext context) {
    final isExclusive = backend.isExclusiveMode();
    return Wrap(
      spacing: 5,
      runSpacing: 4,
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
