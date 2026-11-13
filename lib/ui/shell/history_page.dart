import 'package:aqloss/l10n/l10n.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/history_provider.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/ui/shell/album_art.dart';
import 'package:aqloss/ui/shell/tokens.dart';
import 'package:aqloss/ui/shell/track_menu.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _line = Color(0xFF2D2D2D);

const _title = TextStyle(
  color: Colors.white,
  fontSize: 28,
  height: 36 / 28,
  fontWeight: FontWeight.w600,
);

const _section = TextStyle(
  color: Colors.white,
  fontSize: 16,
  fontWeight: FontWeight.w600,
);

class HistoryPage extends ConsumerWidget {
  final VoidCallback onOpenHome;

  const HistoryPage({super.key, required this.onOpenHome});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final current = ref.watch(
      playerProvider.select((player) => player.currentTrack?.path),
    );
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final days = _days(history.entries);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        wide ? 50 : 20,
        wide ? 50 : 24,
        wide ? 50 : 20,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tr('history'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _title,
                  ),
                ),
                if (history.entries.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      ref.read(historyProvider.notifier).clearHistory();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: textMuted,
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      tr('history.clear'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: !history.loaded
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: textMuted,
                      ),
                    ),
                  )
                : days.isEmpty
                ? _Empty(onOpenHome: onOpenHome)
                : _Days(days: days, current: current),
          ),
        ],
      ),
    );
  }
}

class _Days extends ConsumerWidget {
  final List<_Day> days;
  final String? current;

  const _Days({required this.days, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final tracks = [for (final day in days) ...day.entries.map((e) => e.track)];

    return ListView.builder(
      padding: const EdgeInsets.only(top: 18, bottom: playerClearance),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 22, bottom: 10),
              child: Text(_label(day.day, now, labels), style: _section),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _line),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Column(
                  children: [
                    for (var i = 0; i < day.entries.length; i++) ...[
                      if (i > 0)
                        const ColoredBox(
                          color: _line,
                          child: SizedBox(height: 1, width: double.infinity),
                        ),
                      _Row(
                        track: day.entries[i].track,
                        active: day.entries[i].track.path == current,
                        onTap: () {
                          final from = day.start + i;
                          ref
                              .read(playerProvider.notifier)
                              .loadWithQueue(
                                day.entries[i].track,
                                tracks.sublist(from),
                              );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  final Track track;
  final bool active;
  final VoidCallback onTap;

  const _Row({required this.track, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TrackMenu(
      track: track,
      child: Material(
        color: active ? const Color(0x14FFFFFF) : Colors.transparent,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 12),
                MiniAlbumArt(path: track.path, size: 40, radius: 8),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        track.uiArtist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  track.durationLabel,
                  style: const TextStyle(color: textMuted, fontSize: 12),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onOpenHome;

  const _Empty({required this.onOpenHome});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: playerClearance),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 420
                ? constraints.maxWidth
                : 420.0;
            return SizedBox(
              width: width,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  mouseCursor: SystemMouseCursors.click,
                  onTap: onOpenHome,
                  borderRadius: BorderRadius.circular(16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _line),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 32,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.search,
                            size: 22,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            tr('history.empty'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 22 / 15,
                            ),
                          ),
                          Text(
                            tr('history.empty_hint'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 22 / 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Day {
  final DateTime day;
  final List<HistoryEntry> entries;
  final int start;

  const _Day(this.day, this.entries, this.start);
}

// playedAt is stored with an offset, so the day is local.
List<_Day> _days(List<HistoryEntry> entries) {
  final grouped = <DateTime, List<HistoryEntry>>{};
  for (final entry in entries) {
    final at = entry.playedAt.toLocal();
    final day = DateTime(at.year, at.month, at.day);
    (grouped[day] ??= []).add(entry);
  }
  final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  var start = 0;
  final days = <_Day>[];
  for (final day in keys) {
    final group = grouped[day]!;
    days.add(_Day(day, group, start));
    start += group.length;
  }
  return days;
}

String _label(DateTime day, DateTime now, MaterialLocalizations labels) {
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) return tr('history.today');
  if (day == today.subtract(const Duration(days: 1))) {
    return tr('history.yesterday');
  }
  return labels.formatMediumDate(day);
}
