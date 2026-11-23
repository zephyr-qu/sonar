import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/provider/selection/selected_receiving_files_provider.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';
import 'package:sonar/widget/ls/ls_segmented.dart';
import 'package:sonar/widget/ls/ls_switch.dart';
import 'package:sonar_isolates/rust/api/filename.dart';
import 'package:uuid/uuid.dart';

enum _QuickAction {
  counter,
  random
  ;

  String get label {
    switch (this) {
      case _QuickAction.counter:
        return t.dialogs.quickActions.counter;
      case _QuickAction.random:
        return t.dialogs.quickActions.random;
    }
  }
}

class QuickActionsDialog extends StatefulWidget {
  const QuickActionsDialog({super.key});

  @override
  State<QuickActionsDialog> createState() => _QuickActionsDialogState();
}

class _QuickActionsDialogState extends State<QuickActionsDialog> with Refena {
  _QuickAction _action = _QuickAction.counter;

  // counter
  String _prefix = '';
  bool _padZero = false;
  bool _sortBeforehand = false;

  // random
  final _randomUuid = const Uuid().v4();

  // sanity check
  bool _isValid = true;

  bool _validate(String input) {
    if (!isValidFileName(name: input) && input.isNotEmpty) {
      setState(() {
        _isValid = false;
      });
      return false;
    }

    if (!_isValid) {
      setState(() {
        _isValid = true;
      });
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;

    return LsDialog(
      title: Text(t.dialogs.quickActions.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LsSegmented(
            options: _QuickAction.values.map((mode) => mode.label).toList(),
            index: _action.index,
            onChanged: (index) => setState(() => _action = _QuickAction.values[index]),
          ),
          const SizedBox(height: 14),
          if (_action == _QuickAction.counter) ...[
            Text(t.dialogs.quickActions.prefix, style: tokens.bodySm),
            const SizedBox(height: 6),
            TextFormField(
              autofocus: true,
              onChanged: (s) {
                _validate(s);
                setState(() {
                  _prefix = s;
                });
              },
            ),
            if (!_isValid)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(t.sanitization.invalid, style: tokens.bodySm.copyWith(color: colors.danger)),
              ),
            const SizedBox(height: 12),
            _SwitchRow(
              label: t.dialogs.quickActions.padZero,
              value: _padZero,
              onChanged: (value) {
                setState(() {
                  _padZero = value;
                });
              },
            ),
            _SwitchRow(
              label: t.dialogs.quickActions.sortBeforeCount,
              value: _sortBeforehand,
              onChanged: (value) {
                setState(() {
                  _sortBeforehand = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Text(
              '${t.general.example}: ${_padZero ? '${_prefix}04.jpg' : '${_prefix}4.jpg'}',
              style: tokens.bodySm,
            ),
          ],
          if (_action == _QuickAction.random) Text('${t.general.example}: $_randomUuid.jpg', style: tokens.bodySm),
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
          onPressed: () {
            switch (_action) {
              case _QuickAction.counter:
                if (!_isValid) {
                  return;
                }
                ref
                    .notifier(selectedReceivingFilesProvider)
                    .applyCounter(
                      prefix: _prefix,
                      padZero: _padZero,
                      sortFirst: _sortBeforehand,
                    );
                break;
              case _QuickAction.random:
                ref.notifier(selectedReceivingFilesProvider).applyRandom();
                break;
            }
            context.pop();
          },
        ),
      ],
    );
  }
}

/// A labeled setting of the dialog: the text takes the row, the switch sits end-aligned.
class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;

    return Row(
      children: [
        Expanded(
          child: Text(label, style: tokens.body.copyWith(color: tokens.colors.fg)),
        ),
        const SizedBox(width: 12),
        LsSwitch(value: value, label: label, onChanged: onChanged),
      ],
    );
  }
}
