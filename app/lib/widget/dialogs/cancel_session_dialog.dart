import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/util/native/platform_check.dart';
import 'package:sonar/widget/dialogs/custom_bottom_sheet.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';

/// Asks whether an in-progress session should really be cancelled.
///
/// Returns `true` only when the user confirmed the cancellation, so dismissing
/// the dialog by tapping outside or pressing escape counts as "keep going".
class CancelSessionDialog extends StatelessWidget {
  const CancelSessionDialog();

  static Future<bool> open(BuildContext context) async {
    if (checkPlatformIsDesktop()) {
      final result = await showDialog<bool>(
        context: context,
        builder: (_) => LsDialog(
          title: Text(t.dialogs.cancelSession.title),
          content: Text(t.dialogs.cancelSession.content),
          actions: [
            LsButton(
              label: t.general.continueStr,
              variant: LsButtonVariant.ghost,
              onPressed: () => context.pop(false),
            ),
            LsButton(
              label: t.general.cancel,
              icon: LucideIcons.x,
              onPressed: () => context.pop(true),
            ),
          ],
        ),
      );
      return result == true;
    }

    return (await context.pushBottomSheet(() => const CancelSessionDialog())) == true;
  }

  @override
  Widget build(BuildContext context) {
    return CustomBottomSheet(
      title: t.dialogs.cancelSession.title,
      description: t.dialogs.cancelSession.content,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          LsButton(
            label: t.general.continueStr,
            variant: LsButtonVariant.ghost,
            onPressed: () => context.pop(false),
          ),
          LsButton(
            label: t.general.cancel,
            icon: LucideIcons.x,
            onPressed: () => context.pop(true),
          ),
        ],
      ),
    );
  }
}
