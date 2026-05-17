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
            child: _EqBandSlider(gain: gain, cs: cs, onChanged: onChanged),
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

// EQ band slider
class _EqBandSlider extends StatefulWidget {
  final double gain;
  final ColorScheme cs;
  final ValueChanged<double> onChanged;
  const _EqBandSlider({
    required this.gain,
    required this.cs,
    required this.onChanged,
  });
  @override
  State<_EqBandSlider> createState() => _EqBandSliderState();
}

class _EqBandSliderState extends State<_EqBandSlider> {
  static const _min = -12.0;
  static const _max = 12.0;

  void _update(double localX, double width) {
    final norm = (localX / width).clamp(0.0, 1.0);
    final raw = _min + norm * (_max - _min);
    final snapped = (raw / 0.5).round() * 0.5;
    widget.onChanged(snapped.clamp(_min, _max));
  }

  @override
  Widget build(BuildContext context) {
    final norm = ((widget.gain - _min) / (_max - _min)).clamp(0.0, 1.0);
    final active = widget.gain.abs() > 0.5;
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _update(d.localPosition.dx, w),
          onHorizontalDragUpdate: (d) => _update(d.localPosition.dx, w),
          child: SizedBox(
            height: constraints.maxHeight,
            child: CustomPaint(
              size: Size(w, constraints.maxHeight),
              painter: _EqSliderPainter(
                norm: norm,
                activeColor: active
                    ? widget.cs.onSurface.withValues(alpha: 0.60)
                    : widget.cs.onSurface.withValues(alpha: 0.20),
                inactiveColor: widget.cs.onSurface.withValues(alpha: 0.08),
                thumbColor: active
                    ? widget.cs.onSurface.withValues(alpha: 0.80)
                    : widget.cs.onSurface.withValues(alpha: 0.30),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EqSliderPainter extends CustomPainter {
  final double norm;
  final Color activeColor, inactiveColor, thumbColor;
  const _EqSliderPainter({
    required this.norm,
    required this.activeColor,
    required this.inactiveColor,
    required this.thumbColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const r = 5.0;
    final cy = size.height / 2;
    final left = r;
    final right = size.width - r;
    final fillX = left + (right - left) * norm;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(left, cy), Offset(right, cy), inactivePaint);
    if (fillX > left) {
      canvas.drawLine(Offset(left, cy), Offset(fillX, cy), activePaint);
    }
    canvas.drawCircle(Offset(fillX, cy), r, Paint()..color = thumbColor);
  }

  @override
  bool shouldRepaint(_EqSliderPainter old) =>
      old.norm != norm || old.activeColor != activeColor;
}
