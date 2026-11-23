import 'package:flutter/material.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/widget/ls/ls_hover.dart';
import 'package:sonar/widget/responsive_builder.dart';

/// One of the big destination buttons of the empty friend list.
///
/// A fixed-size tile rather than a text row: the label is a single sentence in
/// some locales, so it is fitted into the tile instead of wrapping.
class BigButton extends StatelessWidget {
  static const double desktopWidth = 100.0;
  static const double mobileWidth = 90.0;

  final IconData icon;
  final String label;
  final bool filled;
  final double? width;
  final VoidCallback onTap;

  const BigButton({
    required this.icon,
    required this.label,
    required this.filled,
    this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final sizingInformation = SizingInformation(MediaQuery.sizeOf(context).width);
    final buttonWidth = width ?? (sizingInformation.isDesktop ? desktopWidth : mobileWidth);
    final tint = filled ? colors.accent : colors.fg;

    return SizedBox(
      width: buttonWidth,
      height: 65.0,
      child: LsHover(
        color: filled ? colors.accentSoft : colors.bg3,
        hoverColor: filled ? colors.accentSoft : colors.lineStrong,
        borderColor: filled ? colors.accent : colors.line,
        borderRadius: tokens.tileRadius,
        onTap: onTap,
        builder: (context, hovered) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 18, color: tint),
                FittedBox(
                  alignment: Alignment.bottomCenter,
                  child: Text(label, maxLines: 1, style: tokens.label.copyWith(color: tint)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
