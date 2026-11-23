import 'package:flutter/material.dart';
import 'package:sonar/config/design_tokens.dart';

/// Blocking spinner on the redesign's dialog surface.
///
/// It is opened with `barrierDismissible: false` and popped by its caller, so it
/// has no buttons; the small card keeps the scrim from flashing a bare spinner.
class LoadingDialog extends StatelessWidget {
  const LoadingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: colors.bg2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: tokens.cardRadius,
          side: BorderSide(color: colors.lineStrong, width: tokens.hairlineOf(context)),
        ),
        // [Dialog] puts a `minWidth: 280` constraint on its card and hands that
        // minimum down to the content, so a spinner in a 26px box is laid out
        // 232px wide. [CircularProgressIndicator] paints its arc into the full
        // size rect (`Offset & Size`), which turns the circle into an ellipse.
        // Empty constraints drop the 280 floor and [Center] keeps the box square.
        constraints: const BoxConstraints(),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: SizedBox.square(
              dimension: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ),
      ),
    );
  }
}
