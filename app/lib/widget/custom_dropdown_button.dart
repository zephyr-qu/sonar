import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';

/// A [DropdownButton] with a custom theme.
/// Currently, there is no easy way to apply color and border radius to all [DropdownButton].
class CustomDropdownButton<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T>? onChanged;

  /// Shown instead of the selected value when [value] is `null`, i.e. when the
  /// current setting is represented by another control (e.g. the accent
  /// swatches) and therefore has no item in this dropdown.
  final Widget? hint;
  final bool expanded;

  const CustomDropdownButton({
    required this.value,
    required this.items,
    this.onChanged,
    this.hint,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).inputDecorationTheme.fillColor,
      shape: RoundedRectangleBorder(borderRadius: Theme.of(context).inputDecorationTheme.borderRadius),
      child: DropdownButton<T>(
        value: value,
        hint: hint,
        isExpanded: expanded,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        underline: Container(),
        borderRadius: Theme.of(context).inputDecorationTheme.borderRadius,
        items: items,
        onChanged: onChanged == null
            ? null
            : (value) {
                if (value != null) {
                  onChanged!(value);
                }
              },
      ),
    );
  }
}
