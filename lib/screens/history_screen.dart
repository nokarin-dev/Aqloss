import 'dart:io';
import 'dart:typed_data';

import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/history_provider.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/services/lastfm_service.dart';
import 'package:aqloss/src/rust/api.dart' as backend;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Root
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

enum _Tab { history, loved }

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _Tab _tab = _Tab.history;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: Row(
            children: [
              _TabPill(
                label: 'History',
                icon: Icons.history_rounded,
                active: _tab == _Tab.history,
                onTap: () => setState(() => _tab = _Tab.history),
              ),
              const SizedBox(width: 6),
              _TabPill(
                label: 'Loved',
                icon: Icons.favorite_rounded,
                active: _tab == _Tab.loved,
                onTap: () => setState(() => _tab = _Tab.loved),
              ),
            ],
          ),
        ),

        const SizedBox(height: 2),

        // Content
        Expanded(
          child: switch (_tab) {
            _Tab.history => const _HistoryTab(),
            _Tab.loved => const _LovedTab(),
          },
        ),
      ],
    );
  }
}

// History tab
class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    if (!history.loaded) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      );
    }

    if (history.entries.isEmpty) {
      return _EmptyState(
        icon: Icons.history_rounded,
        title: 'No plays yet',
        subtitle: 'Tracks you listen to will appear here.',
      );
    }

    // Group by date
    final grouped = <String, List<HistoryEntry>>{};
    for (final e in history.entries) {
      final key = _dateLabel(e.playedAt);
      grouped.putIfAbsent(key, () => []).add(e);
    }

    return Column(
      children: [
        // Stats bar
        _HistoryStats(history: history),

        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: grouped.length,
            itemBuilder: (context, idx) {
              final key = grouped.keys.elementAt(idx);
              final entries = grouped[key]!;
              return _DateSection(label: key, entries: entries);
            },
          ),
        ),

        // Clear button
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: _ClearHistoryButton(
            onConfirm: () => ref.read(historyProvider.notifier).clearHistory(),
          ),
        ),
      ],
    );
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);

    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}

class _HistoryStats extends StatelessWidget {
  final HistoryState history;
  const _HistoryStats({required this.history});

  @override
  Widget build(BuildContext context) {
    final todayCount = history.today.length;
    final weekCount = history.thisWeek.length;
    final totalCount = history.entries.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
      child: Row(
        children: [
          _StatChip(label: 'today', value: '$todayCount'),
          const SizedBox(width: 6),
          _StatChip(label: '7 days', value: '$weekCount'),
          const SizedBox(width: 6),
          _StatChip(label: 'all time', value: '$totalCount'),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.32),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateSection extends ConsumerWidget {
  final String label;
  final List<HistoryEntry> entries;
  const _DateSection({required this.label, required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: cs.onSurface.withValues(alpha: 0.28),
            ),
          ),
        ),
        for (final entry in entries) _HistoryTile(entry: entry),
      ],
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  final HistoryEntry entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final history = ref.watch(historyProvider);
    final isLoved = history.isLoved(entry.track);
    final player = ref.watch(playerProvider);
    final isPlaying = player.currentTrack?.path == entry.track.path;
    final track = entry.track;

    return _HoverableTile(
      onTap: () {
        final entries = ref.read(historyProvider).entries;
        final queue = entries.map((e) => e.track).toList();
        final entryIdx = entries.indexOf(entry);
        ref
            .read(playerProvider.notifier)
            .loadWithQueue(
              track,
              queue.isNotEmpty ? queue : [track],
              atIndex: entryIdx >= 0 ? entryIdx : null,
            );
      },
      builder: (hovered) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            // Art
            _MiniArt(path: track.path, size: 36, playing: isPlaying),
            const SizedBox(width: 10),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.displayTitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isPlaying
                          ? cs.onSurface
                          : cs.onSurface.withValues(alpha: 0.80),
                      fontWeight: isPlaying ? FontWeight.w500 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    track.displayArtist,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.34),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Time
            Text(
              _timeLabel(entry.playedAt),
              style: TextStyle(
                fontSize: 10.5,
                color: cs.onSurface.withValues(alpha: 0.24),
              ),
            ),
            const SizedBox(width: 8),

            // Love button
            AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: hovered || isLoved ? 1.0 : 0.0,
              child: _LoveButton(track: track, isLoved: isLoved),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// Loved tab
class _LovedTab extends ConsumerWidget {
  const _LovedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final library = ref.watch(libraryProvider);

    if (!history.loaded) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      );
    }

