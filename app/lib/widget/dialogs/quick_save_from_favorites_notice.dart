import 'package:flutter/material.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/util/native/platform_check.dart';
import 'package:sonar/util/ui/snackbar.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';

class QuickSaveFromFavoritesNotice {
  const QuickSaveFromFavoritesNotice._();

  static Future<void> open(BuildContext context) async {
    if (checkPlatformIsDesktop()) {
      await showDialog(
        context: context,
        builder: (_) => LsDialog(
          title: Text(t.dialogs.quickSaveFromFavoritesNotice.title),
          content: Text(t.dialogs.quickSaveFromFavoritesNotice.content.join('\n')),
          actions: [
            LsButton(
              label: t.general.close,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      );
    } else {
      // Mobile: a light snackbar instead of a bottom sheet, so toggling quick save does not interrupt the user.
      context.showSnackBar(t.dialogs.quickSaveFromFavoritesNotice.content.join('\n'));
    }
  }
}
