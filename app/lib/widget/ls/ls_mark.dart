import 'package:flutter/material.dart';
import 'package:sonar/config/design_tokens.dart';

/// The 30×30 rounded square that carries a mark: a screen glyph, a section icon
/// or the kind of a file.
///
/// Two flavours exist in the design: the accent one used by the screen headers
/// and the rail, which is filled with the accent colour, and the quiet `bg3`
/// one that carries a 14–16px icon or a kind.
class LsMark extends StatelessWidget {
  final Widget? child;
  final IconData? icon;
  final bool accent;

  /// Icon size, and the size the [IconTheme] passes down to [child].
  final double iconSize;

  final Color? iconColor;

  const LsMark({required this.child, this.accent = false, this.iconSize = 16, this.iconColor, super.key}) : icon = null;

  const LsMark.icon(this.icon, {this.accent = false, this.iconSize = 16, this.iconColor, super.key}) : child = null;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final color = iconColor ?? (accent ? colors.accentFg : colors.fg);

    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: accent ? colors.accent : colors.bg3, borderRadius: BorderRadius.circular(tokens.radiusSm)),
      child: icon != null
          ? Icon(icon, size: iconSize, color: color)
          : IconTheme(
              data: IconThemeData(size: iconSize, color: color),
              child: child!,
            ),
    );
  }
}
