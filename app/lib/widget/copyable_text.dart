import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/util/ui/snackbar.dart';
import 'package:sonar/widget/ls/ls_hover.dart';

/// One copyable line: the value, plus a copy glyph that appears with it.
///
/// Tapping the line copies [value]; a line without one (an unset debug value, a
/// log entry whose text is empty) is not tappable and reads as a dash.
class CopyableText extends StatelessWidget {
  final TextSpan? prefix;
  final String name;
  final String? value;

  const CopyableText({
    this.prefix,
    required this.name,
    required this.value,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final copy = value;

    return LsHover(
      color: Colors.transparent,
      hoverColor: colors.bg3,
      borderRadius: tokens.tileRadius,
      onTap: copy == null
          ? null
          : () async {
              await Clipboard.setData(ClipboardData(text: copy));
              if (context.mounted) {
                context.showSnackBar('Copied $name to clipboard!');
              }
            },
      builder: (context, hovered) {
        final color = hovered ? colors.accent : colors.fg;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      ?prefix,
                      TextSpan(text: copy ?? '-'),
                    ],
                  ),
                  style: tokens.mono.copyWith(color: color),
                ),
              ),
              if (copy != null) ...[
                const SizedBox(width: 8),
                // Pinned to the first line: a wrapped PEM block is taller than
                // the glyph and a centered one would sit in its middle.
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(LucideIcons.copy, size: 11, color: hovered ? colors.accent : colors.faint),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
