import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/widgets/ui/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/services/lastfm_service.dart';
import 'package:aqloss/l10n/l10n.dart';

class LastFmAuthRow extends ConsumerStatefulWidget {
  const LastFmAuthRow({super.key});
  @override
  ConsumerState<LastFmAuthRow> createState() => _LastFmAuthRowState();
}

class _LastFmAuthRowState extends ConsumerState<LastFmAuthRow> {
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
    final hasSession = s.lastFmSessionKey != null;
    final needsKey = s.needsUserKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (needsKey && !hasSession) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: a(0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: a(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('integrations.api_required'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: a(0.70),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr("integrations.api_missing"),
                    style: TextStyle(fontSize: 11, height: 1.4, color: a(0.40)),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showApiKeyDialog(context, n, s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: a(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: a(0.14)),
                      ),
                      child: Text(
                        tr('integrations.enter_api'),
                        style: TextStyle(fontSize: 11, color: a(0.70)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 17, color: a(0.36)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasSession
                            ? trFill('integrations.signed_in', {
                                'name': s.lastFmUsername ?? '',
                              })
                            : (s.lastFmUsername?.isNotEmpty == true
                                  ? s.lastFmUsername!
                                  : tr('integrations.signed_out')),
                        style: TextStyle(fontSize: 13, color: a(0.70)),
                      ),
                      if (hasSession)
                        Text(
                          tr('integrations.scrobbling'),
                          style: TextStyle(fontSize: 11, color: a(0.30)),
                        ),
                      if (!hasSession && !needsKey && s.hasBuiltInKey)
                        Text(
                          tr('integrations.builtin_key'),
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: a(0.24),
                          ),
                        ),
                      if (s.lastFmApiKey?.isNotEmpty == true)
                        Text(
                          tr('integrations.custom_key'),
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: a(0.24),
                          ),
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
                else if (hasSession)
                  GestureDetector(
                    onTap: n.clearLastFmSession,
                    child: _Chip(
                      label: tr('integrations.sign_out'),
                      onSurface: onSurface,
                      filled: false,
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => _showLoginDialog(context, n, s),
                    child: _Chip(
                      label: tr('integrations.sign_in'),
                      onSurface: onSurface,
                      filled: true,
                    ),
                  ),
              ],
            ),
          ),
          if (!s.hasBuiltInKey || s.lastFmApiKey?.isNotEmpty == true) ...[
            Divider(height: 1, color: a(0.05), indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.key_rounded, size: 15, color: a(0.24)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      s.lastFmApiKey?.isNotEmpty == true
                          ? tr('integrations.custom_set')
                          : tr('integrations.builtin_key'),
                      style: TextStyle(fontSize: 12, color: a(0.44)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showApiKeyDialog(context, n, s),
                    child: Text(
                      tr('integrations.change'),
                      style: TextStyle(fontSize: 11, color: a(0.36)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _showLoginDialog(
    BuildContext ctx,
    SettingsNotifier n,
    SettingsState s,
  ) async {
    final userCtrl = TextEditingController(text: s.lastFmUsername ?? '');
    final passCtrl = TextEditingController();

    await showUiDialog<void>(
      context: ctx,
      title: tr('integrations.lastfm_sign_in'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Field(controller: userCtrl, hint: tr('integrations.username')),
          const SizedBox(height: 10),
          _Field(
            controller: passCtrl,
            hint: tr('integrations.password'),
            obscure: true,
          ),
        ],
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
            n.setLastFmUsername(userCtrl.text.trim());
            final creds = LastFmService.resolve(
              userApiKey: s.lastFmApiKey,
              userApiSecret: s.lastFmApiSecret,
            );
            final key = await LastFmService.authenticate(
              username: userCtrl.text.trim(),
              password: passCtrl.text,
              creds: creds,
            );
            if (!mounted) return;
            setState(() => _loading = false);
            if (key != null) {
              n.setLastFmSession(key);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('integrations.sign_in_failed'))),
              );
            }
          },
          child: Text(tr('integrations.sign_in')),
        ),
      ],
    );
  }

  Future<void> _showApiKeyDialog(
    BuildContext ctx,
    SettingsNotifier n,
    SettingsState s,
  ) async {
    final keyCtrl = TextEditingController(text: s.lastFmApiKey ?? '');
    final secretCtrl = TextEditingController(text: s.lastFmApiSecret ?? '');

    await showUiDialog<void>(
      context: ctx,
      title: tr('integrations.lastfm_key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('integrations.lastfm_key_hint'),
            style: TextStyle(
              fontSize: 11,
              color: ctx.isMaterial3Ui
                  ? Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.36)
                  : ctx.aq.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 12),
          _Field(controller: keyCtrl, hint: tr('integrations.api_key')),
          const SizedBox(height: 10),
          _Field(controller: secretCtrl, hint: tr('integrations.secret')),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(tr('integrations.cancel')),
        ),
        if (s.lastFmApiKey?.isNotEmpty == true)
          TextButton(
            onPressed: () {
              n.setLastFmApiKey(null);
              n.setLastFmApiSecret(null);
              n.clearLastFmSession();
              Navigator.pop(ctx);
            },
            child: Text(tr('integrations.clear')),
          ),
        TextButton(
          onPressed: () {
            n.setLastFmApiKey(keyCtrl.text.trim());
            n.setLastFmApiSecret(secretCtrl.text.trim());
            n.clearLastFmSession();
            Navigator.pop(ctx);
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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  const _Field({
    required this.controller,
    required this.hint,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: onSurface, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.28)),
        filled: true,
        fillColor: isM3 ? cs.onSurface.withValues(alpha: 0.05) : aq.indicator,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}
