import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/native/cmd_helper.dart';
import 'package:localsend_app/util/native/macos_channel.dart' as macos_channel;
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/dialogs/not_available_on_platform_dialog.dart';
import 'package:localsend_app/widget/ls/ls_buttons.dart';
import 'package:localsend_app/widget/ls/ls_card.dart';
import 'package:localsend_app/widget/ls/ls_header.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class TroubleshootPage extends StatelessWidget {
  const TroubleshootPage();

  @override
  Widget build(BuildContext context) {
    final settings = context.ref.watch(settingsProvider);
    final tokens = context.ls;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LsSubHeader(
                  title: t.troubleshootPage.title,
                  onBack: () => context.pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      Text(t.troubleshootPage.subTitle, style: tokens.bodySm),
                      const SizedBox(height: 4),
                      if (checkPlatformIsDesktop())
                        _TroubleshootItem(
                          symptomText: t.troubleshootPage.firewall.symptom,
                          solutionText: t.troubleshootPage.firewall.solution(port: settings.port),
                          primaryButton: _FixButton(
                            label: t.troubleshootPage.fixButton,
                            onTapMap: {
                              TargetPlatform.windows: _CommandFixAction(
                                adminPrivileges: true,
                                commands: [
                                  'netsh advfirewall firewall add rule name="LocalSend" dir=in action=allow protocol=TCP localport=${settings.port}',
                                  'netsh advfirewall firewall add rule name="LocalSend" dir=in action=allow protocol=UDP localport=${settings.port}',
                                ],
                              ),
                            },
                          ),
                          secondaryButton: _FixButton(
                            label: t.troubleshootPage.firewall.openFirewall,
                            onTapMap: {
                              TargetPlatform.windows: _CommandFixAction(
                                adminPrivileges: false,
                                commands: ['wf'],
                              ),
                              TargetPlatform.macOS: _NativeFixAction(() => macos_channel.openFirewallSettings()),
                            },
                          ),
                        ),
                      _TroubleshootItem(
                        symptomText: t.troubleshootPage.noDiscovery.symptom,
                        solutionText: t.troubleshootPage.noDiscovery.solution,
                      ),
                      _TroubleshootItem(
                        symptomText: t.troubleshootPage.noConnection.symptom,
                        solutionText: t.troubleshootPage.noConnection.solution,
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

class _TroubleshootItem extends StatefulWidget {
  final String symptomText;
  final String solutionText;
  final _FixButton? primaryButton;
  final _FixButton? secondaryButton;

  const _TroubleshootItem({
    required this.symptomText,
    required this.solutionText,
    this.primaryButton,
    this.secondaryButton,
  });

  @override
  State<_TroubleshootItem> createState() => _TroubleshootItemState();
}

class _TroubleshootItemState extends State<_TroubleshootItem> {
  bool _showCommands = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final hasButtons = widget.primaryButton?.onTap != null || widget.secondaryButton?.onTap != null;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LsCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.symptomText, style: tokens.subtitle),
            const SizedBox(height: 10),
            Text(t.troubleshootPage.solution.toUpperCase(), style: tokens.eyebrow),
            const SizedBox(height: 4),
            Text(widget.solutionText, style: tokens.bodySm.copyWith(color: colors.muted)),
            if (hasButtons) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.primaryButton?.onTap != null) widget.primaryButton!,
                  if (widget.secondaryButton?.onTap != null) widget.secondaryButton!,
                  if (widget.primaryButton?.onTap?.commands != null)
                    LsIconButton(
                      icon: _showCommands ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                      tooltip: t.troubleshootPage.solution,
                      onPressed: () => setState(() => _showCommands = !_showCommands),
                    ),
                ],
              ),
              AnimatedCrossFade(
                crossFadeState: _showCommands ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
                firstChild: const SizedBox(width: double.infinity),
                secondChild: SelectionArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final cmd in widget.primaryButton?.onTap?.commands ?? const <String>[])
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(cmd, style: tokens.mono.copyWith(height: 1.6)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FixButton extends StatelessWidget {
  final String label;
  final Map<TargetPlatform, _FixAction> onTapMap;
  final _FixAction? onTap;

  _FixButton({
    required this.label,
    required this.onTapMap,
  }) : onTap = onTapMap[defaultTargetPlatform];

  @override
  Widget build(BuildContext context) {
    return LsButton(
      label: label,
      variant: LsButtonVariant.ghost,
      onPressed: () async {
        if (onTap != null) {
          onTap!.runFix();
        } else {
          await showDialog(
            context: context,
            builder: (_) => NotAvailableOnPlatformDialog(platforms: onTapMap.keys.toList()),
          );
        }
      },
    );
  }
}

abstract class _FixAction {
  void runFix();

  List<String>? get commands;
}

class _CommandFixAction extends _FixAction {
  final bool adminPrivileges;

  @override
  final List<String> commands;

  _CommandFixAction({
    required this.adminPrivileges,
    required this.commands,
  });

  @override
  void runFix() async {
    if (adminPrivileges) {
      if (checkPlatform([TargetPlatform.windows])) {
        await runWindowsCommandAsAdmin(commands);
      } else {
        throw 'Admin privileges are only implemented on Windows.';
      }
    } else {
      for (final c in commands) {
        await Process.run(c, [], runInShell: true);
      }
    }
  }
}

class _NativeFixAction extends _FixAction {
  final Future<void> Function() action;

  _NativeFixAction(this.action);

  @override
  List<String>? get commands => null;

  @override
  void runFix() async {
    await action();
  }
}
