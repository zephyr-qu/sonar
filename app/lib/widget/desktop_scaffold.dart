import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/provider/local_ip_provider.dart';
import 'package:sonar/provider/network/server/server_provider.dart';
import 'package:sonar/provider/settings_provider.dart';
import 'package:sonar/util/ui/snackbar.dart';
import 'package:sonar/widget/dialogs/device_name_dialog.dart';
import 'package:sonar/widget/ls/ls_chip.dart';
import 'package:sonar/widget/ls/ls_header.dart';
import 'package:sonar/widget/ls/ls_switch.dart';
import 'package:sonar_isolates/constants.dart';

/// The window header of the desktop shell: device mark, alias, status line and
/// trailing chips/actions.
class LsDesktopHeader extends StatelessWidget {
  final Widget mark;
  final String title;
  final Widget? subtitle;
  final List<Widget> actions;

  /// Makes the title block act as an edit affordance for the value it shows.
  final VoidCallback? onTitleTap;

  /// Tooltip of the tappable title block, e.g. the name of the setting it edits.
  final String? titleTooltip;

  const LsDesktopHeader({
    required this.mark,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onTitleTap,
    this.titleTooltip,
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
          LsHeaderTitle(
            title: title,
            subtitle: subtitle,
            style: tokens.subtitle,
            tooltip: titleTooltip,
            onTap: onTitleTap,
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
      titleTooltip: t.settingsTab.network.alias,
      onTitleTap: () => showDeviceNameDialog(context),
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
        _VisibilityControl(visible: visible),
      ],
    );
  }
}

/// The "visible on the network" toggle of the window header: a status word and
/// the switch, nothing more.
///
/// Starting and stopping the server hands off to a child isolate and can fail (a
/// port taken meanwhile, a missing connection), which used to look like a dead
/// button — a failure now reports itself instead of vanishing.
class _VisibilityControl extends StatefulWidget {
  final bool visible;

  const _VisibilityControl({required this.visible});

  @override
  State<_VisibilityControl> createState() => _VisibilityControlState();
}

class _VisibilityControlState extends State<_VisibilityControl> {
  /// Keeps a second start/stop from racing the one still in flight.
  bool _busy = false;

  /// Starting or stopping the server hands off to a child isolate. If that child
  /// is gone (a missing connection, a port taken meanwhile) the call would
  /// otherwise never settle, which is indistinguishable from a dead button.
  static const _timeout = Duration(seconds: 8);

  Future<void> _toggle() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final notifier = context.notifier(serverProvider);
    try {
      // Read the state at tap time, not at build time.
      if (context.read(serverProvider) == null) {
        await notifier.startServerFromSettings().timeout(_timeout);
      } else {
        await notifier.stopServer().timeout(_timeout);
      }
    } catch (e) {
      // A failure used to be swallowed here: the switch stayed where it was and
      // nothing on screen said why.
      if (mounted) {
        context.showSnackBar('${t.general.error}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final enabled = !_busy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Only the capsule toggles; the word beside it is a plain label.
        Text(widget.visible ? t.nearbyTab.visible : t.nearbyTab.hidden, style: tokens.mono),
        const SizedBox(width: 6),
        LsSwitch(
          value: widget.visible,
          label: t.settingsPage.visibleToNetwork,
          onChanged: enabled ? (_) => _toggle() : null,
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
