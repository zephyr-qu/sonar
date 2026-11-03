import 'package:flutter/material.dart';
import 'package:sonar/config/design_tokens.dart';

/// Segmented control of the redesign (30px items inside a `bg2` track).
///
/// The selected item is filled with the theme accent so the bar follows the
/// accent color (brand, dynamic or custom).
class LsSegmented extends StatelessWidget {
  /// Labels of the items. They are rendered as text; when [icons] is given each
  /// label is also used as the tooltip / semantics label of its icon.
  final List<String> options;

  /// Optional icons rendered instead of the [options] text.
  final List<IconData>? icons;
  final int index;
  final ValueChanged<int> onChanged;

  const LsSegmented({
    required this.options,
    required this.index,
    required this.onChanged,
    this.icons,
  }) : assert(icons == null || icons.length == options.length, 'Every option needs an icon');

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colors.bg2,
        borderRadius: tokens.tileRadius,
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: Tooltip(
                message: options[i],
                child: Semantics(
                  button: true,
                  selected: i == index,
                  label: options[i],
                  child: Material(
                    color: i == index ? colors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(tokens.radiusSm - 2),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(tokens.radiusSm - 2),
                      onTap: () => onChanged(i),
                      child: SizedBox(
                        height: 30,
                        child: Center(
                          child: icons == null
                              ? Text(
                                  options[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tokens.label.copyWith(
                                    color: i == index ? colors.accentFg : colors.muted,
                                    fontWeight: i == index ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                )
                              : Icon(
                                  icons![i],
                                  size: 15,
                                  color: i == index ? colors.accentFg : colors.muted,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
