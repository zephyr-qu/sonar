import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/persistence/color_mode.dart';
import 'package:sonar/model/persistence/nearby_layout.dart';
import 'package:sonar/model/persistence/quick_save_mode.dart';
import 'package:sonar/model/state/settings_state.dart';
import 'package:sonar/provider/persistence_provider.dart';
import 'package:sonar/provider/window_dimensions_provider.dart';
import 'package:sonar/util/native/platform_check.dart';
import 'package:sonar_isolates/isolate.dart';
import 'package:sonar_isolates/model/device.dart';
import 'package:window_manager/window_manager.dart';

/// The range a TCP port can bind.
///
/// The port field parses any number, and an unusable one would only surface
/// later as a server that fails to start, with the value already persisted.
const minPort = 1;
const maxPort = 65535;

/// Bounds for the discovery timeout in milliseconds.
///
/// Below the lower bound the scan gives up before a peer can answer, above the
/// upper one it outlives the patience of the user waiting for the result.
const minDiscoveryTimeout = 100;
const maxDiscoveryTimeout = 60 * 1000;

final _listEq = const ListEquality().equals;

final settingsProvider = NotifierProvider<SettingsService, SettingsState>(
  (ref) {
    return SettingsService(ref.read(persistenceProvider));
  },
  onChanged: (_, next, ref) {
    final syncState = ref.read(parentIsolateProvider).syncState;
    if (_listEq(syncState.networkWhitelist, next.networkWhitelist) &&
        _listEq(syncState.networkBlacklist, next.networkBlacklist) &&
        syncState.multicastGroup == next.multicastGroup &&
        syncState.discoveryTimeout == next.discoveryTimeout) {
      return;
    }

    ref
        .redux(parentIsolateProvider)
        .dispatch(
          IsolateSyncSettingsAction(
            networkWhitelist: next.networkWhitelist,
            networkBlacklist: next.networkBlacklist,
            multicastGroup: next.multicastGroup,
            discoveryTimeout: next.discoveryTimeout,
          ),
        );
  },
);

class SettingsService extends PureNotifier<SettingsState> {
  final PersistenceService _persistence;

  SettingsService(this._persistence);

  @override
  SettingsState init() => SettingsState(
    showToken: _persistence.getShowToken(),
    alias: _persistence.getAlias(),
    theme: _persistence.getTheme(),
    colorMode: _persistence.getColorMode(),
    customColor: _persistence.getCustomColor(),
    locale: _persistence.getLocale(),
    port: _persistence.getPort(),
    networkWhitelist: _persistence.getNetworkWhitelist(),
    networkBlacklist: _persistence.getNetworkBlacklist(),
    multicastGroup: _persistence.getMulticastGroup(),
    destination: _persistence.getDestination(),
    saveToGallery: _persistence.isSaveToGallery(),
    saveToHistory: _persistence.isSaveToHistory(),
    quickSave: _persistence.getQuickSave() == QuickSaveMode.on,
    quickSaveFromFavorites: _persistence.getQuickSave() == QuickSaveMode.paired,
    receivePin: _persistence.getReceivePin(),
    autoFinish: _persistence.isAutoFinish(),
    minimizeToTray: _persistence.isMinimizeToTray(),
    https: _persistence.isHttps(),
    saveWindowPlacement: _persistence.getSaveWindowPlacement(),
    alwaysOnTop: _persistence.getAlwaysOnTop(),
    enableAnimations: _persistence.getEnableAnimations(),
    deviceType: _persistence.getDeviceType(),
    deviceModel: _persistence.getDeviceModel(),
    shareViaLinkAutoAccept: _persistence.getShareViaLinkAutoAccept(),
    receiveViaLinkAutoAccept: _persistence.getReceiveViaLinkAutoAccept(),
    createChecksums: _persistence.getCreateChecksums(),
    verifyChecksums: _persistence.getVerifyChecksums(),
    discoveryTimeout: _persistence.getDiscoveryTimeout(),
    nearbyLayout: _persistence.getNearbyLayout(),
  );

  Future<void> setAlias(String alias) async {
    await _persistence.setAlias(alias);
    state = state.copyWith(
      alias: alias,
    );
  }

  Future<void> setTheme(ThemeMode theme) async {
    await _persistence.setTheme(theme);
    state = state.copyWith(
      theme: theme,
    );
  }

  Future<void> setColorMode(ColorMode mode) async {
    await _persistence.setColorMode(mode);
    state = state.copyWith(
      colorMode: mode,
    );
  }

  Future<void> setCustomColor(Color color) async {
    await _persistence.setCustomColor(color);
    state = state.copyWith(
      customColor: color,
    );
  }

  Future<void> setNearbyLayout(NearbyLayout layout) async {
    await _persistence.setNearbyLayout(layout);
    state = state.copyWith(
      nearbyLayout: layout,
    );
  }

  Future<void> setLocale(AppLocale? locale) async {
    await _persistence.setLocale(locale);
    state = state.copyWith(
      locale: locale,
    );
  }

  Future<void> setPort(int port) async {
    final value = port.clamp(minPort, maxPort);
    await _persistence.setPort(value);
    state = state.copyWith(
      port: value,
    );
  }

  Future<void> setNetworkWhitelist(List<String>? whitelist) async {
    await _persistence.setNetworkWhitelist(whitelist);
    state = state.copyWith(
      networkWhitelist: whitelist,
    );
  }

