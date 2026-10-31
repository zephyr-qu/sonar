import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/config/design_tokens.dart';

/// The capsule switch of the design language: 40×24 track, 18px thumb, accent
/// when on — one step smaller than the Material switch so it sits lightly on a
/// settings row on both mobile and desktop.
///
/// The track stays small, but the control is full-sized: the padding around it
/// makes the tap target 44×44, it is a focus target, and Space/Enter toggle it
/// like a tap. Only keyboard focus shows a ring (an accent halo), so a click does
/// not leave a highlight behind.
class LsSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  const LsSwitch({required this.value, required this.onChanged, this.label, super.key});

  @override
  State<LsSwitch> createState() => _LsSwitchState();
}

class _LsSwitchState extends State<LsSwitch> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final enabled = widget.onChanged != null;
    return Semantics(
      label: widget.label,
      toggled: widget.value,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: FocusableActionDetector(
          enabled: enabled,
          mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onShowFocusHighlight: (focused) {
            if (focused != _focused) {
              setState(() => _focused = focused);
            }
          },
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onChanged?.call(!widget.value);
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => widget.onChanged!(!widget.value) : null,
            child: Padding(
              // 24 + 2×10 = 44 tall, 40 + 2×2 = 44 wide: a finger-sized target that
              // does not change the weight of the switch inside the row.
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 40,
                height: 24,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: widget.value ? colors.accent : colors.muted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                  // A spread-only shadow is a focus ring that does not take part in
                  // layout, so switching focus never nudges the row.
                  boxShadow: _focused ? [BoxShadow(color: colors.accent, spreadRadius: 2, blurRadius: 0)] : null,
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: widget.value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.value ? colors.accentFg : colors.fg,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
