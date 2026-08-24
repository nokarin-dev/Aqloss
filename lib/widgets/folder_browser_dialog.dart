import 'dart:io';

import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/util/search_focus_tracker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class FolderBrowserDialog extends StatefulWidget {
  final String title;
  final String? initialDirectory;

  const FolderBrowserDialog({
    super.key,
    required this.title,
    this.initialDirectory,
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? initialDirectory,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) =>
          FolderBrowserDialog(title: title, initialDirectory: initialDirectory),
    );
  }

  @override
  State<FolderBrowserDialog> createState() => _FolderBrowserDialogState();
}

class _FolderBrowserDialogState extends State<FolderBrowserDialog> {
  final _pathController = TextEditingController();
  final _pathFocus = FocusNode();
  late Directory _current;
  List<Directory> _children = const [];
  String? _error;
  bool _loading = true;
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    SearchFocusTracker.instance.register(_pathFocus);
    _current = _resolveStart(widget.initialDirectory);
    _pathController.text = _current.path;
    _load(_current);
  }

  @override
  void dispose() {
    SearchFocusTracker.instance.unregister(_pathFocus);
    _pathFocus.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Directory _resolveStart(String? initial) {
    if (initial != null && initial.isNotEmpty) {
      final dir = Directory(initial);
      if (dir.existsSync()) return dir;
    }
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null) {
      final dir = Directory(home);
      if (dir.existsSync()) return dir;
    }
    return Directory.current;
  }

  bool get _isRoot {
    final parent = p.dirname(_current.path);
    return parent == _current.path;
  }

  Future<void> _load(Directory dir) async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final entries = <Directory>[];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue;
        entries.add(entity);
      }
      entries.sort(
        (a, b) => p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase()),
      );
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _current = dir;
        _children = entries;
        _loading = false;
        _pathController.text = dir.path;
      });
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _current = dir;
        _children = const [];
        _loading = false;
        _error = 'Cannot open this folder';
        _pathController.text = dir.path;
      });
    }
  }

  void _goToPath(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && (trimmed == '~' || trimmed.startsWith('~/'))) {
      trimmed = trimmed == '~' ? home : p.join(home, trimmed.substring(2));
    }
    final dir = Directory(trimmed);
    if (!dir.existsSync()) {
      setState(() => _error = 'Folder does not exist');
      return;
    }
    _load(dir);
  }

  void _goHome() {
    _load(_resolveStart(null));
  }

  void _goUp() {
    if (_isRoot) return;
    _load(Directory(p.dirname(_current.path)));
  }

  @override
  Widget build(BuildContext context) {
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    Color a(double v) => onSurface.withValues(alpha: v);

    final body = SizedBox(
      width: 480,
      height: 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IconBtn(
                icon: Icons.arrow_upward_rounded,
                tooltip: 'Parent folder',
                enabled: !_isRoot,
                onTap: _goUp,
              ),
              const SizedBox(width: 4),
              _IconBtn(
                icon: Icons.home_rounded,
                tooltip: 'Home',
                onTap: _goHome,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _pathController,
                  focusNode: _pathFocus,
                  style: TextStyle(color: onSurface, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Folder path',
                    hintStyle: TextStyle(color: a(0.24)),
                    filled: true,
                    fillColor: isM3
                        ? cs.onSurface.withValues(alpha: 0.04)
                        : aq.indicator,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: a(0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: a(0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: a(0.22)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: _goToPath,
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: a(0.45), fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isM3
                    ? cs.onSurface.withValues(alpha: 0.03)
                    : aq.indicator,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: a(0.08)),
              ),
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 1.6),
                      ),
                    )
                  : _children.isEmpty
                  ? Center(
                      child: Text(
                        'No subfolders',
                        style: TextStyle(color: a(0.32), fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _children.length,
                      itemBuilder: (ctx, i) {
                        final dir = _children[i];
                        return InkWell(
                          onTap: () => _load(dir),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.folder_rounded,
                                  size: 16,
                                  color: a(0.32),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    p.basename(dir.path),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: a(0.78),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );

    final actions = [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel', style: TextStyle(color: a(0.32), fontSize: 13)),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _current.path),
        child: Text(
          'Use this folder',
          style: TextStyle(
            color: a(0.68),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ];

    if (isM3) {
      return AlertDialog(
        title: Text(
          widget.title,
          style: TextStyle(
            color: onSurface,
            fontWeight: FontWeight.w400,
            fontSize: 15,
          ),
        ),
        content: body,
        actions: actions,
      );
    }

    return Dialog(
      backgroundColor: aq.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                color: aq.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 14),
            body,
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    final color = onSurface.withValues(alpha: enabled ? 0.50 : 0.18);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
