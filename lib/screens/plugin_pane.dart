import 'package:aqloss/plugins/plugin_api.dart';
import 'package:aqloss/plugins/plugin_io_service.dart';
import 'package:aqloss/providers/plugin_provider.dart';
import 'package:aqloss/widgets/q_toast.dart';
import 'package:aqloss/widgets/ui/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PluginsPane extends ConsumerWidget {
  const PluginsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pluginProvider);
    final cs = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.widgets_outlined,
                          size: 16,
                          color: cs.onSurface.withValues(alpha: 0.30),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Plugins',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.88),
                            fontSize: 18,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Text(
                        '${state.manifests.length} plugin${state.manifests.length == 1 ? '' : 's'} installed',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.26),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                _InstallButton(installing: state.installing, cs: cs),
              ],
            ),
          ),
        ),
        if (state.manifests.isEmpty)
          const SliverFillRemaining(child: _EmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                final m = state.manifests[i];
                return Column(
                  children: [
                    if (i == 0) _CardTop(cs: cs),
                    _PluginRow(
                      manifest: m,
                      enabled: state.isEnabled(m.id),
                      cs: cs,
                    ),
                    if (i < state.manifests.length - 1)
                      const UiDivider(
                        margin: EdgeInsets.symmetric(horizontal: 14),
                      )
                    else
                      _CardBottom(cs: cs),
                  ],
                );
              }, childCount: state.manifests.length),
            ),
          ),
      ],
    );
  }
}

