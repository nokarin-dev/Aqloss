import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/util/eq_presets.dart';
import 'package:aqloss/widgets/q_sheet.dart';
import 'package:aqloss/widgets/q_toast.dart';
import 'package:aqloss/widgets/shared/input_dialog.dart';
import 'package:aqloss/widgets/ui/ui_kit.dart';
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
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;

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
                    onSurface: onSurface,
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
                  color: onSurface.withValues(alpha: 0.08),
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '0 dB',
                style: TextStyle(
                  fontSize: 9,
                  color: onSurface.withValues(alpha: 0.24),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(
                  color: onSurface.withValues(alpha: 0.08),
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _EqAction(
                label:
                    matchingEqPresetName(s.eqGains, s.eqUserPresets) ??
                    'Presets',
                onTap: () => showQSheet(
                  context: context,
                  builder: (_) => const _EqPresetSheet(),
                ),
              ),
              _EqAction(label: 'Save', onTap: () => _savePreset(context, ref)),
              _EqAction(label: 'Reset', onTap: n.resetEq),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _savePreset(BuildContext context, WidgetRef ref) async {
  final ctrl = TextEditingController(
    text:
        matchingEqPresetName(
          ref.read(settingsProvider).eqGains,
          ref.read(settingsProvider).eqUserPresets,
        ) ??
        '',
  );
  if (isBuiltInEqPresetName(ctrl.text)) ctrl.clear();
  final raw = await showDialog<String>(
    context: context,
    builder: (ctx) => InputDialog(
      title: 'Save EQ preset',
      hint: 'Preset name',
      confirmLabel: 'Save',
      controller: ctrl,
    ),
  );
  ctrl.dispose();
  if (raw == null || !context.mounted) return;
  final result = ref.read(settingsProvider.notifier).saveEqPreset(raw);
  final message = switch (result) {
    EqPresetSaveResult.ok => 'Saved',
    EqPresetSaveResult.emptyName => 'Name required',
    EqPresetSaveResult.builtInName => 'That name is a built-in preset',
    EqPresetSaveResult.full => 'Remove a saved preset first',
  };
  if (context.mounted) QToast.show(context, message);
}

class _EqAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _EqAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: onSurface.withValues(alpha: 0.08)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: onSurface.withValues(alpha: 0.40),
          ),
        ),
      ),
    );
  }
}

class _EqPresetSheet extends ConsumerWidget {
  const _EqPresetSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final selected = matchingEqPresetName(s.eqGains, s.eqUserPresets);

    void apply(EqPreset preset) {
      n.applyEqPreset(preset);
      Navigator.pop(context);
    }

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
              'EQ presets',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 14),
            const UiDivider(),
            const SizedBox(height: 8),
            for (final p in kBuiltInEqPresets)
              UiListTile(
                title: p.name,
                selected: selected == p.name,
                onTap: () => apply(p),
              ),
            if (s.eqUserPresets.isNotEmpty) ...[
              const SizedBox(height: 8),
              const UiDivider(),
              const SizedBox(height: 8),
              for (final p in s.eqUserPresets)
                UiListTile(
                  title: p.name,
                  selected: selected == p.name,
                  trailing: IconButton(
                    tooltip: 'Delete',
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: cs.onSurface.withValues(alpha: 0.36),
                    ),
                    onPressed: () => n.deleteEqUserPreset(p.name),
                  ),
                  onTap: () => apply(p),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  final String label;
  final double gain;
  final ValueChanged<double> onChanged;
  final Color onSurface;

  const _BandSlider({
    required this.label,
    required this.gain,
    required this.onChanged,
    required this.onSurface,
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
                ? onSurface.withValues(alpha: 0.70)
                : onSurface.withValues(alpha: 0.24),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        // Vertical slider
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: _EqBandSlider(
              gain: gain,
              onSurface: onSurface,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Frequency label
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: onSurface.withValues(alpha: 0.30),
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
  final Color onSurface;
  final ValueChanged<double> onChanged;
  const _EqBandSlider({
    required this.gain,
    required this.onSurface,
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
                    ? widget.onSurface.withValues(alpha: 0.60)
                    : widget.onSurface.withValues(alpha: 0.20),
                inactiveColor: widget.onSurface.withValues(alpha: 0.08),
                thumbColor: active
                    ? widget.onSurface.withValues(alpha: 0.80)
                    : widget.onSurface.withValues(alpha: 0.30),
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
