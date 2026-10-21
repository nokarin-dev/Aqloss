import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/widgets/ui/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/services/listenbrainz_service.dart';
import 'package:aqloss/l10n/l10n.dart';

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
                      ? trFill('integrations.signed_in', {
                          'name':
                              s.listenBrainzUsername ??
                              tr('integrations.lb_user'),
                        })
                      : tr('integrations.lb_paste'),
                  style: TextStyle(fontSize: 13, color: a(0.70)),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('integrations.lb_create'),
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
                label: tr('integrations.sign_out'),
                onSurface: onSurface,
                filled: false,
              ),
            )
          else
            GestureDetector(
              onTap: () => _showTokenDialog(context, n),
              child: _Chip(
                label: tr('integrations.lb_add'),
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
      title: tr('integrations.lb_token'),
      content: TextField(
        controller: tokenCtrl,
        obscureText: true,
        decoration: InputDecoration(hintText: tr('integrations.lb_user_token')),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(tr('integrations.cancel')),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('integrations.lb_invalid'))),
              );
            }
          },
          child: Text(tr('eq.save')),
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
