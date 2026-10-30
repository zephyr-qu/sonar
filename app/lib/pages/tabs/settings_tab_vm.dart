import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/model/state/server/server_state.dart';
import 'package:localsend_app/model/state/settings_state.dart';
import 'package:localsend_isolates/model/device_info_result.dart';

part 'settings_tab_vm.mapper.dart';

/// The settings a running server only picks up on its next start: the alias,
/// port and protocol it was started with, and the multicast group, bind
/// interfaces and discovery timeout its sockets were bound with.
enum ServerSetting { alias, port, https, multicastGroup, discoveryTimeout, networkInterfaces }

@MappableClass()
class SettingsTabVm with SettingsTabVmMappable {
  final TextEditingController aliasController;
  final TextEditingController deviceModelController;
  final TextEditingController portController;
  final TextEditingController timeoutController;
  final TextEditingController multicastController;

  final SettingsState settings;
  final ServerState? serverState;
  final DeviceInfoResult deviceInfo;
  final List<ThemeMode> themeModes = ThemeMode.values;
  final List<ColorMode> colorModes;
  final bool autoStart;
  final bool autoStartLaunchHidden;
  final bool showInContextMenu;
  final void Function(BuildContext context, ThemeMode mode) onChangeTheme;
  final void Function(BuildContext context, ColorMode mode) onChangeColorMode;
  final void Function(BuildContext context) onTapLanguage;
  final void Function(BuildContext context) onToggleAutoStart;
  final void Function(BuildContext context) onToggleAutoStartLaunchHidden;
  final void Function(BuildContext context) onToggleShowInContextMenu;
  final void Function(BuildContext context) onTapRestartServer;
  final void Function(BuildContext context) onTapStartServer;
  final void Function() onTapStopServer;

  /// Settings the running server has not picked up yet (empty while it is
  /// stopped, as the next start reads them anyway).
  final Set<ServerSetting> pendingRestart;
  SettingsTabVm({
    required this.aliasController,
    required this.deviceModelController,
    required this.portController,
    required this.timeoutController,
    required this.multicastController,
    required this.settings,
    required this.serverState,
    required this.deviceInfo,
    required this.colorModes,
    required this.autoStart,
    required this.autoStartLaunchHidden,
    required this.showInContextMenu,
    required this.onChangeTheme,
    required this.onChangeColorMode,
    required this.onTapLanguage,
    required this.onToggleAutoStart,
    required this.onToggleAutoStartLaunchHidden,
    required this.onToggleShowInContextMenu,
    required this.onTapRestartServer,
    required this.onTapStartServer,
    required this.onTapStopServer,
    required this.pendingRestart,
  });
}
