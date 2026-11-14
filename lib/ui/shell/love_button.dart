import 'package:aqloss/l10n/l10n.dart';
import 'package:aqloss/models/track.dart';
import 'package:aqloss/providers/history_provider.dart';
import 'package:aqloss/ui/shell/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoveButton extends ConsumerWidget {
  final Track track;

  const LoveButton({super.key, required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loved = ref.watch(
      historyProvider.select((state) => state.isLoved(track)),
    );
    return IconButton(
      tooltip: tr(loved ? 'track.unlove' : 'track.love'),
      onPressed: () {
        ref.read(historyProvider.notifier).toggleLove(track);
      },
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      icon: Icon(
        loved ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
        size: 16,
        color: loved ? Colors.white : textMuted,
      ),
    );
  }
}