    if (history.lovedPaths.isEmpty) {
      return _EmptyState(
        icon: Icons.favorite_rounded,
        title: 'No loved tracks',
        subtitle: 'Tap the heart on any track to love it.',
      );
    }

    final trackByPath = {for (final t in library.tracks) t.path: t};
    final loved = history.lovedPaths
        .map((path) => trackByPath[path])
        .whereType<Track>()
        .toList();

    final ghosts = history.lovedPaths
        .where((p) => !trackByPath.containsKey(p))
        .toList();

    return Column(
      children: [
        // Count bar
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
          child: Row(
            children: [
              _StatChip(label: 'loved', value: '${history.lovedPaths.length}'),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final track in loved) _LovedTile(track: track),
              if (ghosts.isNotEmpty) ...[_GhostSection(paths: ghosts)],
            ],
          ),
        ),
      ],
    );
  }
}

class _LovedTile extends ConsumerWidget {
  final Track track;
  const _LovedTile({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final player = ref.watch(playerProvider);
    final isPlaying = player.currentTrack?.path == track.path;

    return _HoverableTile(
      onTap: () {
        final library = ref.read(libraryProvider);
        final lovedPaths = ref.read(historyProvider).lovedPaths;
        final trackByPath = {for (final t in library.tracks) t.path: t};
        final lovedTracks = lovedPaths
            .map((p) => trackByPath[p])
            .whereType<Track>()
            .toList();
        ref
            .read(playerProvider.notifier)
            .loadWithQueue(
              track,
              lovedTracks.isNotEmpty ? lovedTracks : [track],
            );
      },
      builder: (hovered) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            _MiniArt(path: track.path, size: 36, playing: isPlaying),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.displayTitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isPlaying
                          ? cs.onSurface
                          : cs.onSurface.withValues(alpha: 0.80),
                      fontWeight: isPlaying ? FontWeight.w500 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${track.displayArtist}${track.album != null ? ' · ${track.album}' : ''}',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.34),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: hovered ? 1.0 : 0.6,
              child: _LoveButton(track: track, isLoved: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _GhostSection extends ConsumerWidget {
  final List<String> paths;
  const _GhostSection({required this.paths});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 5),
          child: Text(
            'NOT IN LIBRARY',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
              color: cs.onSurface.withValues(alpha: 0.20),
            ),
          ),
        ),
        for (final path in paths)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 14,
                    color: cs.onSurface.withValues(alpha: 0.18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    path.split(Platform.pathSeparator).last,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurface.withValues(alpha: 0.26),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _IconBtn24(
                  icon: Icons.heart_broken_outlined,
                  onTap: () => ref
                      .read(historyProvider.notifier)
                      .setLoved(
                        Track(
                          path: path,
                          durationSecs: 0,
                          sampleRate: 44100,
                          channels: 2,
                          format: '',
                          fileSizeBytes: 0,
                        ),
                        loved: false,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Love button
class _LoveButton extends ConsumerStatefulWidget {
  final Track track;
  final bool isLoved;
  const _LoveButton({required this.track, required this.isLoved});

  @override
  ConsumerState<_LoveButton> createState() => _LoveButtonState();
}

class _LoveButtonState extends ConsumerState<_LoveButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.4,
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

    // Sync to Last.fm
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
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: Icon(
                widget.isLoved
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 15,
                color: widget.isLoved
                    ? const Color(0xFFFF6B8A)
                    : cs.onSurface.withValues(alpha: 0.30),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Shared primitives
class _TabPill extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _TabPill({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  State<_TabPill> createState() => _TabPillState();
}

class _TabPillState extends State<_TabPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.active
                ? cs.onSurface.withValues(alpha: 0.09)
                : _hovered
                ? cs.onSurface.withValues(alpha: 0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 13,
                color: widget.active
                    ? cs.onSurface.withValues(alpha: 0.80)
                    : cs.onSurface.withValues(alpha: 0.36),
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.active ? FontWeight.w500 : FontWeight.w400,
                  color: widget.active
                      ? cs.onSurface.withValues(alpha: 0.86)
                      : cs.onSurface.withValues(alpha: 0.40),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoverableTile extends StatefulWidget {
  final Widget Function(bool hovered) builder;
  final VoidCallback onTap;
  const _HoverableTile({required this.builder, required this.onTap});

  @override
  State<_HoverableTile> createState() => _HoverableTileState();
}

class _HoverableTileState extends State<_HoverableTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: _hovered
              ? cs.onSurface.withValues(alpha: 0.03)
              : Colors.transparent,
          child: widget.builder(_hovered),
        ),
      ),
    );
  }
}

class _MiniArt extends StatefulWidget {
  final String path;
  final double size;
  final bool playing;
  const _MiniArt({
    required this.path,
    required this.size,
    required this.playing,
  });

  @override
  State<_MiniArt> createState() => _MiniArtState();
}

class _MiniArtState extends State<_MiniArt> {
  Uint8List? _art;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_MiniArt old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _art = null;
      _tried = false;
      _load();
    }
  }

  Future<void> _load() async {
    if (_tried) return;
    _tried = true;
    try {
      final bytes = await backend.readAlbumArtThumbnail(path: widget.path);
      if (mounted && bytes != null) setState(() => _art = bytes);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(5);

    Widget art = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.05),
        borderRadius: radius,
      ),
      child: _art != null
          ? ClipRRect(
              borderRadius: radius,
              child: Image.memory(
                _art!,
                fit: BoxFit.cover,
                width: widget.size,
                height: widget.size,
              ),
            )
          : Icon(
              Icons.music_note_rounded,
              size: widget.size * 0.4,
              color: cs.onSurface.withValues(alpha: 0.18),
            ),
    );

    if (widget.playing) {
      art = Stack(
        children: [
          art,
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.40),
              borderRadius: radius,
            ),
            child: const Icon(
              Icons.equalizer_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
        ],
      );
    }

