import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sonar/config/design_tokens.dart';

/// The main header of a tab: accent mark, alias, status line and actions.
class LsScreenHeader extends StatelessWidget {
  final Widget mark;
  final String title;
  final Widget? subtitle;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  /// Makes the title block act as an edit affordance for the value it shows.
  final VoidCallback? onTitleTap;

  /// Tooltip of the tappable title block, e.g. the name of the setting it edits.
  final String? titleTooltip;

  const LsScreenHeader({
    required this.mark,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 8),
    this.onTitleTap,
    this.titleTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.accent, borderRadius: BorderRadius.circular(tokens.radiusSm)),
            child: IconTheme(
              data: IconThemeData(size: 17, color: colors.accentFg),
              child: mark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LsHeaderTitle(
              title: title,
              subtitle: subtitle,
              style: tokens.title,
              tooltip: titleTooltip,
              onTap: onTitleTap,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// The title line of a header, optionally clickable.
///
/// [onTitleTap] turns the block into an affordance: the pointer becomes a hand
/// and a hover highlight marks the target that can be clicked to change the
/// shown value.
class LsHeaderTitle extends StatelessWidget {
  final String title;
  final Widget? subtitle;
  final TextStyle? style;
  final VoidCallback? onTap;
  final String? tooltip;

  const LsHeaderTitle({
    required this.title,
    this.subtitle,
    this.style,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final onTap = this.onTap;
    // The tap target is the alias line itself, not the whole block: a hover
    // highlight spanning the empty space beside a short name reads like a bug.
    // Only vertical padding is added, so the title keeps its baseline and left
    // edge whether or not the header is editable.
    final titleLine = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      hoverColor: tokens.colors.bg3,
      child: Padding(
        // The padding only grows the tap target of an editable title, so a plain
        // header keeps its previous height down to the pixel.
        padding: EdgeInsets.symmetric(vertical: onTap == null ? 0 : 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onTap == null)
          titleLine
        else
          Tooltip(
            message: tooltip ?? title,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: titleLine,
            ),
          ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          subtitle!,
        ],
      ],
    );
  }
}

/// Header of a pushed page: back chevron, title, subtitle and a trailing slot.
class LsSubHeader extends StatelessWidget {
  final String title;
  final Widget? subtitle;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final EdgeInsetsGeometry padding;

  const LsSubHeader({
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onBack,
    this.padding = const EdgeInsets.fromLTRB(8, 10, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: Material(
              color: Colors.transparent,
              borderRadius: tokens.tileRadius,
              child: InkWell(
                onTap: onBack,
                borderRadius: tokens.tileRadius,
                hoverColor: colors.bg3,
                child: Icon(LucideIcons.chevronLeft, size: 20, color: colors.muted),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.title,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  subtitle!,
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// The small accent dot used for the visibility / online state.
class LsStatusDot extends StatelessWidget {
  final bool on;
  final double size;

  const LsStatusDot({required this.on, this.size = 6});

  @override
  Widget build(BuildContext context) {
    final colors = context.ls.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? colors.accent : colors.faint,
        boxShadow: on ? [BoxShadow(color: colors.accent.withValues(alpha: 0.14), spreadRadius: 3)] : null,
      ),
    );
  }
}

/// A row of small "key: value" stats used in headers and sidebars.
class LsStat extends StatelessWidget {
  final String label;
  final String value;

  const LsStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: tokens.eyebrow),
        const SizedBox(height: 4),
        Text(value, style: tokens.mono.copyWith(color: tokens.colors.fg)),
      ],
    );
  }
}
