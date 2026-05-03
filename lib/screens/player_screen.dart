import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/lyrics_provider.dart';
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

class _WideLayout extends ConsumerWidget {
  final Track? track;
  final PlayerState player;
  const _WideLayout({required this.track, required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLyrics = ref.watch(lyricsProvider).hasLyrics;
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          width: hasLyrics
              ? MediaQuery.of(context).size.width * 0.28
              : MediaQuery.of(context).size.width * 0.46,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 36, 16, 28),
            child: Column(
              children: [
                AspectRatio(aspectRatio: 1, child: _AlbumArtCard(track: track)),
                if (hasLyrics) ...[
                  const SizedBox(height: 16),
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
            padding: const EdgeInsets.fromLTRB(16, 36, 36, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TrackInfo(track: track),
                const SizedBox(height: 6),
                if (track != null) _FormatRow(track: track!),
                const Spacer(),
                SpectrumDisplay(
                  height: 40,
                  barCount: 32,
                  color: cs.onSurface.withValues(alpha: 0.12),
                ),
                const SizedBox(height: 20),
                const PlayerControls(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NarrowLayout extends ConsumerWidget {
  final Track? track;
  final PlayerState player;
  const _NarrowLayout({required this.track, required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLyrics = ref.watch(lyricsProvider).hasLyrics;
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            height:
                MediaQuery.of(context).size.height * (hasLyrics ? 0.48 : 0.72),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _AlbumArtCard(track: track),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SpectrumDisplay(
                    height: 18,
                    barCount: 24,
                    color: cs.onSurface.withValues(alpha: 0.12),
                  ),
                  const SizedBox(height: 10),
                  _TrackInfo(track: track),
                  const SizedBox(height: 4),
                  if (track != null) _FormatRow(track: track!),
                  const SizedBox(height: 14),
                  const PlayerControls(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          if (track != null)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                child: const LyricsView(),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlbumArtCard extends ConsumerStatefulWidget {
  final Track? track;
  const _AlbumArtCard({this.track});

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
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(anim),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(widget.track?.path),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 40,
              offset: const Offset(0, 16),
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
                  color: cs.onSurface.withValues(alpha: 0.10),
                ),
              ),
      ),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  final Track? track;
  const _TrackInfo({this.track});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final artist = track?.artist;
    final album = track?.album;
    final subtitle = [?artist, ?album].join(' — ');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Column(
        key: ValueKey(track?.path),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            track?.displayTitle ?? 'Nothing playing',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle.isEmpty ? '—' : subtitle,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.38),
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

class _FormatRow extends StatelessWidget {
  final Track track;
  const _FormatRow({required this.track});

  @override
  Widget build(BuildContext context) {
    final isExclusive = backend.isExclusiveMode();
    return Wrap(
      spacing: 6,
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
            ).colorScheme.onSurface.withValues(alpha: 0.10),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: cs.onSurface.withValues(alpha: 0.30),
          letterSpacing: 0.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
