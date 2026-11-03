import 'package:flutter/material.dart';
import 'package:sonar/config/design_tokens.dart';

/// Small pill badge used for transport/meta information next to a device name.
///
/// The visual language follows the "Signal" redesign: 24px pill, compact label.
class DeviceBadge extends StatelessWidget {
  final Color backgroundColor;
  final Color foregroundColor;
  final String label;

  const DeviceBadge({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.ls.label.copyWith(color: foregroundColor),
      ),
    );
  }
}
