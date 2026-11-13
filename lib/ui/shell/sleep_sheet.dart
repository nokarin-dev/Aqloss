import 'package:aqloss/l10n/l10n.dart';
import 'package:aqloss/providers/player_provider.dart';
import 'package:aqloss/ui/shell/glass_morph.dart';
import 'package:aqloss/ui/shell/tokens.dart';
import 'package:aqloss/util/sleep_timer.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showSleepTimerSheet(BuildContext context, Offset origin) {
  return showShellMorph(
    context: context,
    origin: origin,
    motion: LiquidGlassMorphMotion.anchoredPop,
    menu: (_) => const SleepTimerSheet(key: ValueKey('sleep')),
  );
}

class SleepTimerSheet extends ConsumerWidget {
  const SleepTimerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    return ShellMenu(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Text(
            tr('sleep.title'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (player.sleepActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Text(
              sleepTimerTooltip(
                mode: player.sleepMode,
                until: player.sleepUntil,
              ),
              style: const TextStyle(color: textMuted, fontSize: 12),
            ),
          ),
        for (final mode in SleepTimerMode.values)
          ShellMenuRow(
            label: sleepTimerLabel(mode),
            selected: player.sleepMode == mode,
            onTap: () {
              ref.read(playerProvider.notifier).setSleepTimer(mode);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }
}
