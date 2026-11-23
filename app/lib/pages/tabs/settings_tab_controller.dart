import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/theme.dart';
import 'package:sonar/model/state/server/server_state.dart';
import 'package:sonar/model/state/settings_state.dart';
import 'package:sonar/pages/language_page.dart';
import 'package:sonar/pages/tabs/settings_tab_vm.dart';
import 'package:sonar/provider/device_info_provider.dart';
import 'package:sonar/provider/local_ip_provider.dart';
import 'package:sonar/provider/network/server/server_provider.dart';
import 'package:sonar/provider/settings_provider.dart';
import 'package:sonar/util/native/autostart_helper.dart';
import 'package:sonar/util/native/context_menu_helper.dart';
import 'package:sonar/util/ui/snackbar.dart';
import 'package:sonar_isolates/isolate.dart';
import 'package:sonar_isolates/model/device_info_result.dart';
import 'package:sonar_isolates/util/sleep.dart';

final settingsTabControllerProvider = ReduxProvider<SettingsTabController, SettingsTabVm>((ref) {
  final settings = ref.notifier(settingsProvider);
  final server = ref.notifier(serverProvider);
  final isolateController = ref.notifier(parentIsolateProvider);
  final localIpService = ref.notifier(localIpProvider);
  final initialDeviceInfo = ref.read(deviceInfoProvider);

  return SettingsTabController(
    settingsService: settings,
    serverNotifier: server,
    isolateController: isolateController,
    localIpService: localIpService,
    initialDeviceInfo: initialDeviceInfo,
  );
});

class SettingsTabController extends ReduxNotifier<SettingsTabVm> {
  final SettingsService _settingsService;
  final ServerService _serverService;
  final IsolateController _isolateController;
  final LocalIpService _localIpService;
  final DeviceInfoResult _initialDeviceInfo;

  /// The settings the running server was started with. The server only reads
  /// them once, so a difference to the current settings shows what still needs
  /// a restart.
  SettingsState _appliedSettings;

  SettingsTabController({
    required SettingsService settingsService,
    required ServerService serverNotifier,
    required IsolateController isolateController,
    required LocalIpService localIpService,
    required DeviceInfoResult initialDeviceInfo,
  }) : _settingsService = settingsService,
       _serverService = serverNotifier,
       _isolateController = isolateController,
       _localIpService = localIpService,
       _initialDeviceInfo = initialDeviceInfo,
       _appliedSettings = settingsService.state;

  @override
  SettingsTabVm init() {
    return SettingsTabVm(
      aliasController: TextEditingController(text: _settingsService.state.alias),
      deviceModelController: TextEditingController(text: _initialDeviceInfo.deviceModel),
      portController: TextEditingController(text: _settingsService.state.port.toString()),
      timeoutController: TextEditingController(text: _settingsService.state.discoveryTimeout.toString()),
      multicastController: TextEditingController(text: _settingsService.state.multicastGroup),
      settings: _settingsService.state,
      serverState: _serverService.state,
      deviceInfo: _initialDeviceInfo,
      pendingRestart: _pendingRestart(server: _serverService.state, settings: _settingsService.state),
      autoStart: false,
      autoStartLaunchHidden: false,
      showInContextMenu: false,
      onChangeTheme: (context, theme) async {
        await _settingsService.setTheme(theme);
        await sleepAsync(500); // workaround: brightness takes some time to be updated
        if (context.mounted) {
          await updateSystemOverlayStyle(context);
        }
      },
      onTapLanguage: (context) async {
        await context.push(() => const LanguagePage());
      },
      onToggleAutoStart: (context) async {
        final bool success;
        if (state.autoStart) {
          success = await disableAutoStart();
        } else {
          success = await enableAutoStart(startHidden: state.autoStartLaunchHidden);
        }

        if (success) {
          redux.dispatch(_SetAutoStartAction(!state.autoStart));
        }
      },
      onToggleAutoStartLaunchHidden: (context) async {
        if (state.autoStart) {
          final success = await enableAutoStart(startHidden: !state.autoStartLaunchHidden);
          if (success) {
            redux.dispatch(_SetAutoStartLaunchHiddenAction(!state.autoStartLaunchHidden));
          }
        }
      },
      onToggleShowInContextMenu: (context) async {
        final bool success;
        if (state.showInContextMenu) {
          success = await disableContextMenu();
        } else {
          success = await enableContextMenu();
        }
        if (success) {
          redux.dispatch(_SetShowInContextMenuAction(!state.showInContextMenu));
        }
      },
      onTapRestartServer: (context) async {
        try {
          final newServerState = await _serverService.restartServer(
            alias: _settingsService.state.alias,
            port: _settingsService.state.port,
            https: _settingsService.state.https,
          );

          if (newServerState != null) {
            await _applyServerState(newServerState);
          }
        } catch (e) {
          // ignore: use_build_context_synchronously
          context.showSnackBar(e.toString());
        }
      },
      onTapStartServer: (context) async {
        try {
          final newServerState = await _serverService.startServerFromSettings();
          if (newServerState != null) {
            await _applyServerState(newServerState);
          }
        } catch (e) {
          // ignore: use_build_context_synchronously
          context.showSnackBar(e.toString());
        }
      },
      onTapStopServer: () async => await _serverService.stopServer(),
    );
  }

