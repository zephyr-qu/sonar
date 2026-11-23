import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/util/native/platform_check.dart';
import 'package:sonar/widget/dialogs/custom_bottom_sheet.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';

/// Release announcement, shown once after an update: a dialog on desktop and a
/// bottom sheet on mobile.
class WhatsNewDialog extends StatelessWidget {
  final String version;
  final WhatsNewStrings strings;

  const WhatsNewDialog({
    super.key,
    required this.version,
    required this.strings,
  });

  /// The announcement that [lastVersion] has not seen yet, or `null` when the
  /// user has already dismissed it.
  static WhatsNewDialog? fromLastVersion({required String? lastVersion}) {
    return switch (lastVersion) {
      null => WhatsNewDialog(version: '1.18.0', strings: t.whatsNewPage.changes.v1_18_0),
      _ => null,
    };
  }

  static Future<void> open(BuildContext context, WhatsNewDialog dialog) {
    if (checkPlatformIsDesktop()) {
      return showDialog(
        context: context,
        builder: (context) => LsDialog(
          title: Text(t.whatsNewPage.title(version: dialog.version)),
          content: _ChangeList(strings: dialog.strings),
          maxWidth: 460,
          actions: [
            LsButton(
              label: t.general.done,
              icon: LucideIcons.check,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      );
    }
    return context.pushBottomSheet(() => dialog);
  }

  @override
  Widget build(BuildContext context) {
    return CustomBottomSheet(
      title: t.whatsNewPage.title(version: version),
      description: null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChangeList(strings: strings),
          const SizedBox(height: 18),
          LsButton(
            label: t.general.done,
            icon: LucideIcons.check,
            expand: true,
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}

/// The bulleted list of changes shared by the dialog and the bottom sheet.
class _ChangeList extends StatelessWidget {
  final WhatsNewStrings strings;

  const _ChangeList({required this.strings});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final change in strings.changes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('·', style: tokens.body.copyWith(color: tokens.colors.accent)),
                const SizedBox(width: 8),
                Expanded(child: Text(change, style: tokens.body)),
              ],
            ),
          ),
      ],
    );
  }
}
