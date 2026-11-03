import 'package:flutter/material.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';

class ErrorDialog extends StatelessWidget {
  final String error;

  const ErrorDialog({required this.error, super.key});

  @override
  Widget build(BuildContext context) {
    return LsDialog(
      title: Text(t.dialogs.errorDialog.title),
      content: SelectableText(error),
      actions: [
        LsButton(
          label: t.general.close,
          onPressed: () => context.pop(),
        ),
      ],
    );
  }
}