  /// Writes back the state the server actually started with, so the fields stop showing an
  /// alias the server invented for an empty one and a port it clamped into range.
  Future<void> _applyServerState(ServerState serverState) async {
    state.aliasController.text = serverState.alias;
    state.portController.text = serverState.port.toString();
    await _settingsService.setAlias(serverState.alias);
    await _settingsService.setPort(serverState.port);
    external(_isolateController).dispatch(IsolateDiscoveryRestartAction());
    external(_localIpService).dispatchAsync(FetchLocalIpAction()); // ignore: unawaited_futures
    redux.dispatch(_ApplyServerSettingsAction());
  }

  /// The settings the running server has not picked up yet: it reads them once
  /// when it starts, and so does the multicast discovery it binds.
  Set<ServerSetting> _pendingRestart({required ServerState? server, required SettingsState settings}) {
    if (server == null) {
      // Stopped: the next start reads the current settings anyway.
      return const {};
    }

    final applied = _appliedSettings;
    return {
      if (applied.alias != settings.alias) ServerSetting.alias,
      if (applied.port != settings.port) ServerSetting.port,
      if (applied.https != settings.https) ServerSetting.https,
      if (applied.multicastGroup != settings.multicastGroup) ServerSetting.multicastGroup,
      if (applied.discoveryTimeout != settings.discoveryTimeout) ServerSetting.discoveryTimeout,
      if (!_listEq(applied.networkWhitelist, settings.networkWhitelist) || !_listEq(applied.networkBlacklist, settings.networkBlacklist))
        ServerSetting.networkInterfaces,
    };
  }

  @override
  get initialAction => _SettingsTabInitAction();

  @override
  void dispose() {
    state.aliasController.dispose();
    state.deviceModelController.dispose();
    state.portController.dispose();
    state.timeoutController.dispose();
    state.multicastController.dispose();
    super.dispose();
  }
}

class _SettingsTabInitAction extends AsyncReduxAction<SettingsTabController, SettingsTabVm> {
  @override
  Future<SettingsTabVm> reduce() async {
    dispatch(_SettingsTabWatchAction());
    final autoStartEnabled = await isAutoStartEnabled();
    final autoStartHidden = await isAutoStartHidden();
    final showInContextMenu = await isContextMenuEnabled();
    return state.copyWith(
      autoStart: autoStartEnabled,
      autoStartLaunchHidden: autoStartHidden,
      showInContextMenu: showInContextMenu,
    );
  }
}

class _SettingsTabWatchAction extends WatchAction<SettingsTabController, SettingsTabVm> {
  @override
  SettingsTabVm reduce() {
    final settings = ref.watch(settingsProvider);
    final serverState = ref.watch(serverProvider);

    final prevServer = state.serverState;
    if (serverState != null &&
        (prevServer == null ||
            prevServer.alias != serverState.alias ||
            prevServer.port != serverState.port ||
            prevServer.https != serverState.https)) {
      // A new server started from the current settings.
      notifier._appliedSettings = settings;
    }
    // The alias can also change outside this page (the device name in the window
    // header), so the field follows it instead of showing a stale name.
    if (state.settings.alias != settings.alias) {
      state.aliasController.text = settings.alias;
    }

    return state.copyWith(
      settings: settings,
      serverState: serverState,
      deviceInfo: ref.watch(deviceInfoProvider),
      pendingRestart: notifier._pendingRestart(server: serverState, settings: settings),
    );
  }
}

class _SetAutoStartAction extends ReduxAction<SettingsTabController, SettingsTabVm> {
  final bool enabled;

  _SetAutoStartAction(this.enabled);

  @override
  SettingsTabVm reduce() {
    return state.copyWith(autoStart: enabled);
  }
}

class _SetAutoStartLaunchHiddenAction extends ReduxAction<SettingsTabController, SettingsTabVm> {
  final bool enabled;

  _SetAutoStartLaunchHiddenAction(this.enabled);

  @override
  SettingsTabVm reduce() {
    return state.copyWith(autoStartLaunchHidden: enabled);
  }
}

class _SetShowInContextMenuAction extends ReduxAction<SettingsTabController, SettingsTabVm> {
  final bool enabled;

  _SetShowInContextMenuAction(this.enabled);

  @override
  SettingsTabVm reduce() {
    return state.copyWith(showInContextMenu: enabled);
  }
}

class _ApplyServerSettingsAction extends ReduxAction<SettingsTabController, SettingsTabVm> {
  @override
  SettingsTabVm reduce() {
    // The server (re)started with the settings it was given, so everything is
    // applied now, including the discovery configuration nobody reports back.
    notifier._appliedSettings = notifier._settingsService.state;
    return state.copyWith(pendingRestart: const {});
  }
}

/// Compares two optional lists element by element, which [List] does not.
bool _listEq(List<String>? a, List<String>? b) {
  if (a == null || b == null) {
    return a == b;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
