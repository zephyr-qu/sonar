import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/cross_file.dart';
import 'package:sonar/model/persistence/favorite_device.dart';
import 'package:sonar/model/state/nearby_devices_state.dart';
import 'package:sonar/pages/web_share_page.dart';
import 'package:sonar/provider/favorites_provider.dart';
import 'package:sonar/provider/local_ip_provider.dart';
import 'package:sonar/provider/network/nearby_devices_provider.dart';
import 'package:sonar/provider/network/scan_facade.dart';
import 'package:sonar/provider/network/send_provider.dart';
import 'package:sonar/provider/network/server/server_provider.dart';
import 'package:sonar/provider/selection/selected_sending_files_provider.dart';
import 'package:sonar/provider/settings_provider.dart';
import 'package:sonar/util/favorites.dart';
import 'package:sonar/util/native/file_picker.dart';
import 'package:sonar/util/ui/snackbar.dart';
import 'package:sonar/widget/dialogs/add_file_dialog.dart';
import 'package:sonar/widget/dialogs/address_input_dialog.dart';
import 'package:sonar_isolates/model/device.dart';
import 'package:sonar_isolates/model/session_status.dart';

/// State and actions of the "nearby" tab.
class NearbyTabVm {
  final String alias;
  final bool visible;
  final int port;
  final bool https;
  final bool scanning;
  final List<String> localIps;
  final List<CrossFile> selectedFiles;
  final List<Device> devices;
  final List<FavoriteDevice> favoriteDevices;

  final Future<void> Function(BuildContext context) onToggleVisibility;
  final Future<void> Function(BuildContext context) onManualIp;
  final Future<void> Function(BuildContext context) onScan;
  final Future<void> Function(BuildContext context) onAddFiles;
  final Future<void> Function(BuildContext context) onOpenLink;
  final Future<void> Function(BuildContext context) onClearFiles;
  final Future<void> Function(BuildContext context, Device device) onTapDevice;
  final Future<bool> Function(List<Device> devices) onSendToMany;
  final Future<bool> Function(Device device) onToggleFavorite;
  final Future<void> Function(FavoriteDevice favorite) onToggleFavoriteOffline;
  final void Function(int index) onRemoveFile;

  const NearbyTabVm({
    required this.alias,
    required this.visible,
    required this.port,
    required this.https,
    required this.scanning,
    required this.localIps,
    required this.selectedFiles,
    required this.devices,
    required this.favoriteDevices,
    required this.onToggleVisibility,
    required this.onManualIp,
    required this.onScan,
    required this.onAddFiles,
    required this.onOpenLink,
    required this.onClearFiles,
    required this.onTapDevice,
    required this.onSendToMany,
    required this.onToggleFavorite,
    required this.onToggleFavoriteOffline,
    required this.onRemoveFile,
  });
}

