import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';

/// Dialog shell of the redesign: `bg2` surface, hairline border, radius 16,
/// optional mono eyebrow, 16px title and a trailing row of [LsButton]s.
///
/// Drop-in replacement for the stock `AlertDialog` so every dialog shares the
/// same spacing and typography; content is scrollable when it exceeds the
/// available height.
class LsDialog extends StatelessWidget {
  /// Small uppercase mono label above the title (e.g. "接收请求").
  final String? eyebrow;

  /// Dialog title, rendered with the 16/700 title style.
  final Widget? title;

  final Widget? content;

  /// Action buttons, aligned to the end. Prefer [LsButton].
  final List<Widget> actions;

  final double maxWidth;

  /// Extra width for dialogs holding lists or tables.
  final CrossAxisAlignment contentAlignment;

  const LsDialog({
    this.eyebrow,
    this.title,
    this.content,
    this.actions = const [],
    this.maxWidth = 420,
    this.contentAlignment = CrossAxisAlignment.start,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;

    return Dialog(
      backgroundColor: colors.bg2,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(
        borderRadius: tokens.cardRadius,
        side: BorderSide(color: colors.lineStrong, width: tokens.hairlineOf(context)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: contentAlignment,
            children: [
              if (eyebrow != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(eyebrow!.toUpperCase(), style: tokens.eyebrow),
                ),
              if (title != null) DefaultTextStyle.merge(style: tokens.title, child: title!),
              if (content != null)
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.only(top: title != null || eyebrow != null ? 14 : 0),
                    child: DefaultTextStyle.merge(
                      style: tokens.body.copyWith(color: colors.muted),
                      child: SingleChildScrollView(child: content!),
                    ),
                  ),
                ),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 8,
                    overflowSpacing: 8,
                    children: actions,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
