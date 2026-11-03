import 'package:flutter/material.dart';
import 'package:sonar/config/design_tokens.dart';

/// Section label: uppercase eyebrow, optional count, then a hairline that fills the row.
class LsSectionLabel extends StatelessWidget {
  final String label;
  final String? count;
  final EdgeInsetsGeometry padding;

  const LsSectionLabel({
    required this.label,
    this.count,
    this.padding = const EdgeInsets.only(top: 18, bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label.toUpperCase(), style: tokens.eyebrow.copyWith(color: colors.muted)),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(count!, style: tokens.eyebrow),
          ],
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Container(height: 1, color: colors.line),
            ),
          ),
        ],
      ),
    );
  }
}
