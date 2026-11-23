import 'package:flutter/material.dart';

/// Interactive surface with the prototype's micro-interactions: a 150ms fill /
/// border transition on hover and a 0.985 press scale.
///
/// [builder] receives the current hover state so that callers can also animate
/// foreground colours (the prototype transitions icon/text colours as well).
class LsHover extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovered) builder;
  final Color color;
  final Color hoverColor;
  final BorderRadius borderRadius;
  final Color? borderColor;
  final VoidCallback? onTap;
  final MouseCursor? cursor;

  const LsHover({
    super.key,
    required this.builder,
    required this.color,
    required this.hoverColor,
    required this.borderRadius,
    this.borderColor,
    this.onTap,
    this.cursor,
  });

  @override
  State<LsHover> createState() => _LsHoverState();
}

class _LsHoverState extends State<LsHover> {
  bool _hover = false;
  bool _pressed = false;

  void _setHover(bool value) {
    if (_hover != value) {
      setState(() => _hover = value);
    }
  }

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = widget.borderColor;

    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : widget.cursor ?? SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _hover ? widget.hoverColor : widget.color,
            borderRadius: widget.borderRadius,
            border: border == null ? null : Border.all(color: border),
          ),
          child: Material(
            type: MaterialType.transparency,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: widget.borderRadius),
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: (_) => _setPressed(true),
              onTapUp: (_) => _setPressed(false),
              onTapCancel: () => _setPressed(false),
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              child: widget.builder(context, _hover),
            ),
          ),
        ),
      ),
    );
  }
}
