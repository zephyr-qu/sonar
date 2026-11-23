import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/provider/settings_provider.dart';
import 'package:sonar/util/native/cmd_helper.dart';
import 'package:sonar/util/native/macos_channel.dart' as macos_channel;
import 'package:sonar/util/native/platform_check.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_card.dart';
import 'package:sonar/widget/ls/ls_section_label.dart';

/// The guidance of upstream's standalone troubleshoot page, folded into the
/// debug page: three symptoms, their fix, and — on desktop — the button that
/// applies it (Windows firewall rules, macOS firewall settings).
class TroubleshootSection extends StatelessWidget {
  const TroubleshootSection({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch(settingsProvider);
    final isWindows = checkPlatform([TargetPlatform.windows]);
    final isMacOS = checkPlatform([TargetPlatform.macOS]);
    final firewallCommands = [
      'netsh advfirewall firewall add rule name="Sonar" dir=in action=allow protocol=TCP localport=${settings.port}',
      'netsh advfirewall firewall add rule name="Sonar" dir=in action=allow protocol=UDP localport=${settings.port}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LsSectionLabel(label: t.troubleshootPage.title),
        Text(t.troubleshootPage.subTitle, style: context.ls.bodySm),
        if (checkPlatformIsDesktop())
          _TroubleshootItem(
            symptom: t.troubleshootPage.firewall.symptom,
            solution: t.troubleshootPage.firewall.solution(port: settings.port),
            actions: [
              if (isWindows)
                LsButton(
                  label: t.troubleshootPage.fixButton,
                  icon: LucideIcons.wand2,
                  compact: true,
                  onPressed: () async => runWindowsCommandAsAdmin(firewallCommands),
                ),
              if (isWindows || isMacOS)
                LsButton(
                  label: t.troubleshootPage.firewall.openFirewall,
                  icon: LucideIcons.shieldCheck,
                  variant: LsButtonVariant.ghost,
                  compact: true,
                  onPressed: () async {
                    if (isWindows) {
                      // `wf` opens the Windows Defender Firewall control panel.
                      await Process.run('wf', [], runInShell: true);
                    } else {
                      await macos_channel.openFirewallSettings();
                    }
                  },
                ),
            ],
            commands: isWindows ? firewallCommands : null,
          ),
        _TroubleshootItem(
          symptom: t.troubleshootPage.noDiscovery.symptom,
          solution: t.troubleshootPage.noDiscovery.solution,
        ),
        _TroubleshootItem(
          symptom: t.troubleshootPage.noConnection.symptom,
          solution: t.troubleshootPage.noConnection.solution,
        ),
      ],
    );
  }
}

class _TroubleshootItem extends StatelessWidget {
  final String symptom;
  final String solution;
  final List<Widget> actions;

  /// Raw commands behind an automatic fix, shown so the fix can also be applied
  /// by hand (or inspected before an elevated shell runs it).
  final List<String>? commands;

  const _TroubleshootItem({
    required this.symptom,
    required this.solution,
    this.actions = const [],
    this.commands,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: LsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(symptom, style: tokens.bodyStrong),
            const SizedBox(height: 8),
            Text(t.troubleshootPage.solution, style: tokens.bodySm),
            Text(solution, style: tokens.body),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
            if (commands != null) ...[
              const SizedBox(height: 10),
              SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final command in commands!)
                      Text(
                        command,
                        style: tokens.mono.copyWith(fontSize: 11, color: tokens.colors.muted, height: 1.5),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
