import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';

/// Bottom sheet of the redesign: grabber, `bg2` surface, radius 22 and a
/// left-aligned 16/700 title with optional muted description.
///
/// The mobile counterpart of [LsDialog]; pushed via `context.pushBottomSheet`.
class CustomBottomSheet extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;

  const CustomBottomSheet({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;

    return Container(
      constraints: const BoxConstraints(maxWidth: 550),
      decoration: BoxDecoration(
        color: colors.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(color: colors.lineStrong, width: tokens.hairlineOf(context)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: colors.lineStrong, borderRadius: BorderRadius.circular(999)),
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: tokens.title),
              if (description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(description!, style: tokens.bodySm),
                ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
