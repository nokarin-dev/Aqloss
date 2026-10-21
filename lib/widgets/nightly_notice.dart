import 'package:aqloss/app_channel.dart';
import 'package:aqloss/l10n/l10n.dart';
import 'package:aqloss/util/notices.dart';
import 'package:aqloss/widgets/ui/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> maybeShowNightlyNotice(
  BuildContext context, {
  bool isNightly = kIsNightly,
}) async {
  if (!isNightly) return;
  final prefs = await SharedPreferences.getInstance();
  if (!shouldShowNightlyNotice(
    isNightly: isNightly,
    acked: prefs.getBool(kNightlyAckPref) == true,
  )) {
    return;
  }
  if (!context.mounted) return;
  await showUiDialog<void>(
    context: context,
    title: tr(kNightlyBuildTitle),
    content: Text(tr(kNightlyBuildMessage)),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(tr('OK')),
      ),
    ],
  );
  await prefs.setBool(kNightlyAckPref, true);
}
