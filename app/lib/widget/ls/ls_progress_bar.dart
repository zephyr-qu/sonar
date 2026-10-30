import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';

/// 4px accent progress bar of the redesign.
class LsProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Color? color;

  const LsProgressBar({
    required this.value,
    this.height = 4,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: colors.line,
        color: color ?? colors.accent,
      ),
    );
  }
}
