import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/addons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_card.dart';
import 'package:sonar/widget/ls/ls_header.dart';

class WhatsNewPage extends StatelessWidget {
  final String version;
  final WhatsNewStrings strings;

  const WhatsNewPage({
    super.key,
    required this.version,
    required this.strings,
  });

  static WhatsNewPage? fromLastVersion({required String? lastVersion}) {
    return switch (lastVersion) {
      null => WhatsNewPage(version: '1.18.0', strings: t.whatsNewPage.changes.v1_18_0),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LsSubHeader(
                  title: t.whatsNewPage.title(version: version),
                  onBack: () => context.pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      LsCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final change in strings.changes)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('·', style: tokens.bodySm.copyWith(color: tokens.colors.accent)),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(change, style: tokens.body)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      LsButton(
                        label: t.general.done,
                        icon: LucideIcons.check,
                        expand: true,
                        onPressed: () => context.global.dispatch(NavigateAction.pop()),
                      ),
                    ],
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
