import 'package:flutter/material.dart';
import 'package:sonar/config/design_tokens.dart';

/// The card surface of the redesign: `bg2`, 1px hairline, radius 16, no shadow.
class LsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final BorderRadius? borderRadius;

  const LsCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.color,
    this.borderColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final radius = borderRadius ?? tokens.cardRadius;

    return Material(
      color: color ?? colors.bg2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor ?? colors.line, width: tokens.hairlineOf(context)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        hoverColor: colors.bg3,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