  Future<void> setNetworkBlacklist(List<String>? blacklist) async {
    await _persistence.setNetworkBlacklist(blacklist);
    state = state.copyWith(
      networkBlacklist: blacklist,
    );
  }

  Future<void> setDiscoveryTimeout(int timeout) async {
    final value = timeout.clamp(minDiscoveryTimeout, maxDiscoveryTimeout);
    await _persistence.setDiscoveryTimeout(value);
    state = state.copyWith(
      discoveryTimeout: value,
    );
  }

  Future<void> setMulticastGroup(String group) async {
    await _persistence.setMulticastGroup(group);
    state = state.copyWith(
      multicastGroup: group,
    );
  }

  Future<void> setDestination(String? destination) async {
    await _persistence.setDestination(destination);
    state = state.copyWith(
      destination: destination,
    );
  }

  Future<void> setSaveToGallery(bool saveToGallery) async {
    await _persistence.setSaveToGallery(saveToGallery);
    state = state.copyWith(
      saveToGallery: saveToGallery,
    );
  }

  Future<void> setSaveToHistory(bool saveToHistory) async {
    await _persistence.setSaveToHistory(saveToHistory);
    state = state.copyWith(
      saveToHistory: saveToHistory,
    );
  }

  Future<void> setQuickSave(bool quickSave) async {
    final old = _persistence.getQuickSave();
    final QuickSaveMode mode;
    if (quickSave) {
      mode = QuickSaveMode.on;
    } else {
      mode = old == QuickSaveMode.on ? QuickSaveMode.off : old;
    }
    await _setQuickSaveMode(mode);
  }

  Future<void> setQuickSaveFromFavorites(bool quickSaveFromFavorites) async {
    final old = _persistence.getQuickSave();
    final QuickSaveMode mode;
    if (quickSaveFromFavorites) {
      mode = QuickSaveMode.paired;
    } else {
      mode = old == QuickSaveMode.paired ? QuickSaveMode.off : old;
    }
    await _setQuickSaveMode(mode);
  }

  Future<void> _setQuickSaveMode(QuickSaveMode mode) async {
    await _persistence.setQuickSave(mode);
    state = state.copyWith(
      quickSave: mode == QuickSaveMode.on,
      quickSaveFromFavorites: mode == QuickSaveMode.paired,
    );
  }

  Future<void> setReceivePin(String? receivePin) async {
    await _persistence.setReceivePin(receivePin);
    state = state.copyWith(
      receivePin: receivePin,
    );
  }

  Future<void> setAutoFinish(bool autoFinish) async {
    await _persistence.setAutoFinish(autoFinish);
    state = state.copyWith(
      autoFinish: autoFinish,
    );
  }

  Future<void> setMinimizeToTray(bool minimizeToTray) async {
    await _persistence.setMinimizeToTray(minimizeToTray);
    state = state.copyWith(
      minimizeToTray: minimizeToTray,
    );
  }

  Future<void> setHttps(bool https) async {
    await _persistence.setHttps(https);
    state = state.copyWith(
      https: https,
    );
  }

  Future<void> setSaveWindowPlacement(bool savePlacement) async {
    await WindowDimensionsController(_persistence).configureWindowFrameAutosave(enabled: savePlacement);
    await _persistence.setSaveWindowPlacement(savePlacement);
    state = state.copyWith(
      saveWindowPlacement: savePlacement,
    );
  }

  Future<void> setAlwaysOnTop(bool alwaysOnTop) async {
    if (!checkPlatformIsNotWaylandDesktop()) return;
    if (checkPlatformIsDesktop()) {
      await windowManager.setAlwaysOnTop(alwaysOnTop);
    }
    await _persistence.setAlwaysOnTop(alwaysOnTop);
    state = state.copyWith(alwaysOnTop: alwaysOnTop);
  }

  Future<void> setEnableAnimations(bool enableAnimations) async {
    await _persistence.setEnableAnimations(enableAnimations);
    state = state.copyWith(
      enableAnimations: enableAnimations,
    );
  }

  Future<void> setDeviceType(DeviceType deviceType) async {
    await _persistence.setDeviceType(deviceType);
    state = state.copyWith(
      deviceType: deviceType,
    );
  }

  Future<void> setDeviceModel(String deviceModel) async {
    await _persistence.setDeviceModel(deviceModel);
    state = state.copyWith(
      deviceModel: deviceModel,
    );
  }

  Future<void> setShareViaLinkAutoAccept(bool shareViaLinkAutoAccept) async {
    await _persistence.setShareViaLinkAutoAccept(shareViaLinkAutoAccept);

    state = state.copyWith(
      shareViaLinkAutoAccept: shareViaLinkAutoAccept,
    );
  }

  Future<void> setReceiveViaLinkAutoAccept(bool receiveViaLinkAutoAccept) async {
    await _persistence.setReceiveViaLinkAutoAccept(receiveViaLinkAutoAccept);

    state = state.copyWith(
      receiveViaLinkAutoAccept: receiveViaLinkAutoAccept,
    );
  }

  Future<void> setCreateChecksums(bool createChecksums) async {
    await _persistence.setCreateChecksums(createChecksums);
    state = state.copyWith(
      createChecksums: createChecksums,
    );
  }

  Future<void> setVerifyChecksums(bool verifyChecksums) async {
    await _persistence.setVerifyChecksums(verifyChecksums);
    state = state.copyWith(
      verifyChecksums: verifyChecksums,
    );
  }
}
