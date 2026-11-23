import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_chip.dart';
import 'package:sonar/widget/ls/ls_hover.dart';

/// One entry of an [LsMenuButton] menu.
class LsMenuItem<T> {
  final T value;
  final String label;

  /// Draws the accent check in the leading slot. Unchecked entries keep the
  /// slot empty so labels stay aligned in mixed (toggle) menus.
  final bool checked;

  const LsMenuItem({
    required this.value,
    required this.label,
    this.checked = false,
  });
}

/// Icon trigger that opens a menu in the design language: `bg2` surface,
/// hairline outline and the tile radius, instead of the Material popup surface.
///
/// Use it for the trailing header action of a page (filters, sort orders,
/// overflow actions). Menus with a current selection pass [LsMenuItem.checked].
/// [compact] swaps the 38px [LsIconButton] plate for a 28px glyph with no plate
/// of its own, for dense rows that already highlight on hover.
class LsMenuButton<T> extends StatelessWidget {
  final IconData icon;

  /// Falls back to the localized "Show menu" string of the material delegate.
  final String? tooltip;

  final List<LsMenuItem<T>> items;
  final ValueChanged<T> onSelected;

  /// Marks the trigger regardless of the open state, e.g. when a filter is
  /// active and the menu therefore hides rows.
  final bool active;

  /// 28px trigger for dense rows instead of the 38px header plate.
  final bool compact;

  /// Draws an empty square in the leading slot of unchecked entries, so the
  /// menu reads as a multi-select checkbox list rather than a plain toggle list.
  final bool checkbox;

  /// Shrinks the panel to the widest label (150px floor) and tightens the rows
  /// to 30px, for menus with two or three short toggle entries.
  final bool dense;

  /// Fixes the panel width instead of hugging the widest label. Required by
  /// [alignRight], whose position has to be computed before layout.
  final double? panelWidth;

  /// Hangs the panel from the trigger's right edge instead of its left one.
  ///
  /// [MenuAnchor] places an unconstrained panel by its top-left corner and
  /// clamps it against the window edge when it overflows, so a menu opened from
  /// the trailing trigger of a row ends up glued to that edge. Opening at an
  /// explicit position keeps the panel's gap to the window.
  final bool alignRight;

  const LsMenuButton({
    super.key,
    required this.icon,
    this.tooltip,
    required this.items,
    required this.onSelected,
    this.active = false,
    this.compact = false,
    this.checkbox = false,
    this.dense = false,
    this.panelWidth,
    this.alignRight = false,
  }) : assert(!alignRight || panelWidth != null, 'alignRight places the panel by its right edge, which needs panelWidth.');

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final rowRadius = BorderRadius.circular(tokens.radiusSm - 2);

    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      style: _menuStyle(context, dense: dense),
      menuChildren: _menuChildren(context, items: items, onSelected: onSelected, dense: dense, checkbox: checkbox, fixedWidth: panelWidth),
      builder: (context, controller, _) {
        final highlighted = active || controller.isOpen;
        // [alignRight] has to know the trigger's width, which is only available
        // once it is laid out. [MenuAnchor]'s own builder context resolves to no
        // render object, so the trigger is measured through a [Builder] below.
        void toggle(BuildContext trigger) {
          if (controller.isOpen) {
            controller.close();
            return;
          }
          final box = alignRight ? trigger.findRenderObject() : null;
          controller.open(
            // The explicit position is relative to the trigger's top-left corner
            // and replaces `alignmentOffset`, hence the vertical gap here.
            position: box is RenderBox ? Offset(box.size.width - panelWidth!, box.size.height + 6) : null,
          );
        }

        return Builder(
          builder: (trigger) => Tooltip(
            message: tooltip ?? MaterialLocalizations.of(context).showMenuTooltip,
            child: compact
                ? SizedBox(
                    width: 28,
                    height: 28,
                    child: LsHover(
                      color: Colors.transparent,
                      hoverColor: Colors.transparent,
                      borderRadius: rowRadius,
                      onTap: () => toggle(trigger),
                      builder: (context, hovered) => Center(
                        // The dense row already highlights itself, so the glyph
                        // only moves from faint to muted instead of adding a plate.
                        child: Icon(icon, size: 15, color: hovered || highlighted ? colors.muted : colors.faint),
                      ),
                    ),
                  )
                : LsIconButton(icon: icon, active: highlighted, onPressed: () => toggle(trigger)),
          ),
        );
      },
    );
  }
}

