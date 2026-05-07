import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/lyrics_provider.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/widgets/player_controls.dart';
import 'package:aqloss/widgets/spectrum_display.dart';
import 'package:aqloss/widgets/lyrics_view.dart';
import 'package:aqloss/src/rust/api.dart' as backend;

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final track = player.currentTrack;
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      body: isWide
          ? _WideLayout(track: track, player: player)
          : _NarrowLayout(track: track, player: player),
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
    final hasLyrics = ref.watch(lyricsProvider).hasLyrics;
    final settings = ref.watch(settingsProvider);
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          width: hasLyrics ? width * 0.28 : width * 0.44,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 16, 24),
            child: Column(
              children: [
                // Album art card
                AspectRatio(
                  aspectRatio: 1,
                  child: _AlbumArtCard(
                    track: track,
                    showBackground: settings.showAlbumArtBackground,
                  ),
                ),
                if (hasLyrics) ...[
                  const SizedBox(height: 14),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
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
            padding: const EdgeInsets.fromLTRB(16, 32, 32, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TrackInfo(track: track),
                const SizedBox(height: 5),
                if (track != null) _FormatRow(track: track!),
                const Spacer(),
                // Spectrum
                if (settings.spectrumEnabled) ...[
                  SpectrumDisplay(
                    height: 36,
                    barCount: 32,
                    color: cs.onSurface.withValues(alpha: 0.10),
                  ),
                  const SizedBox(height: 18),
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

// Narrow layout
class _NarrowLayout extends ConsumerWidget {
  final Track? track;
  final PlayerState player;
  const _NarrowLayout({required this.track, required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLyrics = ref.watch(lyricsProvider).hasLyrics;
    final settings = ref.watch(settingsProvider);
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return SafeArea(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            height: size.height * (hasLyrics ? 0.46 : 0.70),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _AlbumArtCard(
                          track: track,
                          showBackground: settings.showAlbumArtBackground,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (settings.spectrumEnabled) ...[
                    SpectrumDisplay(
                      height: 16,
                      barCount: 24,
                      color: cs.onSurface.withValues(alpha: 0.10),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _TrackInfo(track: track),
                  const SizedBox(height: 3),
                  if (track != null) _FormatRow(track: track!),
                  const SizedBox(height: 12),
                  const PlayerControls(),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          if (track != null)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: cs.outline)),
                ),
                child: const LyricsView(),
              ),
            ),
        ],
      ),
    );
  }
}

// Album art card
class _AlbumArtCard extends ConsumerStatefulWidget {
  final Track? track;
  final bool showBackground;
  const _AlbumArtCard({this.track, required this.showBackground});

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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOut,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.97, end: 1.0).animate(anim),
          child: child,
        ),
      ),
      child: Stack(
        key: ValueKey('${widget.track?.path}_${widget.showBackground}'),
        children: [
          // Background art
          if (widget.showBackground && _artBytes != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
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
                              Colors.black.withValues(alpha: 0.30),
                              Colors.black.withValues(alpha: 0.52),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Main art container
          Container(
            decoration: BoxDecoration(
              color: widget.showBackground && _artBytes != null
                  ? Colors.transparent
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.onSurface.withValues(alpha: 0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 44,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _artBytes != null
                ? Image.memory(_artBytes!, fit: BoxFit.cover)
                : Center(
                    child: Icon(
                      Icons.music_note_rounded,
                      size: 60,
                      color: cs.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// Track info
class _TrackInfo extends StatelessWidget {
  final Track? track;
  const _TrackInfo({this.track});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width > 700;
    final artist = track?.artist;
    final album = track?.album;
    final subtitle = [?artist, ?album].join(' - ');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Column(
        key: ValueKey(track?.path),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            track?.displayTitle ?? 'Nothing playing',
            style: TextStyle(
              fontSize: isWide ? 20 : 18,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            subtitle.isEmpty ? '-' : subtitle,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.36),
              fontWeight: FontWeight.w300,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// Format row
class _FormatRow extends StatelessWidget {
  final Track track;
  const _FormatRow({required this.track});

  @override
  Widget build(BuildContext context) {
    final isExclusive = backend.isExclusiveMode();
    return Wrap(
      spacing: 5,
      runSpacing: 4,
      children: [
        _Badge(track.format),
        if (track.sampleRate > 0)
          _Badge(
            '${(track.sampleRate / 1000).toStringAsFixed(track.sampleRate % 1000 == 0 ? 0 : 1)} kHz',
          ),
        if (track.bitDepth != null) _Badge('${track.bitDepth}-bit'),
        if (isExclusive)
          _Badge(
            'BIT-PERFECT',
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.08),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color? color;
  const _Badge(this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: cs.onSurface.withValues(alpha: 0.28),
          letterSpacing: 0.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
