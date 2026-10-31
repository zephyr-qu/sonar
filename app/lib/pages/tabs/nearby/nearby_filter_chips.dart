import 'package:flutter/widgets.dart';
import 'package:localsend_app/pages/tabs/nearby/nearby_ui.dart';
import 'package:localsend_app/widget/ls/ls_chip.dart';

/// One of the three device-filter chips. Shared so the grid and radar layouts render them identically.
class NearbyFilterChip extends StatelessWidget {
  final String label;
  final NearbyFilter value;
  final NearbyUi ui;
  final NearbyActions actions;

  const NearbyFilterChip({
    required this.label,
    required this.value,
    required this.ui,
    required this.actions,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LsChip.text(
      label,
      accent: ui.filter == value,
      onTap: () => actions.onFilterChanged(value),
    );
  }
}
