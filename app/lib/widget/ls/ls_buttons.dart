import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/widget/ls/ls_hover.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum LsButtonVariant {
  /// Accent fill with dark ink.
  primary,

  /// Transparent with a strong hairline.
  ghost,

  /// `bg3` fill, used for secondary actions.
  plain,
}

/// 44px action button of the redesign.
class LsButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final LsButtonVariant variant;
  final bool expand;

  const LsButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = LsButtonVariant.primary,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final (background, hoverBackground, foreground) = switch (variant) {
      // The prototype brightens the primary fill by 6% instead of tinting it.
      LsButtonVariant.primary => (colors.accent, Color.lerp(colors.accent, Colors.white, 0.06)!, colors.accentFg),
      LsButtonVariant.ghost => (Colors.transparent, colors.bg2, colors.fg),
      LsButtonVariant.plain => (colors.bg3, colors.lineStrong, colors.fg),
    };
    final enabled = onPressed != null;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: LsHover(
        color: background,
        hoverColor: hoverBackground,
        borderRadius: tokens.tileRadius,
        borderColor: variant == LsButtonVariant.ghost ? colors.lineStrong : null,
        onTap: onPressed,
        builder: (context, hovered) => SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: foreground),
                  const SizedBox(width: 7),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.buttonLabel.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 38px square icon button (hover shows a `bg3` plate, active uses the accent).
class LsIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool active;

  const LsIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final color = active ? colors.accent : colors.muted;

    Widget button = SizedBox(
      width: 38,
      height: 38,
      child: LsHover(
        color: active ? colors.bg3 : Colors.transparent,
        hoverColor: colors.bg3,
        borderRadius: tokens.tileRadius,
        onTap: onPressed,
        builder: (context, hovered) => Center(
          // The prototype also transitions the glyph from muted to fg.
          child: TweenAnimationBuilder<Color?>(
            duration: const Duration(milliseconds: 150),
            tween: ColorTween(end: hovered && !active ? colors.fg : color),
            builder: (context, animated, child) => Icon(icon, size: 17, color: animated),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// A row that behaves like a link: hairline on top, label grows, chevron on the right.
class LsLinkRow extends StatelessWidget {
  final Widget? leading;
  final String label;
  final String? value;
  final IconData trailingIcon;
  final VoidCallback? onTap;
  final bool showTopBorder;

  const LsLinkRow({
    super.key,
    required this.label,
    this.leading,
    this.value,
    this.trailingIcon = LucideIcons.chevronRight,
    this.onTap,
    this.showTopBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final hairline = tokens.hairlineOf(context);
    return LsHover(
      color: Colors.transparent,
      hoverColor: Colors.transparent,
      borderRadius: BorderRadius.zero,
      onTap: onTap,
      builder: (context, hovered) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
        decoration: BoxDecoration(
          border: showTopBorder
              ? Border(
                  top: BorderSide(color: colors.line, width: hairline),
                )
              : null,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              TweenAnimationBuilder<Color?>(
                duration: const Duration(milliseconds: 140),
                tween: ColorTween(end: hovered ? colors.fg : colors.muted),
                builder: (context, animated, child) => IconTheme(
                  data: IconThemeData(size: 15, color: animated),
                  child: child!,
                ),
                child: leading!,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: TweenAnimationBuilder<Color?>(
                duration: const Duration(milliseconds: 140),
                tween: ColorTween(end: hovered ? colors.fg : colors.muted),
                builder: (context, animated, child) => Text(label, style: tokens.bodySm.copyWith(color: animated)),
              ),
            ),
            if (value != null) ...[
              Text(value!, style: tokens.mono),
              const SizedBox(width: 6),
            ],
            Icon(trailingIcon, size: 14, color: colors.faint),
          ],
        ),
      ),
    );
  }
}
