import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/widget/dialogs/custom_bottom_sheet.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:system_settings_2/system_settings_2.dart';

class LocalNetworkDialog extends StatelessWidget {
  const LocalNetworkDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomBottomSheet(
      title: t.dialogs.localNetworkUnauthorized.title,
      description: t.dialogs.localNetworkUnauthorized.description,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          LsButton(
            label: t.general.close,
            variant: LsButtonVariant.ghost,
            onPressed: () => context.pop(),
          ),
          LsButton(
            label: t.dialogs.localNetworkUnauthorized.gotoSettings,
            icon: LucideIcons.settings,
            onPressed: () async => SystemSettings.app(),
          ),
        ],
      ),
    );
  }
}
