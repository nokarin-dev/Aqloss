import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/history_provider.dart';
import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/widgets/q_sheet.dart';
import 'package:aqloss/widgets/q_toast.dart';
import 'package:aqloss/widgets/ui/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/l10n/l10n.dart';

Future<void> showTrackInfoSheet(BuildContext context, Track track) {
  return showQSheet(
    context: context,
    builder: (_) => TrackInfoSheet(track: track),
  );
}

class TrackInfoSheet extends ConsumerWidget {
  final Track track;

  const TrackInfoSheet({super.key, required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final plays = ref.watch(historyProvider).playCount(track.path);
    final number = track.trackNumber;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              track.displayTitle,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              track.uiArtistAlbum,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.36),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 14),
            const UiDivider(),
            const SizedBox(height: 8),
            if (number != null)
              _InfoRow(label: tr('library.track'), value: '$number'),
            _InfoRow(label: tr('library.album'), value: track.uiAlbum),
            _InfoRow(label: tr('library.format'), value: track.format),
            _InfoRow(
              label: tr('track.sample_rate'),
              value: track.sampleRateLabel,
            ),
            _InfoRow(label: tr('track.bit_depth'), value: track.bitDepthLabel),
            _InfoRow(label: tr('track.channels'), value: track.channelsLabel),
            _InfoRow(label: tr('library.duration'), value: track.durationLabel),
            _InfoRow(label: tr('track.file_size'), value: track.fileSizeLabel),
            _InfoRow(
              label: tr('track.replaygain'),
              value: track.replayGainTrackLabel,
            ),
            _InfoRow(
              label: tr('track.replaygain_album'),
              value: track.replayGainAlbumLabel,
            ),
            _InfoRow(
              label: tr('track.play_count'),
              value: plays == 0 ? '0' : '$plays',
            ),
            const SizedBox(height: 8),
            const UiDivider(),
            const SizedBox(height: 8),
            _InfoRow(label: tr('track.path'), value: track.path),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: track.path));
                  if (context.mounted) {
                    QToast.show(context, tr('track.path_copied'));
                  }
                },
                icon: Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: 0.50),
                ),
                label: Text(
                  tr('track.copy_path'),
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.50),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: onSurface.withValues(alpha: 0.36),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: onSurface.withValues(alpha: 0.82),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
