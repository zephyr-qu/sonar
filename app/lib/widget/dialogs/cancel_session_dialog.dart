import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/widget/dialogs/custom_bottom_sheet.dart';
import 'package:localsend_app/widget/ls/ls_buttons.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:routerino/routerino.dart';

class CancelSessionDialog extends StatelessWidget {
  const CancelSessionDialog();

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
