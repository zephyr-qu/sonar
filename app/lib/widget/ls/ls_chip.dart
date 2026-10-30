import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';

/// Pill-shaped meta label of the redesign (24px tall, monospace 10).
class LsChip extends StatelessWidget {
  final Widget child;
  final bool accent;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final String? tooltip;

  const LsChip({
    super.key,
    required this.child,
    this.accent = false,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 9),
    this.tooltip,
  });

  /// Convenience constructor for a plain text chip (optionally with a leading icon).
  LsChip.text(
    String text, {
    bool accent = false,
    VoidCallback? onTap,
    IconData? icon,
    String? tooltip,
    Key? key,
  }) : this(
         key: key,
         accent: accent,
         onTap: onTap,
         tooltip: tooltip,
         child: Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             if (icon != null) ...[
               Icon(icon, size: 12),
               const SizedBox(width: 4),
             ],
             Text(text),
           ],
         ),
       );

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final background = accent ? colors.accentSoft : colors.bg3;
    final foreground = accent ? colors.accentInk : colors.muted;

    Widget content = Container(
      height: 24,
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: IconTheme(
        data: IconThemeData(color: foreground, size: 12),
        child: DefaultTextStyle.merge(
          style: tokens.mono.copyWith(color: foreground, letterSpacing: 0.3),
          child: Center(widthFactor: 1, heightFactor: 1, child: child),
        ),
      ),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          hoverColor: accent ? colors.accentSoft : colors.lineStrong,
          child: content,
        ),
      );
    }

    if (tooltip != null) {
      content = Tooltip(message: tooltip!, child: content);
    }

    return content;
  }
}