/// The panel styling shared by [LsMenuButton] and [LsMenuChip]: `bg2` surface,
/// no elevation, hairline outline and the tile radius. [dense] tightens the
/// panel padding, and the rows built by [_menuChildren], for panels with only
/// two or three short entries.
///
/// There is deliberately no `maximumSize` here: the vertical panel measures
/// itself with an `IntrinsicWidth`, which lays its child out at the content's
/// intrinsic width even when that exceeds the incoming box, so a style maximum
/// left a wide label overflowing a narrow panel. Fixing the width on the rows
/// (see [LsMenuButton.panelWidth]) is what actually bounds the panel.
MenuStyle _menuStyle(BuildContext context, {required bool dense}) {
  final tokens = context.ls;
  final colors = tokens.colors;
  return MenuStyle(
    backgroundColor: WidgetStatePropertyAll(colors.bg2),
    elevation: const WidgetStatePropertyAll(0),
    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: dense ? 3 : 4)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: tokens.tileRadius,
        side: BorderSide(color: colors.line, width: tokens.hairlineOf(context)),
      ),
    ),
  );
}

/// The rows of an [LsMenuButton] / [LsMenuChip] panel. Unchecked entries keep
/// the 20px leading slot empty so the labels stay aligned in mixed (toggle)
/// menus; [checkbox] swaps the empty slot for an outlined square.
List<Widget> _menuChildren<T>(
  BuildContext context, {
  required List<LsMenuItem<T>> items,
  required ValueChanged<T> onSelected,
  required bool dense,
  bool checkbox = false,
  double? fixedWidth,
  double? minRowWidth,
}) {
  // [fixedWidth] pins every row, which also pins the panel: the rows are what
  // the panel's IntrinsicWidth measures. [minRowWidth] is only a floor for a
  // panel that hugs its labels, and defaults to a readable width so two short
  // labels do not leave a sliver of a panel.
  final minWidth = fixedWidth ?? minRowWidth ?? (dense ? 150 : 220);
  final tokens = context.ls;
  final colors = tokens.colors;
  final rowRadius = BorderRadius.circular(tokens.radiusSm - 2);

  Widget buildRow(LsMenuItem<T> item) {
    final row = MenuItemButton(
      onPressed: () => onSelected(item.value),
      style: MenuItemButton.styleFrom(
        foregroundColor: colors.fg,
        overlayColor: colors.bg3,
        minimumSize: Size(minWidth, dense ? 30 : 34),
        // Without this the padded tap target stretches every row to 48px, so the
        // minimumSize above never takes effect.
        tapTargetSize: dense ? MaterialTapTargetSize.shrinkWrap : null,
        padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10),
        shape: RoundedRectangleBorder(borderRadius: rowRadius),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: item.checked
                ? Icon(LucideIcons.check, size: 13, color: colors.accent)
                : checkbox
                ? Icon(LucideIcons.square, size: 13, color: colors.faint)
                : null,
          ),
          Flexible(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.bodySm.copyWith(color: colors.fg),
            ),
          ),
        ],
      ),
    );
    // The wrapper is what actually bounds the panel: it reports exactly
    // [fixedWidth] as its intrinsic width, so a wide label cannot stretch the
    // panel past it.
    return fixedWidth == null ? row : SizedBox(width: fixedWidth, child: row);
  }

  return [for (final item in items) buildRow(item)];
}

/// Chip trigger that opens the same design-language panel as [LsMenuButton].
///
/// Use it where the chosen value has to stay readable without opening the menu
/// (a sort order next to the grid/list switch). The chip keeps the current
/// label, a small chevron marks it as a menu rather than a switch that advances
/// on every tap, and the panel marks the entry in effect with the accent check.
class LsMenuChip<T> extends StatelessWidget {
  final String label;

  final String? tooltip;

  final List<LsMenuItem<T>> items;
  final ValueChanged<T> onSelected;

  /// Shrinks the panel to the widest label (150px floor) and tightens the rows
  /// to 30px, for menus with two or three short entries.
  final bool dense;

  const LsMenuChip({
    super.key,
    required this.label,
    required this.items,
    required this.onSelected,
    this.tooltip,
    this.dense = true,
  });

  @override
  Widget build(BuildContext context) {
    // No `alignmentOffset`: [MenuAnchor] places the panel under the trigger and
    // flips it above when it would not fit — which is the case for a footer
    // band sitting on the bottom edge of the window.
    return MenuAnchor(
      style: _menuStyle(context, dense: dense),
      // No row minimum: the panel hugs the widest order label, so a three-entry
      // sort menu stays small next to the chip instead of carrying a 150px floor.
      menuChildren: _menuChildren(context, items: items, onSelected: onSelected, dense: dense, minRowWidth: 0),
      builder: (context, controller, _) {
        void toggle() => controller.isOpen ? controller.close() : controller.open();

        return LsChip(
          accent: controller.isOpen,
          tooltip: tooltip,
          onTap: toggle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 4),
              const Icon(LucideIcons.chevronDown, size: 11),
            ],
          ),
        );
      },
    );
  }
}
