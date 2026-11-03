import 'package:flutter/material.dart';
import 'package:sonar/config/design_tokens.dart';

/// A read-only capsule that shows the state of a setting without spelling out
/// "on"/"off": filled accent when enabled, outlined hairline when disabled.
///
/// The settings index and the search results use it instead of text values so
/// that the state reads as a pill, while the detail pages keep the real
/// [Switch] (also a capsule).
class LsStateTag extends StatelessWidget {
  final String label;
  final bool on;

  const LsStateTag({required this.label, required this.on, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 8, 4),
      decoration: BoxDecoration(
        color: on ? colors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: on ? Colors.transparent : colors.lineStrong,
          width: tokens.hairlineOf(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? colors.accentInk : colors.faint,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.mono.copyWith(
              fontSize: 9.5,
              height: 1.1,
              color: on ? colors.accentInk : colors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// The capsule switch of the design language, made non-interactive. Used where
/// a row is a link rather than a control (e.g. a search result): the value is
/// still shown as a switch instead of the words "on"/"off".
class LsSwitchIndicator extends StatelessWidget {
  final bool on;

  const LsSwitchIndicator({required this.on, super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.ls.colors;
    return Container(
      width: 40,
      height: 24,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: on ? colors.accent : colors.muted.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Align(
        alignment: on ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? colors.accentFg : colors.fg,
          ),
        ),
      ),
    );
  }
}
