import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/dialogs/custom_bottom_sheet.dart';
import 'package:localsend_app/widget/ls/ls_buttons.dart';
import 'package:localsend_app/widget/ls/ls_dialog.dart';
import 'package:routerino/routerino.dart';

class QuickSaveFromFavoritesNotice extends StatelessWidget {
  const QuickSaveFromFavoritesNotice({super.key});

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
      await context.pushBottomSheet(() => const QuickSaveFromFavoritesNotice());
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomBottomSheet(
      title: t.dialogs.quickSaveFromFavoritesNotice.title,
      description: t.dialogs.quickSaveFromFavoritesNotice.content.join('\n'),
      child: Center(
        child: LsButton(
          label: t.general.close,
          onPressed: () => context.popUntilRoot(),
        ),
      ),
    );
  }
}
