import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/widget/ls/ls_chip.dart';
import 'package:localsend_app/widget/ls/ls_header.dart';
import 'package:localsend_app/widget/ls/ls_switch.dart';
import 'package:localsend_isolates/constants.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// The window header of the desktop shell: device mark, alias, status line and
/// trailing chips/actions.
class LsDesktopHeader extends StatelessWidget {
  final Widget mark;
  final String title;
  final Widget? subtitle;
  final List<Widget> actions;

  const LsDesktopHeader({
    required this.mark,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.line, width: tokens.hairlineOf(context)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.bg3, borderRadius: BorderRadius.circular(tokens.radiusSm)),
            child: IconTheme(
              data: IconThemeData(size: 16, color: colors.fg),
              child: mark,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.subtitle,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                subtitle!,
              ],
            ],
          ),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

/// The shared device header of the desktop shell. It stays the same on every
/// screen so the rail and window chrome feel like one window.
class LsDesktopDeviceHeader extends StatelessWidget {
  const LsDesktopDeviceHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final settings = context.watch(settingsProvider);
    final network = context.watch(localIpProvider);
    final server = context.watch(serverProvider);
    final visible = server != null;
    final ip = network.localIps.isNotEmpty ? network.localIps.first : t.general.unknown;
    final port = server?.port ?? settings.port;
    final https = server?.https ?? settings.https;

    return LsDesktopHeader(
      mark: const Icon(LucideIcons.radar),
      title: settings.alias,
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LsStatusDot(on: visible),
          const SizedBox(width: 6),
          Text(visible ? t.nearbyTab.visible : t.nearbyTab.hidden, style: tokens.mono),
          const SizedBox(width: 10),
          Text('$ip:$port', style: tokens.mono.copyWith(color: tokens.colors.faint)),
        ],
      ),
      actions: [
        LsChip.text(https ? t.receiveRequestPage.secure : t.receiveRequestPage.plain, accent: https),
        const SizedBox(width: 8),
        LsChip.text(t.receiveRequestPage.protocol(version: protocolVersion)),
        const SizedBox(width: 12),
        Text(visible ? t.nearbyTab.visible : t.nearbyTab.hidden, style: tokens.mono),
        const SizedBox(width: 6),
        LsSwitch(
          value: visible,
          label: t.settingsPage.visibleToNetwork,
          onChanged: (_) async {
            final notifier = context.notifier(serverProvider);
            if (server == null) {
              await notifier.startServerFromSettings();
            } else {
              await notifier.stopServer();
            }
          },
        ),
      ],
    );
  }
}

/// Desktop content + 300px right-hand sidebar, separated by a hairline.
class LsDesktopLayout extends StatelessWidget {
  final Widget content;
  final Widget? aside;

  const LsDesktopLayout({required this.content, this.aside});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    if (aside == null) {
      return content;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: content),
        Container(
          width: 300,
          decoration: BoxDecoration(
            color: colors.bg2,
            border: Border(
              left: BorderSide(color: colors.line, width: tokens.hairlineOf(context)),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: SingleChildScrollView(child: aside!),
        ),
      ],
    );
  }
}
