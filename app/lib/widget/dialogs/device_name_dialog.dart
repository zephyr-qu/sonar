import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/provider/device_info_provider.dart';
import 'package:sonar/provider/network/server/server_provider.dart';
import 'package:sonar/provider/settings_provider.dart';
import 'package:sonar/util/alias_generator.dart';
import 'package:sonar/util/device_type_ext.dart';
import 'package:sonar/util/native/device_info_helper.dart';
import 'package:sonar/util/ui/snackbar.dart';
import 'package:sonar/widget/dialogs/text_field_with_actions.dart';
import 'package:sonar_isolates/isolate.dart';

/// Upper bound for a device name.
///
/// The name is announced to the network and rendered in every peer's device
/// list, so an overlong one is at best truncated there and at worst pushes the
/// whole multicast announcement past the receive buffer of its peers.
const maxDeviceNameLength = 64;

/// Rejects a device name that cannot be announced or displayed.
///
/// The name is announced to the network and listed by every peer, so a blank one
/// is not a rename worth persisting, an overlong one is dropped or truncated on
/// the other side, and control characters (the tab or line break of a pasted
/// name) end up in their logs and single-line labels.
String? validateDeviceName(String value) {
  final name = value.trim();
  if (name.isEmpty) {
    return t.settingsTab.network.aliasInvalid;
  }
  if (name.runes.length > maxDeviceNameLength) {
    return t.settingsTab.network.aliasTooLong(maxLength: maxDeviceNameLength);
  }
  if (name.runes.any(_isControlCharacter)) {
    return t.settingsTab.network.aliasInvalidCharacters;
  }
  return null;
}

/// Whether [rune] is a control character, the kind a device name has no use of.
bool _isControlCharacter(int rune) => rune < 0x20 || rune == 0x7f;

/// Opens the device name dialog from a tappable header title and applies the result.
///
/// It is the dialog the settings page uses, so both entries share the same field
/// and the same shortcuts; only the row that opens it differs.
Future<void> showDeviceNameDialog(BuildContext context) async {
  final controller = TextEditingController(text: context.read(settingsProvider).alias);
  await showTextFieldDialog(
    context,
    name: t.settingsTab.network.alias,
    validator: validateDeviceName,
    controller: controller,
    // The controller exists only for this edit and dies with the dialog: the
    // closing route keeps building the field, so it cannot be disposed here.
    disposeController: true,
    actions: [DeviceNameActions(controller: controller)],
  );
  final alias = controller.text.trim();
  if (!context.mounted) {
    return;
  }
  await applyDeviceName(context, alias);
}

/// Persists [alias] and makes a running server announce it right away.
///
/// The alias is baked into the identity of a running server and into the
/// multicast announcement, so a renamed device keeps its old name on the network
/// until the server restarts. That restart happens here, except while a session
/// runs: dropping the transfer the user is watching is worse than a name that
/// lags behind, so that case only leaves the "restart the server" hint of the
/// settings page.
Future<void> applyDeviceName(BuildContext context, String alias) async {
  final settings = context.read(settingsProvider);
  final server = context.read(serverProvider);
  // The dialog commits whatever is in its field when it closes, including an
  // empty one, and a blank device name is not a rename worth a server restart.
  if (alias.isEmpty || alias == settings.alias) {
    return;
  }

  await context.notifier(settingsProvider).setAlias(alias);
  if (!context.mounted || server == null) {
    return;
  }

  if (server.session != null) {
    context.showSnackBar(t.settingsTab.network.needRestart);
    return;
  }

  try {
    await context
        .notifier(serverProvider)
        .restartServer(
          alias: alias,
          port: server.port,
          https: server.https,
          web: server.web,
        );
  } catch (e) {
    if (context.mounted) {
      context.showSnackBar(e.toString());
    }
    return;
  }

  if (!context.mounted) {
    return;
  }

  // Peers learn the new name from an announcement, not from the next scan.
  // Discovery is optional (it may have failed to start), which is no reason to
  // report the successful rename as an error.
  if (context.read(parentIsolateProvider).discovery != null) {
    context.redux(parentIsolateProvider).dispatch(IsolateDiscoveryAnnouncementAction());
  }
}

/// The random-name and system-name shortcuts of the device name dialog.
///
/// Shared by the settings row and the header title so both offer the same two
/// ways to fill in a name; [onPicked] lets a caller commit a pick immediately,
/// while the settings row relies on its `onClosed` to persist whatever the field
/// holds when the dialog goes away.
class DeviceNameActions extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onPicked;

  const DeviceNameActions({required this.controller, this.onPicked, super.key});

  void _fill(String name) {
    controller.text = name;
    onPicked?.call(name);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: t.settingsTab.network.generateRandomAlias,
          child: IconButton(
            onPressed: () => _fill(generateRandomAlias()),
            icon: const Icon(LucideIcons.dices),
          ),
        ),
        Tooltip(
          message: t.settingsTab.network.useSystemName,
          child: IconButton(
            onPressed: () async {
              final name = await getDeviceName();
              if (name != null) {
                _fill(name);
              }
            },
            // The name comes from the OS, so the icon follows the device this app actually
            // runs on.
            icon: Icon(context.read(deviceInfoProvider).deviceType.icon),
          ),
        ),
      ],
    );
  }
}
