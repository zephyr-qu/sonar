import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/pages/tabs/nearby/nearby_ui.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_hover.dart';
import 'package:sonar/widget/ls/ls_search_field.dart';
import 'package:sonar/widget/ls/ls_segmented.dart';

/// The desktop tab's control row: search, the device filters and a rescan button.
///
/// The stacked layouts fold these into the mini radar bar (`nearby_grid_view.dart`)
/// and the chip row (`nearby_radar_view.dart`); the desktop shell renders neither, so
/// the query and [NearbyUi.filter] stayed at their initial values and all the
/// filtering in `nearby_tab.dart` was unreachable on this layout.
class NearbyDesktopToolbar extends StatelessWidget {
  final bool scanning;
  final VoidCallback onScan;
  final NearbyUi ui;
  final NearbyActions actions;

  /// [LsSegmented] lays its items out with `Expanded`, so it cannot size itself inside
  /// a `Row`: three 64px items plus the track's 2px padding on each side.
  static const double _segmentedWidth = 204;

  const NearbyDesktopToolbar({
    required this.scanning,
    required this.onScan,
    required this.ui,
    required this.actions,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final query = actions.query;
    return Row(
      children: [
        Expanded(
          child: LsSearchField(
            controller: query,
            focusNode: actions.searchFocus,
            hint: t.nearbyTab.search,
            onChanged: (_) => actions.onQueryChanged(),
            trailing: query.text.isEmpty
                ? null
                : _ClearQueryButton(
                    onPressed: () {
                      query.clear();
                      actions.onQueryChanged();
                    },
                  ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: _segmentedWidth,
          height: 36,
          // The enum order is the filter order: all, online, favorites.
          child: LsSegmented(
            options: [
              t.nearbyTab.filterAll,
              t.nearbyTab.filterOnline,
              t.nearbyTab.filterFavorites,
            ],
            index: ui.filter.index,
            onChanged: (index) => actions.onFilterChanged(NearbyFilter.values[index]),
          ),
        ),
        const SizedBox(width: 8),
        _ScanButton(scanning: scanning, onScan: onScan),
      ],
    );
  }
}

/// Empties the search field. [LsSearchField] has no clear affordance of its own, and
/// on desktop the query is the only way to hide every device from the grid.
class _ClearQueryButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ClearQueryButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.ls.colors;
    return Tooltip(
      message: t.nearbyTab.clear,
      waitDuration: const Duration(milliseconds: 500),
      child: LsHover(
        color: Colors.transparent,
        hoverColor: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        builder: (context, hovered) => SizedBox(
          width: 22,
          height: 22,
          child: Center(
            child: Icon(
              LucideIcons.x,
              size: 13,
              color: hovered ? colors.fg : colors.faint,
            ),
          ),
        ),
      ),
    );
  }
}

/// Rescans the network; a scan runs for seconds, so the button turns into a spinner
/// instead of staying tappable and looking dead.
class _ScanButton extends StatelessWidget {
  final bool scanning;
  final VoidCallback onScan;

  const _ScanButton({required this.scanning, required this.onScan});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    if (!scanning) {
      return LsIconButton(
        icon: LucideIcons.refreshCw,
        tooltip: t.nearbyTab.scan,
        onPressed: onScan,
      );
    }

    // Same 38px box as [LsIconButton], so the row does not shift when a scan starts.
    return Semantics(
      label: t.nearbyTab.scan,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: tokens.colors.accent,
            ),
          ),
        ),
      ),
    );
  }
}
