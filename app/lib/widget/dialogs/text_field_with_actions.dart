import 'package:flutter/material.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';

/// Opens a dialog that edits [controller]'s text, with [actions] as shortcuts
/// under the field.
///
/// The trigger is the bare text, not a filled input look: it sits as the value of a
/// settings row (e.g. the device name), where a trailing value is expected to be plain.
class TextFieldWithActions extends StatefulWidget {
  final String name;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  /// Called once when the dialog closes, with the final text. Use this instead of [onChanged]
  /// for expensive writes (e.g. persisting a setting) so typing does not commit every keystroke.
  ///
  /// A text that [validator] rejects is never passed here, so a dialog the user
  /// cancelled with an emptied field cannot persist a blank value.
  final ValueChanged<String>? onClosed;

  /// Rejects a text with an error message; `null` means the text may be committed.
  final String? Function(String value)? validator;
  final List<Widget> actions;

  const TextFieldWithActions({
    required this.name,
    required this.controller,
    this.onChanged,
    this.onClosed,
    this.validator,
    required this.actions,
  });

  @override
  State<TextFieldWithActions> createState() => _TextFieldWithActionsState();
}

class _TextFieldWithActionsState extends State<TextFieldWithActions> {
  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      onPressed: () async {
        await showTextFieldDialog(
          context,
          name: widget.name,
          controller: widget.controller,
          onChanged: widget.onChanged,
          actions: widget.actions,
          validator: widget.validator,
        );
        if (!mounted) {
          return;
        }
        if (widget.validator?.call(widget.controller.text) != null) {
          return;
        }
        widget.onClosed?.call(widget.controller.text);
      },
      child: Text(
        widget.controller.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

/// Opens the dialog of [TextFieldWithActions].
///
/// Extracted so that other entries can edit the same value without looking like
/// a settings row — e.g. clicking the device name in a header opens the very
/// dialog the settings page uses.
///
/// [validator] returns the error message of an unacceptable [controller] text, or
/// `null` when the text may be committed: the confirm button stays disabled and
/// the error is shown under the field while a message is returned.
///
/// [onClosed] is not handled here: the caller reads the final text of
/// [controller] after the future completes, which happens however the dialog is
/// dismissed.
///
/// [disposeController] hands ownership of [controller] to the dialog, for
/// controllers that exist only for this edit. The dialog disposes it when it
/// leaves the tree: disposing it as soon as the future completes is too early,
/// because the closing route keeps rebuilding the field while it fades out and
/// would then use a disposed controller.
Future<void> showTextFieldDialog(
  BuildContext context, {
  required String name,
  required TextEditingController controller,
  ValueChanged<String>? onChanged,
  List<Widget> actions = const [],
  String? Function(String value)? validator,
  bool disposeController = false,
}) async {
  await showDialog(
    context: context,
    builder: (context) {
      return _TextFieldDialog(
        name: name,
        controller: controller,
        onChanged: onChanged,
        actions: actions,
        validator: validator,
        disposeController: disposeController,
      );
    },
  );
}

class _TextFieldDialog extends StatefulWidget {
  final String name;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final List<Widget> actions;
  final String? Function(String value)? validator;

  /// Whether the controller belongs to the dialog and dies with it.
  final bool disposeController;

  const _TextFieldDialog({
    required this.name,
    required this.controller,
    required this.actions,
    this.onChanged,
    this.validator,
    this.disposeController = false,
  });

  @override
  State<_TextFieldDialog> createState() => _TextFieldDialogState();
}

class _TextFieldDialogState extends State<_TextFieldDialog> {
  String? get _error => widget.validator?.call(widget.controller.text);

  @override
  void initState() {
    super.initState();
    // Validity follows the text itself, not the field's own callbacks: the shortcuts
    // below the field fill it through the controller, which no field notices.
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    // After the listener, so a controller owned by the dialog dies with the
    // widget instead of with the future that opened it.
    if (widget.disposeController) {
      widget.controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  void _submit() {
    if (_error != null) {
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;

    return LsDialog(
      title: Text(widget.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: widget.controller,
            textAlign: TextAlign.center,
            decoration: InputDecoration(errorText: error),
            onChanged: widget.onChanged,
            autofocus: true,
            onFieldSubmitted: (_) => _submit(),
          ),
          // The shortcuts sit under the field, on the same row as the confirm
          // button: the field is what the dialog is about, and a row of icons
          // above it pushed the field out of the visual center.
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                ...widget.actions,
                const Spacer(),
                LsButton(
                  label: t.general.confirm,
                  onPressed: error == null ? _submit : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
