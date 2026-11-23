import 'package:flutter/material.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/widget/copyable_text.dart';

/// A labeled, copyable value of the debug pages.
///
/// The label sits above the value instead of beside it: these values are paths,
/// PEM blocks and SDK strings — long, wrapping, and unreadable if squeezed into
/// a table column.
class DebugEntry extends StatelessWidget {
  final String name;
  final String? value;

  const DebugEntry({
    required this.name,
    required this.value,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: tokens.eyebrow.copyWith(color: colors.muted)),
          const SizedBox(height: 3),
          CopyableText(name: name, value: value),
        ],
      ),
    );
  }
}
