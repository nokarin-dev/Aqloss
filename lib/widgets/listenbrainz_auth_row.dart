import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/widgets/ui/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/services/listenbrainz_service.dart';

class ListenBrainzAuthRow extends ConsumerStatefulWidget {
  const ListenBrainzAuthRow({super.key});

  @override
  ConsumerState<ListenBrainzAuthRow> createState() =>
      _ListenBrainzAuthRowState();
}

class _ListenBrainzAuthRowState extends ConsumerState<ListenBrainzAuthRow> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    Color a(double v) => onSurface.withValues(alpha: v);
    final hasToken = s.listenBrainzReady;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.person_outline_rounded, size: 17, color: a(0.36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasToken
                      ? 'Signed in as ${s.listenBrainzUsername ?? 'ListenBrainz user'}'
                      : 'Paste your user token',
                  style: TextStyle(fontSize: 13, color: a(0.70)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create one at listenbrainz.org/profile',
                  style: TextStyle(fontSize: 11, color: a(0.30)),
                ),
                if (!hasToken)
                  Text(
                    'listenbrainz.org/profile',
                    style: TextStyle(fontSize: 11, color: a(0.36)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_loading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: a(0.38),
              ),
            )
          else if (hasToken)
            GestureDetector(
              onTap: n.clearListenBrainz,
              child: _Chip(
                label: 'Sign out',
                onSurface: onSurface,
                filled: false,
              ),
            )
          else
            GestureDetector(
              onTap: () => _showTokenDialog(context, n),
              child: _Chip(
                label: 'Add token',
                onSurface: onSurface,
                filled: true,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showTokenDialog(BuildContext ctx, SettingsNotifier n) async {
    final tokenCtrl = TextEditingController();

    await showUiDialog<void>(
      context: ctx,
      title: 'ListenBrainz token',
      content: TextField(
        controller: tokenCtrl,
        obscureText: true,
        decoration: const InputDecoration(hintText: 'User token'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            setState(() => _loading = true);
            final user = await ListenBrainzService.validateToken(
              tokenCtrl.text,
            );
            if (!mounted) return;
            setState(() => _loading = false);
            if (user != null) {
              n.setListenBrainzToken(tokenCtrl.text.trim(), username: user);
            } else {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Invalid token.')));
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color onSurface;
  final bool filled;
  const _Chip({
    required this.label,
    required this.onSurface,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: filled ? onSurface.withValues(alpha: 0.08) : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: onSurface.withValues(alpha: 0.12)),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: onSurface.withValues(alpha: filled ? 0.70 : 0.44),
      ),
    ),
  );
}