    return art;
  }
}

class _IconBtn24 extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn24({required this.icon, required this.onTap});

  @override
  State<_IconBtn24> createState() => _IconBtn24State();
}

class _IconBtn24State extends State<_IconBtn24> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _hovered
                ? cs.onSurface.withValues(alpha: 0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(
            widget.icon,
            size: 13,
            color: cs.onSurface.withValues(alpha: 0.30),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: cs.onSurface.withValues(alpha: 0.12)),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.36),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: cs.onSurface.withValues(alpha: 0.22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearHistoryButton extends StatefulWidget {
  final VoidCallback onConfirm;
  const _ClearHistoryButton({required this.onConfirm});

  @override
  State<_ClearHistoryButton> createState() => _ClearHistoryButtonState();
}

class _ClearHistoryButtonState extends State<_ClearHistoryButton> {
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      child: _confirming
          ? Row(
              children: [
                Text(
                  'Clear all history?',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.40),
                  ),
                ),
                const SizedBox(width: 10),
                _SmallBtn(
                  label: 'Yes, clear',
                  danger: true,
                  onTap: () {
                    widget.onConfirm();
                    setState(() => _confirming = false);
                  },
                ),
                const SizedBox(width: 6),
                _SmallBtn(
                  label: 'Cancel',
                  danger: false,
                  onTap: () => setState(() => _confirming = false),
                ),
              ],
            )
          : _SmallBtn(
              label: 'Clear history',
              danger: false,
              onTap: () => setState(() => _confirming = true),
            ),
    );
  }
}

class _SmallBtn extends StatefulWidget {
  final String label;
  final bool danger;
  final VoidCallback onTap;
  const _SmallBtn({
    required this.label,
    required this.danger,
    required this.onTap,
  });

  @override
  State<_SmallBtn> createState() => _SmallBtnState();
}

class _SmallBtnState extends State<_SmallBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered
                ? (widget.danger
                      ? cs.error.withValues(alpha: 0.10)
                      : cs.onSurface.withValues(alpha: 0.06))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.danger
                  ? cs.error.withValues(alpha: 0.25)
                  : cs.onSurface.withValues(alpha: 0.10),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              color: widget.danger
                  ? cs.error.withValues(alpha: 0.70)
                  : cs.onSurface.withValues(alpha: 0.48),
            ),
          ),
        ),
      ),
    );
  }
}
