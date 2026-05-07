import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/settings_provider.dart';
import 'package:aqloss/services/lastfm_service.dart';

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
    final cs = Theme.of(context).colorScheme;
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
                color: cs.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'API Key required',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface.withValues(alpha: 0.70),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This build doesn\'t include a Last.fm API key. '
                    'Get a free key at https://last.fm/api/account/create, '
                    'then enter it below.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: cs.onSurface.withValues(alpha: 0.40),
                    ),
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
                        color: cs.onSurface.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: cs.onSurface.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Text(
                        'Enter API key',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.70),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          // Account row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 17,
                  color: cs.onSurface.withValues(alpha: 0.36),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasSession
                            ? 'Signed in as ${s.lastFmUsername ?? ''}'
                            : (s.lastFmUsername?.isNotEmpty == true
                                  ? s.lastFmUsername!
                                  : 'Not signed in'),
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.70),
                        ),
                      ),
                      if (hasSession)
                        Text(
                          'Scrobbling active',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.30),
                          ),
                        ),
                      if (!hasSession && !needsKey && s.hasBuiltInKey)
                        Text(
                          'Using built-in API key',
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: cs.onSurface.withValues(alpha: 0.24),
                          ),
                        ),
                      if (s.lastFmApiKey?.isNotEmpty == true)
                        Text(
                          'Using your API key',
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: cs.onSurface.withValues(alpha: 0.24),
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
                      color: cs.onSurface.withValues(alpha: 0.38),
                    ),
                  )
                else if (hasSession)
                  GestureDetector(
                    onTap: n.clearLastFmSession,
                    child: _Chip(label: 'Sign out', cs: cs, filled: false),
                  )
                else
                  GestureDetector(
                    onTap: () => _showLoginDialog(context, n, s),
                    child: _Chip(label: 'Sign in', cs: cs, filled: true),
                  ),
              ],
            ),
          ),

          if (!s.hasBuiltInKey || s.lastFmApiKey?.isNotEmpty == true) ...[
            Divider(
              height: 1,
              color: cs.onSurface.withValues(alpha: 0.05),
              indent: 16,
              endIndent: 16,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.key_rounded,
                    size: 15,
                    color: cs.onSurface.withValues(alpha: 0.24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      s.lastFmApiKey?.isNotEmpty == true
                          ? 'Custom API key set'
                          : 'Using built-in API key',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.44),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showApiKeyDialog(context, n, s),
                    child: Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.36),
                      ),
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
    final cs = Theme.of(ctx).colorScheme;

    await showDialog<void>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Sign in to Last.fm',
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w400,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Field(controller: userCtrl, hint: 'Username'),
            const SizedBox(height: 10),
            _Field(controller: passCtrl, hint: 'Password', obscure: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.38),
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dCtx);
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
                  const SnackBar(
                    content: Text(
                      'Sign-in failed. Check credentials or API key.',
                    ),
                  ),
                );
              }
            },
            child: Text(
              'Sign in',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.80),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showApiKeyDialog(
    BuildContext ctx,
    SettingsNotifier n,
    SettingsState s,
  ) async {
    final keyCtrl = TextEditingController(text: s.lastFmApiKey ?? '');
    final secretCtrl = TextEditingController(text: s.lastFmApiSecret ?? '');
    final cs = Theme.of(ctx).colorScheme;

    await showDialog<void>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Last.fm API Key',
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w400,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get a free key at last.fm/api/account/create',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.36),
              ),
            ),
            const SizedBox(height: 12),
            _Field(controller: keyCtrl, hint: 'API Key'),
            const SizedBox(height: 10),
            _Field(controller: secretCtrl, hint: 'Shared Secret'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.38),
                fontSize: 13,
              ),
            ),
          ),
          if (s.lastFmApiKey?.isNotEmpty == true)
            TextButton(
              onPressed: () {
                n.setLastFmApiKey(null);
                n.setLastFmApiSecret(null);
                n.clearLastFmSession();
                Navigator.pop(dCtx);
              },
              child: Text(
                'Clear',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.38),
                  fontSize: 13,
                ),
              ),
            ),
          TextButton(
            onPressed: () {
              n.setLastFmApiKey(keyCtrl.text.trim());
              n.setLastFmApiSecret(secretCtrl.text.trim());
              n.clearLastFmSession();
              Navigator.pop(dCtx);
            },
            child: Text(
              'Save',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.80),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  final bool filled;
  const _Chip({required this.label, required this.cs, required this.filled});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: filled ? cs.onSurface.withValues(alpha: 0.08) : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: cs.onSurface.withValues(alpha: 0.12)),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: cs.onSurface.withValues(alpha: filled ? 0.70 : 0.44),
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
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: cs.onSurface, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.28)),
        filled: true,
        fillColor: cs.onSurface.withValues(alpha: 0.05),
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