// Install button
class _InstallButton extends ConsumerWidget {
  final bool installing;
  final ColorScheme cs;
  const _InstallButton({required this.installing, required this.cs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: installing ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: installing ? null : () => _doInstall(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (installing)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                )
              else
                Icon(
                  Icons.add_rounded,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              const SizedBox(width: 6),
              Text(
                installing ? 'Installing…' : 'Install .aqx',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doInstall(BuildContext context, WidgetRef ref) async {
    final preview = await ref.read(pluginProvider.notifier).previewInstall();
    if (!context.mounted) return;

    if (preview.cancelled) return;

    if (!preview.ok) {
      QToast.show(context, preview.userMessage);
      return;
    }

    final proceed = await _PermissionReviewSheet.show(
      context,
      manifest: preview.manifest!,
    );
    if (!proceed || !context.mounted) return;

    final result = await ref
        .read(pluginProvider.notifier)
        .installBytes(preview.bytes!);
    if (!context.mounted) return;

    if (!result.cancelled) {
      QToast.show(context, result.userMessage);
    }
  }
}

// Plugin row
class _PluginRow extends ConsumerStatefulWidget {
  final PluginManifest manifest;
  final bool enabled;
  final ColorScheme cs;

  const _PluginRow({
    required this.manifest,
    required this.enabled,
    required this.cs,
  });

  @override
  ConsumerState<_PluginRow> createState() => _PluginRowState();
}

class _PluginRowState extends ConsumerState<_PluginRow> {
  bool _hovered = false;
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.manifest;
    final cs = widget.cs;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        color: _hovered || _menuOpen
            ? cs.onSurface.withValues(alpha: 0.025)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.extension_rounded,
                  size: 15,
                  color: cs.onSurface.withValues(alpha: 0.28),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          m.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.80),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _VersionChip(version: m.version, cs: cs),
                        const SizedBox(width: 5),
                        Text(
                          'by ${m.author}',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.22),
                          ),
                        ),
                      ],
                    ),
                    if (m.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        m.description!,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.30),
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (m.permissions.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      _PermBadgeRow(permissions: m.permissions, cs: cs),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniSwitch(
                    value: widget.enabled,
                    onChanged: (v) => ref
                        .read(pluginProvider.notifier)
                        .setEnabled(m.id, enabled: v),
                    cs: cs,
                  ),
                  const SizedBox(width: 4),
                  _MoreMenu(
                    manifest: m,
                    cs: cs,
                    onOpen: () => setState(() => _menuOpen = true),
                    onClose: () => setState(() => _menuOpen = false),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// More menu
class _MoreMenu extends ConsumerWidget {
  final PluginManifest manifest;
  final ColorScheme cs;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  const _MoreMenu({
    required this.manifest,
    required this.cs,
    required this.onOpen,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_MenuAction>(
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 16,
        color: cs.onSurface.withValues(alpha: 0.28),
      ),
      padding: EdgeInsets.zero,
      splashRadius: 14,
      tooltip: '',
      onOpened: onOpen,
      onCanceled: onClose,
      onSelected: (action) {
        onClose();
        switch (action) {
          case _MenuAction.uninstall:
            _confirmUninstall(context, ref);
          case _MenuAction.export:
            _export(context);
        }
      },
      itemBuilder: (_) => [
        _menuItem(
          _MenuAction.export,
          Icons.ios_share_rounded,
          'Export .aqx',
          cs,
        ),
        _menuItem(
          _MenuAction.uninstall,
          Icons.delete_outline_rounded,
          'Uninstall',
          cs,
          destructive: true,
        ),
      ],
    );
  }

  PopupMenuItem<_MenuAction> _menuItem(
    _MenuAction action,
    IconData icon,
    String label,
    ColorScheme cs, {
    bool destructive = false,
  }) {
    final color = destructive
        ? Colors.redAccent.shade100
        : cs.onSurface.withValues(alpha: 0.70);
    return PopupMenuItem(
      value: action,
      height: 36,
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Future<void> _confirmUninstall(BuildContext context, WidgetRef ref) async {
    final confirmed = await showUiDialog<bool>(
      context: context,
      title: 'Uninstall "${manifest.name}"?',
      content: Text(
        'The plugin and all of its files will be removed from disk.',
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Uninstall',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    );

    if (confirmed == true && context.mounted) {
      final ok = await ref.read(pluginProvider.notifier).uninstall(manifest.id);
      if (context.mounted) {
        QToast.show(
          context,
          ok
              ? '"${manifest.name}" uninstalled.'
              : 'Could not uninstall "${manifest.name}".',
        );
      }
    }
  }

  Future<void> _export(BuildContext context) async {
    final ok = await PluginIOService.exportPlugin(manifest.id);
    if (context.mounted && ok) {
      QToast.show(context, '"${manifest.name}" exported.');
    }
  }
}

enum _MenuAction { uninstall, export }

// Permission review sheet
class _PermissionReviewSheet extends StatelessWidget {
  final PluginManifest manifest;
  const _PermissionReviewSheet({required this.manifest});

  static Future<bool> show(
    BuildContext context, {
    required PluginManifest manifest,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PermissionReviewSheet(manifest: manifest),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security_outlined,
                size: 18,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 8),
              Text(
                'Install “${manifest.name}”?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            manifest.permissions.isEmpty
                ? 'This plugin does not request any extra permissions.'
                : 'This plugin requests the permissions below. Only install plugins from sources you trust.',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.45),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          if (manifest.permissions.contains(PluginPermission.network))
            _InfoRow(
              icon: Icons.wifi_outlined,
              label: 'network',
              desc: 'Outgoing HTTP requests',
              cs: cs,
            ),
          if (manifest.permissions.contains(PluginPermission.filesystem))
            _InfoRow(
              icon: Icons.folder_outlined,
              label: 'filesystem',
              desc: 'Read files inside the plugin folder',
              cs: cs,
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Install',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final ColorScheme cs;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.desc,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 13, color: cs.onSurface.withValues(alpha: 0.30)),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: cs.onSurface.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '-',
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurface.withValues(alpha: 0.20),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          desc,
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurface.withValues(alpha: 0.35),
          ),
        ),
      ],
    ),
  );
}

// Shared UI primitives
class _CardTop extends StatelessWidget {
  final ColorScheme cs;
  const _CardTop({required this.cs});

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    decoration: BoxDecoration(
      color: cs.onSurface.withValues(alpha: 0.05),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
    ),
  );
}

class _CardBottom extends StatelessWidget {
  final ColorScheme cs;
  const _CardBottom({required this.cs});

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    decoration: BoxDecoration(
      color: cs.onSurface.withValues(alpha: 0.05),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
    ),
  );
}

class _VersionChip extends StatelessWidget {
  final String version;
  final ColorScheme cs;
  const _VersionChip({required this.version, required this.cs});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: cs.onSurface.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      'v$version',
      style: TextStyle(
        fontSize: 10,
        fontFamily: 'monospace',
        color: cs.onSurface.withValues(alpha: 0.30),
      ),
    ),
  );
}

class _PermBadgeRow extends StatelessWidget {
  final Set<PluginPermission> permissions;
  final ColorScheme cs;
  const _PermBadgeRow({required this.permissions, required this.cs});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    children: permissions.map((p) => _PermBadge(perm: p, cs: cs)).toList(),
  );
}

class _PermBadge extends StatelessWidget {
  final PluginPermission perm;
  final ColorScheme cs;
  const _PermBadge({required this.perm, required this.cs});

  String get _label => switch (perm) {
    PluginPermission.network => 'network',
    PluginPermission.filesystem => 'filesystem',
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: cs.onSurface.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
    ),
    child: Text(
      _label,
      style: TextStyle(
        fontSize: 9.5,
        fontFamily: 'monospace',
        color: cs.onSurface.withValues(alpha: 0.28),
      ),
    ),
  );
}

class _MiniSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final ColorScheme cs;

  const _MiniSwitch({
    required this.value,
    required this.onChanged,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 34,
      height: 20,
      decoration: BoxDecoration(
        color: value
            ? cs.primary.withValues(alpha: 0.85)
            : cs.onSurface.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeInOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.all(2),
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.extension_off_outlined,
            size: 36,
            color: cs.onSurface.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 12),
          Text(
            'No plugins installed',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.28),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Click “Install .aqx” above to add the plugin.',
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}
