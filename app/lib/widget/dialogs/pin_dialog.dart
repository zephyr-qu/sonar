import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/widget/ls/ls_buttons.dart';
import 'package:localsend_app/widget/ls/ls_dialog.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:routerino/routerino.dart';

class PinDialog extends StatefulWidget {
  final String? pin;
  final bool showInvalidPin;
  final bool obscureText;
  final bool generateRandom;

  const PinDialog({
    this.pin,
    required this.obscureText,
    this.showInvalidPin = false,
    this.generateRandom = false,
    super.key,
  });

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _textController.text = widget.pin ?? (widget.generateRandom ? nanoid(alphabet: Alphabet.noDoppelganger, length: 6) : '');
  }

  @override
  Widget build(BuildContext context) {
    return LsDialog(
      title: Text(t.dialogs.pin.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _textController,
            autofocus: true,
            obscureText: widget.obscureText,
            onFieldSubmitted: (value) => context.pop(value),
          ),
          if (widget.showInvalidPin)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                t.web.invalidPin,
                style: TextStyle(color: Theme.of(context).colorScheme.warning),
              ),
            ),
        ],
      ),
      actions: [
        LsButton(
          label: t.general.cancel,
          variant: LsButtonVariant.ghost,
          onPressed: () => context.pop(),
        ),
        LsButton(
          label: t.general.confirm,
          onPressed: () => context.pop(_textController.text),
        ),
      ],
    );
  }
}
