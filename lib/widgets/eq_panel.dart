import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/settings_provider.dart';

const _eqFreqLabels = [
  '31',
  '62',
  '125',
  '250',
  '500',
  '1k',
  '2k',
  '4k',
  '8k',
  '16k',
];

class EqPanel extends ConsumerWidget {
  const EqPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Band sliders
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(10, (i) {
                final gain = s.eqGains.length > i ? s.eqGains[i] : 0.0;
                return Expanded(
                  child: _BandSlider(
                    label: _eqFreqLabels[i],
                    gain: gain,
                    onChanged: (v) => n.setEqBand(i, v),
                    cs: cs,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          // 0 dB reference line label
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: cs.onSurface.withValues(alpha: 0.08),
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '0 dB',
                style: TextStyle(
                  fontSize: 9,
                  color: cs.onSurface.withValues(alpha: 0.24),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(
                  color: cs.onSurface.withValues(alpha: 0.08),
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Reset button
          GestureDetector(
            onTap: n.resetEq,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
              ),
              child: Text(
                'Reset all bands',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.40),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  final String label;
  final double gain;
  final ValueChanged<double> onChanged;
  final ColorScheme cs;

  const _BandSlider({
    required this.label,
    required this.gain,
    required this.onChanged,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final gainStr = gain >= 0
        ? '+${gain.toStringAsFixed(1)}'
        : gain.toStringAsFixed(1);
    return Column(
      children: [
        // Gain label
        Text(
          gainStr,
          style: TextStyle(
            fontSize: 8,
            color: gain.abs() > 0.5
                ? cs.onSurface.withValues(alpha: 0.70)
                : cs.onSurface.withValues(alpha: 0.24),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        // Vertical slider
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                trackHeight: 2,
                activeTrackColor: gain.abs() > 0.5
                    ? cs.onSurface.withValues(alpha: 0.60)
                    : cs.onSurface.withValues(alpha: 0.20),
                inactiveTrackColor: cs.onSurface.withValues(alpha: 0.08),
                thumbColor: gain.abs() > 0.5
                    ? cs.onSurface.withValues(alpha: 0.80)
                    : cs.onSurface.withValues(alpha: 0.30),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: gain,
                min: -12,
                max: 12,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Frequency label
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: cs.onSurface.withValues(alpha: 0.30),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
