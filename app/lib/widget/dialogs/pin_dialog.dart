import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';

class PinDialog extends StatefulWidget {
  /// Characters a PIN may contain: digits and ASCII letters.
  static final RegExp allowedCharacters = RegExp('[a-zA-Z0-9]');

  /// Maximum length of a PIN, both when setting one and when entering one.
  ///
  /// The PIN travels as a query parameter, so there is no protocol limit; this
  /// only keeps a PIN typable on the other device.
  static const int maxLength = 16;

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
  void dispose() {
    _textController.dispose();
    super.dispose();
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
            inputFormatters: [
              FilteringTextInputFormatter.allow(PinDialog.allowedCharacters),
              LengthLimitingTextInputFormatter(PinDialog.maxLength),
            ],
            obscureText: widget.obscureText,
            decoration: InputDecoration(helperText: t.dialogs.pin.hint(maxLength: PinDialog.maxLength)),
            onFieldSubmitted: (value) => context.pop(value),
          ),
          if (widget.showInvalidPin)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                t.web.invalidPin,
                style: TextStyle(color: context.ls.colors.danger),
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
