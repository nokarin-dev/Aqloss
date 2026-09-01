import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/util/sleep_timer.dart';
import 'package:aqloss/widgets/q_sheet.dart';
import 'package:aqloss/widgets/ui/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showSleepTimerSheet(BuildContext context) {
  return showQSheet(context: context, builder: (_) => const SleepTimerSheet());
}

class SleepTimerSheet extends ConsumerWidget {
  const SleepTimerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
            'Sleep timer',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (player.sleepActive) ...[
            const SizedBox(height: 4),
            StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (_, _) {
                final text = sleepTimerTooltip(
                  mode: player.sleepMode,
                  until: player.sleepUntil,
                );
                return Text(
                  text.replaceFirst('Sleep · ', ''),
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.36),
                    fontSize: 11,
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 14),
          const UiDivider(),
          const SizedBox(height: 8),
          for (final mode in SleepTimerMode.values)
            UiListTile(
              title: sleepTimerLabel(mode),
              selected: player.sleepMode == mode,
              onTap: () {
                ref.read(playerProvider.notifier).setSleepTimer(mode);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}
