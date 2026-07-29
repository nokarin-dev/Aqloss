import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:flutter/material.dart';
import 'package:aqloss/models/playlist.dart';
import 'package:aqloss/widgets/playlist/playlist_art_icon.dart';

class PlaylistNavItem extends StatefulWidget {
  final Playlist playlist;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final VoidCallback? onPlay;

  const PlaylistNavItem({
    super.key,
    required this.playlist,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
    this.onPlay,
  });

  @override
  State<PlaylistNavItem> createState() => _PlaylistNavItemState();
}

class _PlaylistNavItemState extends State<PlaylistNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    final card = isM3 ? cs.surfaceContainerHigh : aq.card;
    final border = isM3 ? cs.outlineVariant.withValues(alpha: 0.35) : aq.border;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          decoration: BoxDecoration(
            color: widget.isActive
                ? onSurface.withValues(alpha: 0.07)
                : _hovered
                ? onSurface.withValues(alpha: 0.03)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            children: [
              PlaylistArtIcon(playlist: widget.playlist, size: 30, radius: 6),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.playlist.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isActive
                            ? onSurface
                            : onSurface.withValues(alpha: 0.58),
                        fontWeight: widget.isActive
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${widget.playlist.length} tracks',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: onSurface.withValues(alpha: 0.20),
                      ),
                    ),
                  ],
                ),
              ),
              if (_hovered || widget.isActive)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    size: 14,
                    color: onSurface.withValues(alpha: 0.30),
                  ),
                  color: card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: border),
                  ),
                  elevation: 8,
                  itemBuilder: (_) => _menuItems(context),
                  onSelected: _onMenu,
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _menuItems(
    BuildContext context) {
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    return [
      if (widget.onPlay != null)
        PopupMenuItem(
          value: 'play',
          height: 36,
          child: Text(
            'Play',
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.68),
              fontSize: 12.5,
            ),
          ),
        ),
      PopupMenuItem(
        value: 'rename',
        height: 36,
        child: Text(
          'Rename',
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.68),
            fontSize: 12.5,
          ),
        ),
      ),
      const PopupMenuItem(
        value: 'delete',
        height: 36,
        child: Text(
          'Delete',
          style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 12.5),
        ),
      ),
    ];
  }

  void _onMenu(String v) {
    if (v == 'play') widget.onPlay?.call();
    if (v == 'rename') widget.onRename();
    if (v == 'delete') widget.onDelete();
  }
}
