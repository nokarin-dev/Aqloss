import 'dart:io';
import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/widgets/ui/ui_kit.dart';
import 'package:aqloss/services/folder_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqloss/providers/library_provider.dart';
import 'package:aqloss/util/android_path_helper.dart';

class FolderManagerDialog extends ConsumerWidget {
  const FolderManagerDialog({super.key});

  Future<void> _addFolder(BuildContext context, WidgetRef ref) async {
    final library = ref.read(libraryProvider.notifier);
    if (Platform.isAndroid) {
      final granted = await requestAndroidStoragePermission();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Storage permission is required to scan music folders',
              ),
            ),
          );
        }
        return;
      }
    }
    if (!context.mounted) return;
    final result = await pickDirectory(
      context,
      dialogTitle: 'Select music folder',
    );
    if (result == null) return;
    library.addFolder(resolveAndroidPath(result));
  }

  String _shortPath(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    if (parts.length <= 3) return path;
    return '…/${parts.sublist(parts.length - 2).join('/')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final folders = library.folders;
    final isScanning = library.status == LibraryStatus.scanning;
    final isM3 = context.isMaterial3Ui;
    final cs = Theme.of(context).colorScheme;
    final aq = context.aq;
    final onSurface = isM3 ? cs.onSurface : aq.onSurface;
    Color a(double v) => onSurface.withValues(alpha: v);

    final body = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460, minWidth: 300),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Music Folders',
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const Spacer(),
                if (isScanning)
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: a(0.30),
                    ),
                  ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: a(0.06),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: a(0.40),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (folders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No folders added yet.',
                  style: TextStyle(color: a(0.32), fontSize: 13),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: folders.length,
                  separatorBuilder: (_, _) => isM3
                      ? const UiDivider()
                      : Container(height: 1, color: aq.border),
                  itemBuilder: (ctx, i) {
                    final folder = folders[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: [
                          Icon(Icons.folder_rounded, size: 15, color: a(0.25)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _shortPath(folder),
                                  style: TextStyle(
                                    color: a(0.68),
                                    fontSize: 12.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  folder,
                                  style: TextStyle(
                                    color: a(0.20),
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => ref
                                .read(libraryProvider.notifier)
                                .removeFolder(folder),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: a(0.04),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.remove_rounded,
                                  size: 13,
                                  color: a(0.32),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 14),
            isM3 ? const UiDivider() : Container(height: 1, color: aq.border),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isScanning ? null : () => _addFolder(context, ref),
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text('Add folder', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: a(0.55),
                  side: BorderSide(color: a(0.12)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (isM3) {
      return AlertDialog(content: body);
    }

    return Dialog(
      backgroundColor: aq.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: body,
    );
  }
}
