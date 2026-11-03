import 'package:flutter/material.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/util/native/platform_check.dart';
import 'package:sonar/widget/dialogs/custom_bottom_sheet.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';

class CannotOpenFileDialog extends StatelessWidget {
  final String path;

  const CannotOpenFileDialog({required this.path, super.key});

  static Future<void> open(BuildContext context, String path, void Function()? onDeleteTap) async {
    if (checkPlatformIsDesktop()) {
      await showDialog(
        context: context,
        builder: (_) => LsDialog(
          title: Text(t.dialogs.cannotOpenFile.title),
          content: Text(t.dialogs.cannotOpenFile.content(file: path)),
          actions: [
            if (onDeleteTap != null)
              LsButton(
                label: t.receiveHistoryPage.entryActions.deleteFromHistory,
                variant: LsButtonVariant.ghost,
                onPressed: () {
                  onDeleteTap();
                  context.pop();
                },
              ),
            LsButton(
              label: t.general.close,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      );
    } else {
      await context.pushBottomSheet(() => CannotOpenFileDialog(path: path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomBottomSheet(
      title: t.dialogs.cannotOpenFile.title,
      description: t.dialogs.cannotOpenFile.content(file: path),
      child: Center(
        child: LsButton(
          label: t.general.close,
          onPressed: () => context.popUntilRoot(),
        ),
      ),
    );
  }
}
