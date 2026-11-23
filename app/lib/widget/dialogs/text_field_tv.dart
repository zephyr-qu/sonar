import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/theme.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/provider/tv_provider.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';

/// A normal [TextFormField] on mobile and desktop.
/// A button which opens a dialog on Android TV
class TextFieldTv extends StatefulWidget {
  final String name;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onDelete;

  /// Called when the field loses focus, i.e. once the user is done typing. Used to write the
  /// normalised value back: the setter may clamp what was typed (a port above 65535), and the
  /// field must not keep showing the rejected text.
  final VoidCallback? onFocusLost;
  final TextAlign textAlign;

  const TextFieldTv({
    required this.name,
    required this.controller,
    this.onChanged,
    this.onDelete,
    this.onFocusLost,
    this.textAlign = TextAlign.center,
  });

  @override
  State<TextFieldTv> createState() => _TextFieldTvState();
}

class _TextFieldTvState extends State<TextFieldTv> with Refena {
  late final FocusNode _focusNode = FocusNode()..addListener(_onFocusChange);

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      widget.onFocusLost?.call();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTv = ref.watch(tvProvider);

    if (isTv) {
      return TextButton(
        style: TextButton.styleFrom(
          backgroundColor: Theme.of(context).inputDecorationTheme.fillColor,
          shape: RoundedRectangleBorder(borderRadius: Theme.of(context).inputDecorationTheme.borderRadius),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: () async {
          await showDialog(
            context: context,
            builder: (context) {
              return LsDialog(
                title: Text(widget.name),
                content: TextFormField(
                  controller: widget.controller,
                  textAlign: widget.textAlign,
                  onChanged: widget.onChanged,
                  autofocus: true,
                  onFieldSubmitted: (_) => context.pop(),
                ),
                actions: [
                  LsButton(
                    label: t.general.confirm,
                    onPressed: () => context.pop(),
                  ),
                ],
              );
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(widget.controller.text, style: Theme.of(context).textTheme.titleMedium),
        ),
      );
    } else {
      return TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        textAlign: widget.textAlign,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          suffixIcon: widget.onDelete != null
              ? IconButton(
                  icon: Icon(LucideIcons.x),
                  onPressed: () {
                    widget.onDelete?.call();
                  },
                )
              : null,
        ),
      );
    }
  }
}
