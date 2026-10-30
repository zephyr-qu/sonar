import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// 36px search field of the redesign.
class LsSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  const LsSearchField({
    required this.hint,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colors.bg2,
        borderRadius: tokens.tileRadius,
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 14, color: colors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              textAlignVertical: TextAlignVertical.center,
              style: tokens.body,
              cursorColor: colors.accent,
              cursorWidth: 1.5,
              cursorHeight: 14,
              // Every border slot has to be nulled out explicitly: the global
              // `inputDecorationTheme` sets `enabledBorder`/`focusedBorder`, and
              // `InputDecoration.applyDefaults` copies them onto collapsed
              // decorations too, which painted a second rounded outline inside the
              // field's own container (the "inner border").
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                hintText: hint,
                hintStyle: tokens.body.copyWith(color: colors.faint),
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
