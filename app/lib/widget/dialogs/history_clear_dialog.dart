import 'package:flutter/material.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';

class HistoryClearDialog extends StatelessWidget {
  const HistoryClearDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return LsDialog(
      title: Text(t.dialogs.historyClearDialog.title),
      content: Text(t.dialogs.historyClearDialog.content),
      actions: [
        LsButton(
          label: t.general.cancel,
          variant: LsButtonVariant.ghost,
          onPressed: () => context.pop(),
        ),
        LsButton(
          label: t.general.delete,
          onPressed: () => context.pop(true),
        ),
      ],
    );
  }
}