final nearbyTabVmProvider = ViewProvider((ref) {
  final settings = ref.watch(settingsProvider);
  final selectedFiles = ref.watch(selectedSendingFilesProvider);
  // One watch per provider: Refena warns (and re-subscribes) when a provider is
  // watched twice in the same build method.
  // Select the source fields, not `allDevices`: that getter builds a new map (and
  // `toList()` a new list) on every evaluation, so the selected value could never
  // compare equal and the view would rebuild on every provider notification.
  final (deviceMap, signalingMap, scanning) = ref.watch(
    nearbyDevicesProvider.select(
      (state) => (state.devices, state.signalingDevices, state.runningFavoriteScan || state.runningIps.isNotEmpty),
    ),
  );
  final devices = NearbyDevicesState.mergeDevices(deviceMap, signalingMap).values.toList();
  final favoriteDevices = ref.watch(favoritesProvider);
  final localIps = ref.watch(localIpProvider).localIps;
  final serverState = ref.watch(serverProvider);

  Future<List<CrossFile>> pickFiles(BuildContext context) async {
    if (pickerOptions.length == 1) {
      await ref.global.dispatchAsync(
        PickFileAction(option: pickerOptions.first, context: context),
      );
    } else {
      if (!context.mounted) {
        return ref.read(selectedSendingFilesProvider);
      }
      await AddFileDialog.open(context: context, options: pickerOptions);
    }
    return ref.read(selectedSendingFilesProvider);
  }

  return NearbyTabVm(
    alias: settings.alias,
    visible: serverState != null,
    port: serverState?.port ?? settings.port,
    https: serverState?.https ?? settings.https,
    scanning: scanning,
    localIps: localIps,
    selectedFiles: selectedFiles,
    devices: devices,
    favoriteDevices: favoriteDevices,
    onToggleVisibility: (context) async {
      final starting = ref.read(serverProvider) == null;
      if (starting) {
        await ref.notifier(serverProvider).startServerFromSettings();
      } else {
        await ref.notifier(serverProvider).stopServer();
      }
      if (!context.mounted) {
        return;
      }
      context.showSnackBar(starting ? t.nearbyTab.visibleToast : t.nearbyTab.hiddenToast);
    },
    onScan: (context) async {
      // Emptying the list is what makes a scan feel like a scan, so only do it for a scan that actually
      // starts: a second pull during the grace period would otherwise blank the devices the running scan
      // just found (`StartStagedScan` refuses to start a second one anyway).
      if (ref.read(nearbyDevicesProvider).runningFavoriteScan) {
        return;
      }
      ref.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
      await ref.global.dispatchAsync(StartSmartScan());
    },
    onAddFiles: (context) async {
      await pickFiles(context);
    },
    onClearFiles: (context) async {
      ref.redux(selectedSendingFilesProvider).dispatch(ClearSelectionAction());
    },
    onManualIp: (context) async {
      var files = ref.read(selectedSendingFilesProvider);
      if (files.isEmpty) {
        files = await pickFiles(context);
      }
      if (files.isEmpty || !context.mounted) {
        return;
      }
      final device = await showDialog<Device?>(
        context: context,
        builder: (_) => const AddressInputDialog(),
      );
      if (device != null && context.mounted) {
        await ref.notifier(sendProvider).startSession(target: device, files: files, background: false);
      }
    },
    onOpenLink: (context) async {
      final files = ref.read(selectedSendingFilesProvider);
      await context.push(() => WebSharePage(files: files.isEmpty ? null : files));
    },
    onTapDevice: (context, device) async {
      var files = ref.read(selectedSendingFilesProvider);
      if (files.isEmpty) {
        files = await pickFiles(context);
      }
      if (files.isEmpty) {
        return;
      }
      await ref.notifier(sendProvider).startSession(target: device, files: files, background: false);
    },
    onSendToMany: (targets) async {
      final files = ref.read(selectedSendingFilesProvider);
      if (files.isEmpty || targets.isEmpty) {
        return false;
      }
      // Every session is created synchronously, so all targets start at once and
      // the tray lists them all immediately. A device that already has a running
      // session is skipped instead of opening a second one.
      final active = ref
          .read(sendProvider)
          .values
          .where((session) => const {SessionStatus.waiting, SessionStatus.sending}.contains(session.status))
          .map((session) => session.target.fingerprint)
          .toSet();
      final transfers = [
        for (final device in targets)
          if (!active.contains(device.fingerprint)) ref.notifier(sendProvider).startSession(target: device, files: files, background: true),
      ];
      if (transfers.isEmpty) {
        return false;
      }
      // Awaited so the caller clears the selection only after nothing runs anymore.
      await Future.wait(transfers);
      return true;
    },
    onToggleFavoriteOffline: (favorite) async {
      await ref.redux(favoritesProvider).dispatchAsync(RemoveFavoriteAction(deviceFingerprint: favorite.fingerprint));
    },
    onToggleFavorite: (device) async {
      final entry = ref.read(favoritesProvider).findDevice(device);
      if (entry != null) {
        await ref.redux(favoritesProvider).dispatchAsync(RemoveFavoriteAction(deviceFingerprint: device.fingerprint));
        return false;
      }
      await ref
          .redux(favoritesProvider)
          .dispatchAsync(
            AddFavoriteAction(
              FavoriteDevice.fromValues(
                fingerprint: device.fingerprint,
                ip: device.ip ?? '',
                port: device.port,
                alias: device.alias,
                deviceType: device.deviceType,
              ),
            ),
          );
      return true;
    },
    onRemoveFile: (index) {
      ref.redux(selectedSendingFilesProvider).dispatch(RemoveSelectedFileAction(index));
    },
  );
});

/// Starts the first discovery scan when the nearby tab is opened for the first time.
class NearbyTabInitAction extends AsyncGlobalAction {
  @override
  Future<void> reduce() async {
    final devices = ref.read(nearbyDevicesProvider).devices;
    if (devices.isEmpty) {
      await dispatchAsync(StartSmartScan());
    }
  }
}
