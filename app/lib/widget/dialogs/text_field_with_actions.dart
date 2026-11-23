import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';
import 'package:sonar/widget/ls/ls_hover.dart';

/// Opens a dialog that edits [controller]'s text, with [actions] as shortcuts
/// under the field.
///
/// The trigger is the bare text, not a filled input look: it sits as the value of a
/// settings row (e.g. the device name), where a trailing value is expected to be plain.
class TextFieldWithActions extends StatefulWidget {
  final String name;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  /// Called once when the dialog is confirmed, with the final text. Use this
  /// instead of [onChanged] for expensive writes (e.g. persisting a setting) so
  /// typing does not commit every keystroke.
  ///
  /// Dismissing the dialog — the barrier, the back gesture — is a cancel and
  /// never passes anything here. A text that [validator] rejects is not passed
  /// either, so an emptied field cannot persist a blank value.
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
  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;

    return LsHover(
      borderRadius: tokens.tileRadius,
      color: Colors.transparent,
      hoverColor: colors.bg3,
      onTap: _openDialog,
      builder: (context, hovered) {
        final tint = hovered ? colors.accent : colors.fg;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.controller.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.body.copyWith(color: tint),
                ),
              ),
              const SizedBox(width: 5),
              Icon(LucideIcons.pencil, size: 11, color: hovered ? colors.accent : colors.faint),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openDialog() async {
    // The row renders the text of the controller, so a name the user typed
    // and then walked away from must not linger there: remember what the
    // row said and put it back when the dialog was dismissed, not confirmed.
    final previous = widget.controller.text;
    final confirmed = await showTextFieldDialog(
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
    if (!confirmed) {
      widget.controller.text = previous;
      return;
    }
    if (widget.validator?.call(widget.controller.text) != null) {
      return;
    }
    widget.onClosed?.call(widget.controller.text);
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
/// Returns whether the user confirmed. `false` is a dismissal — the barrier, the
/// back gesture or Escape — which means cancel: [controller] still holds whatever
/// was typed, so a caller must not commit it. [onClosed] is not handled here; the
/// caller reads the final text of [controller] when this future completes with
/// `true`.
///
/// [disposeController] hands ownership of [controller] to the dialog, for
/// controllers that exist only for this edit. The dialog disposes it when it
/// leaves the tree: disposing it as soon as the future completes is too early,
/// because the closing route keeps rebuilding the field while it fades out and
/// would then use a disposed controller.
Future<bool> showTextFieldDialog(
  BuildContext context, {
  required String name,
  required TextEditingController controller,
  ValueChanged<String>? onChanged,
  List<Widget> actions = const [],
  String? Function(String value)? validator,
  bool disposeController = false,
}) async {
  final confirmed = await showDialog<bool>(
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
  return confirmed ?? false;
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
    // The result is what tells the caller this is a confirm and not a dismissal.
    context.pop(true);
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
