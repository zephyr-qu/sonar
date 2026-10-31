import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/model/persistence/nearby_layout.dart';
import 'package:localsend_app/model/state/settings_state.dart';
import 'package:localsend_app/pages/debug/debug_page.dart';
import 'package:localsend_app/pages/settings/network_interfaces_page.dart';
import 'package:localsend_app/pages/tabs/settings_tab_vm.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/alias_generator.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/i18n.dart';
import 'package:localsend_app/util/native/device_info_helper.dart';
import 'package:localsend_app/util/native/macos_channel.dart';
import 'package:localsend_app/util/native/pick_directory_path.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/custom_dropdown_button.dart';
import 'package:localsend_app/widget/dialogs/encryption_disabled_notice.dart';
import 'package:localsend_app/widget/dialogs/pin_dialog.dart';
import 'package:localsend_app/widget/dialogs/quick_save_from_favorites_notice.dart';
import 'package:localsend_app/widget/dialogs/quick_save_notice.dart';
import 'package:localsend_app/widget/dialogs/text_field_tv.dart';
import 'package:localsend_app/widget/dialogs/text_field_with_actions.dart';
import 'package:localsend_app/widget/ls/ls_buttons.dart';
import 'package:localsend_app/widget/ls/ls_chip.dart';
import 'package:localsend_app/widget/ls/ls_segmented.dart';
import 'package:localsend_app/widget/ls/ls_state_tag.dart';
import 'package:localsend_app/widget/ls/ls_switch.dart';
import 'package:localsend_isolates/constants.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

/// The categories of the settings. One category is one screen (or the right
/// pane on desktop), which keeps every page short enough to scan.
enum SettingsSectionId { device, receive, security, appearance, network, desktop }

/// How a row lays out its control: next to the label or below it.
enum SettingsRowKind { trailing, stacked }

/// One setting: label, optional helper text, the control and search metadata.
class SettingsRow {
  final String id;
  final String label;
  final String? description;
  final SettingsRowKind kind;
  final Widget child;

  /// Short current value for the search results, if there is one.
  final String? value;

  /// State of a boolean setting, used to render a capsule instead of "on"/"off".
  final bool? on;

  /// Marks a row that warns about a problem instead of showing a plain value,
  /// e.g. a setting the running server has not picked up yet.
  final bool warning;

  const SettingsRow({
    required this.id,
    required this.label,
    required this.kind,
    required this.child,
    this.description,
    this.value,
    this.on,
    this.warning = false,
  });

  bool matches(String query) {
    return label.toLowerCase().contains(query) || (description ?? '').toLowerCase().contains(query) || (value ?? '').toLowerCase().contains(query);
  }
}

/// State pill shown next to a section title on the settings index. Only
/// binary states are surfaced there; values such as the theme live on the
/// section page itself.
class SettingsTag {
  final String label;
  final bool on;

  const SettingsTag({required this.label, required this.on});
}

/// A settings category: title, icon and a builder for its rows and state tags.
class SettingsSection {
  final SettingsSectionId id;
  final String title;
  final IconData icon;
  final bool desktopOnly;
  final List<SettingsRow> Function(BuildContext context, SettingsTabVm vm) rows;
  final List<SettingsTag> Function(BuildContext context, SettingsTabVm vm) tags;

  const SettingsSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.rows,
    required this.tags,
    this.desktopOnly = false,
  });

  List<SettingsRow> buildRows(BuildContext context, SettingsTabVm vm) => rows(context, vm);

  List<SettingsTag> buildTags(BuildContext context, SettingsTabVm vm) => tags(context, vm);
}

/// All settings, grouped the way the user thinks about them rather than the
/// way the app stores them. The build is cheap: widget objects are only
/// allocated, not mounted, until a page renders them.
List<SettingsSection> buildSettingsSections() {
  return [
    _deviceSection(),
    _receiveSection(),
    _securitySection(),
    _appearanceSection(),
    _networkSection(),
    _desktopSection(),
  ];
}

// ------------------------------------------------------------------- device

SettingsSection _deviceSection() => SettingsSection(
  id: SettingsSectionId.device,
  title: t.settingsPage.groupDevice,
  icon: LucideIcons.smartphone,
  rows: (context, vm) {
    final ref = context.ref;
    final currentDeviceType = vm.settings.deviceType ?? vm.deviceInfo.deviceType;
    // `headless` and `server` belong to CLI / server instances of the protocol,
    // not to this app; keep a persisted one visible but off the bar otherwise.
    final selectableDeviceTypes = [
      DeviceType.mobile,
      DeviceType.desktop,
      DeviceType.web,
      if (!const [DeviceType.mobile, DeviceType.desktop, DeviceType.web].contains(currentDeviceType)) currentDeviceType,
    ];
    return [
      SettingsRow(
        id: 'device.alias',
        label: t.settingsTab.network.alias,
        kind: SettingsRowKind.stacked,
        child: TextFieldWithActions(
          name: t.settingsTab.network.alias,
          controller: vm.aliasController,
          onClosed: (value) async {
            await ref.notifier(settingsProvider).setAlias(value);
          },
          actions: [
            Tooltip(
              message: t.settingsTab.network.generateRandomAlias,
              child: IconButton(
                onPressed: () async {
                  final newAlias = generateRandomAlias();
                  vm.aliasController.text = newAlias;
                  await ref.notifier(settingsProvider).setAlias(newAlias);
                },
                icon: const Icon(LucideIcons.dices),
              ),
            ),
            Tooltip(
              message: t.settingsTab.network.useSystemName,
              child: IconButton(
                onPressed: () async {
                  final newAlias = await getDeviceName();
                  if (newAlias == null) {
                    return;
                  }
                  vm.aliasController.text = newAlias;
                  await ref.notifier(settingsProvider).setAlias(newAlias);
                },
                icon: const Icon(LucideIcons.monitor),
              ),
            ),
          ],
        ),
      ),
      ..._restartHint(context, vm, ServerSetting.alias),
      SettingsRow(
        id: 'device.visible',
        label: t.settingsPage.visibleToNetwork,
        kind: SettingsRowKind.trailing,
        on: vm.serverState != null,
        child: LsSwitch(
          value: vm.serverState != null,
          label: t.settingsPage.visibleToNetwork,
          onChanged: (value) async {
            if (value) {
              vm.onTapStartServer(context);
            } else {
              vm.onTapStopServer();
            }
          },
        ),
      ),
      SettingsRow(
        id: 'device.type',
        label: t.settingsTab.network.deviceType,
        kind: SettingsRowKind.stacked,
        value: _deviceTypeLabel(currentDeviceType),
        child: LsSegmented(
          // Only the types this app itself can be are selectable. `headless`
          // (CLI) and `server` are protocol-level types of other programs; a
          // persisted one is still shown so the current state stays visible.
          options: [for (final type in selectableDeviceTypes) _deviceTypeLabel(type)],
          icons: [for (final type in selectableDeviceTypes) type.icon],
          index: selectableDeviceTypes.indexOf(currentDeviceType),
          onChanged: (index) async {
            await ref.notifier(settingsProvider).setDeviceType(selectableDeviceTypes[index]);
          },
        ),
      ),
      SettingsRow(
        id: 'device.model',
        label: t.settingsTab.network.deviceModel,
        kind: SettingsRowKind.stacked,
        child: TextFieldTv(
          name: t.settingsTab.network.deviceModel,
          controller: vm.deviceModelController,
          onChanged: (value) async {
            await ref.notifier(settingsProvider).setDeviceModel(value);
          },
        ),
      ),
    ];
  },
  tags: (context, vm) {
    final visible = vm.serverState != null;
    return [SettingsTag(label: visible ? t.nearbyTab.visible : t.nearbyTab.hidden, on: visible)];
  },
);

// ------------------------------------------------------------------ receive

SettingsSection _receiveSection() => SettingsSection(
  id: SettingsSectionId.receive,
  title: t.settingsPage.groupReceiveSection,
  icon: LucideIcons.download,
  rows: (context, vm) {
    final ref = context.ref;
    return [
      if (checkPlatformWithFileSystem())
        SettingsRow(
          id: 'receive.destination',
          label: t.settingsTab.receive.destination,
          kind: SettingsRowKind.trailing,
          value: vm.settings.destination ?? t.settingsTab.receive.downloads,
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(context).inputDecorationTheme.fillColor,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () async {
              if (vm.settings.destination != null) {
                await ref.notifier(settingsProvider).setDestination(null);
                if (defaultTargetPlatform == TargetPlatform.macOS) {
                  await removeExistingDestinationAccess();
                }
                return;
              }
              final directory = await pickDirectoryPath();
              if (directory != null) {
                if (defaultTargetPlatform == TargetPlatform.macOS) {
                  await persistDestinationFolderAccess(directory);
                }
                await ref.notifier(settingsProvider).setDestination(directory);
              }
            },
            child: Text(
              vm.settings.destination ?? t.settingsTab.receive.downloads,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ),
      SettingsRow(
        id: 'receive.quickSave',
        label: t.settingsTab.receive.quickSave,
        kind: SettingsRowKind.stacked,
        value: _quickSaveLabel(vm.settings),
        on: vm.settings.quickSave || vm.settings.quickSaveFromFavorites,
        child: LsSegmented(
          options: [
            t.settingsPage.quickSaveOff,
            t.settingsPage.quickSaveFavorites,
            t.settingsPage.quickSaveAll,
          ],
          index: vm.settings.quickSave ? 2 : (vm.settings.quickSaveFromFavorites ? 1 : 0),
          onChanged: (index) async {
            final wasQuickSave = vm.settings.quickSave;
            final wasFavorites = vm.settings.quickSaveFromFavorites;
            await ref.notifier(settingsProvider).setQuickSave(index == 2);
            await ref.notifier(settingsProvider).setQuickSaveFromFavorites(index == 1);
            if (!context.mounted) {
              return;
            }
            if (index == 2 && !wasQuickSave) {
              await QuickSaveNotice.open(context);
            } else if (index == 1 && !wasFavorites) {
              await QuickSaveFromFavoritesNotice.open(context);
            }
          },
        ),
      ),
      SettingsRow(
        id: 'receive.pin',
        label: t.settingsTab.receive.requirePin,
        kind: SettingsRowKind.trailing,
        on: vm.settings.receivePin != null,
        child: LsSwitch(
          value: vm.settings.receivePin != null,
          label: t.settingsTab.receive.requirePin,
          onChanged: (value) async {
            final currentPin = vm.settings.receivePin;
            if (currentPin != null) {
              await ref.notifier(settingsProvider).setReceivePin(null);
            } else {
              final String? newPin = await showDialog<String>(
                context: context,
                builder: (_) => const PinDialog(obscureText: false, generateRandom: false),
              );
              if (newPin != null && newPin.isNotEmpty) {
                await ref.notifier(settingsProvider).setReceivePin(newPin);
              }
            }
            if (ref.read(serverProvider) != null) {
              await ref.notifier(serverProvider).restartServerFromSettings();
            }
          },
        ),
      ),
      if (checkPlatformWithGallery())
        SettingsRow(
          id: 'receive.gallery',
          label: t.settingsTab.receive.saveToGallery,
          kind: SettingsRowKind.trailing,
          on: vm.settings.saveToGallery,
          child: LsSwitch(
            value: vm.settings.saveToGallery,
            label: t.settingsTab.receive.saveToGallery,
            onChanged: (value) async {
              await ref.notifier(settingsProvider).setSaveToGallery(value);
            },
          ),
        ),
      SettingsRow(
        id: 'receive.autoFinish',
        label: t.settingsTab.receive.autoFinish,
        kind: SettingsRowKind.trailing,
        on: vm.settings.autoFinish,
        child: LsSwitch(
          value: vm.settings.autoFinish,
          label: t.settingsTab.receive.autoFinish,
          onChanged: (value) async {
            await ref.notifier(settingsProvider).setAutoFinish(value);
          },
        ),
      ),
      SettingsRow(
        id: 'receive.history',
        label: t.settingsTab.receive.saveToHistory,
        kind: SettingsRowKind.trailing,
        on: vm.settings.saveToHistory,
        child: LsSwitch(
          value: vm.settings.saveToHistory,
          label: t.settingsTab.receive.saveToHistory,
          onChanged: (value) async {
            await ref.notifier(settingsProvider).setSaveToHistory(value);
          },
        ),
      ),
      SettingsRow(
        id: 'receive.verifyChecksums',
        label: t.settingsTab.receive.verifyChecksums,
        kind: SettingsRowKind.trailing,
        on: vm.settings.verifyChecksums,
        child: LsSwitch(
          value: vm.settings.verifyChecksums,
          label: t.settingsTab.receive.verifyChecksums,
          onChanged: (value) async {
            await ref.notifier(settingsProvider).setVerifyChecksums(value);
            if (ref.read(serverProvider) != null) {
              await ref.notifier(serverProvider).restartServerFromSettings();
            }
          },
        ),
      ),
    ];
  },
  tags: (context, vm) => [
    SettingsTag(
      label: t.general.quickSave,
      on: vm.settings.quickSave || vm.settings.quickSaveFromFavorites,
    ),
  ],
);

// ----------------------------------------------------------------- security

SettingsSection _securitySection() => SettingsSection(
  id: SettingsSectionId.security,
  title: t.settingsPage.groupSecuritySection,
  icon: LucideIcons.shield,
  rows: (context, vm) {
    final ref = context.ref;
    return [
      SettingsRow(
        id: 'security.encryption',
        label: t.settingsTab.network.encryption,
        kind: SettingsRowKind.trailing,
        on: vm.settings.https,
        child: LsSwitch(
          value: vm.settings.https,
          label: t.settingsTab.network.encryption,
          onChanged: (value) async {
            final old = vm.settings.https;
            await ref.notifier(settingsProvider).setHttps(value);
            if (old && !value && context.mounted) {
              await EncryptionDisabledNotice.open(context);
            }
          },
        ),
      ),
      ..._restartHint(context, vm, ServerSetting.https),
      SettingsRow(
        id: 'security.shareViaLink',
        label: t.settingsTab.send.shareViaLinkAutoAccept,
        kind: SettingsRowKind.trailing,
        on: vm.settings.shareViaLinkAutoAccept,
        child: LsSwitch(
          value: vm.settings.shareViaLinkAutoAccept,
          label: t.settingsTab.send.shareViaLinkAutoAccept,
          onChanged: (value) async {
            await ref.notifier(settingsProvider).setShareViaLinkAutoAccept(value);
          },
        ),
      ),
      SettingsRow(
        id: 'security.createChecksums',
        label: t.settingsTab.send.createChecksums,
        kind: SettingsRowKind.trailing,
        on: vm.settings.createChecksums,
        child: LsSwitch(
          value: vm.settings.createChecksums,
          label: t.settingsTab.send.createChecksums,
          onChanged: (value) async {
            await ref.notifier(settingsProvider).setCreateChecksums(value);
          },
        ),
      ),
    ];
  },
  tags: (context, vm) => [
    SettingsTag(label: t.settingsTab.network.encryption, on: vm.settings.https),
    SettingsTag(label: t.settingsPage.checksums, on: vm.settings.createChecksums),
  ],
);

// --------------------------------------------------------------- appearance

SettingsSection _appearanceSection() => SettingsSection(
  id: SettingsSectionId.appearance,
  title: t.settingsPage.groupAppearanceSection,
  icon: LucideIcons.palette,
  rows: (context, vm) {
    final ref = context.ref;
    return [
      SettingsRow(
        id: 'appearance.theme',
        label: t.settingsTab.general.brightness,
        kind: SettingsRowKind.stacked,
        value: _themeLabel(vm.settings.theme),
        child: LsSegmented(
          options: [
            t.settingsTab.general.brightnessOptions.system,
            t.settingsTab.general.brightnessOptions.light,
            t.settingsTab.general.brightnessOptions.dark,
          ],
          index: switch (vm.settings.theme) {
            ThemeMode.system => 0,
            ThemeMode.light => 1,
            ThemeMode.dark => 2,
          },
          onChanged: (index) async {
            final theme = [ThemeMode.system, ThemeMode.light, ThemeMode.dark][index];
            vm.onChangeTheme(context, theme);
          },
        ),
      ),
      SettingsRow(
        id: 'appearance.color',
        label: t.settingsTab.general.color,
        kind: SettingsRowKind.stacked,
        value: vm.settings.colorMode == ColorMode.custom ? t.settingsPage.accentColor : vm.settings.colorMode.humanName,
        child: CustomDropdownButton<ColorMode>(
          // Custom colors are picked with the accent swatches below, so they are
          // not an option here. While that mode is active the dropdown shows the
          // "accent color" hint instead of a (missing) selected item.
          value: vm.settings.colorMode == ColorMode.custom ? null : vm.settings.colorMode,
          hint: Text(t.settingsPage.accentColor, overflow: TextOverflow.ellipsis),
          items: [
            for (final colorMode in vm.colorModes.where((mode) => mode != ColorMode.custom))
              DropdownMenuItem(
                value: colorMode,
                alignment: Alignment.center,
                child: Text(colorMode.humanName, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (colorMode) async {
            vm.onChangeColorMode(context, colorMode);
          },
        ),
      ),
      SettingsRow(
        id: 'appearance.accent',
        label: t.settingsPage.accentColor,
        kind: SettingsRowKind.stacked,
        child: _AccentSwatches(
          selected: vm.settings.colorMode == ColorMode.custom ? vm.settings.customColor : null,
          onSelected: (color) async {
            // Picking a swatch is the whole custom-color flow; it must not open
            // the free-form color dialog on top of it.
            await ref.notifier(settingsProvider).setColorMode(ColorMode.custom);
            await ref.notifier(settingsProvider).setCustomColor(color);
          },
        ),
      ),
      SettingsRow(
        id: 'appearance.layout',
        label: t.settingsPage.nearbyLayout,
        kind: SettingsRowKind.stacked,
        value: vm.settings.nearbyLayout == NearbyLayout.radar ? t.settingsPage.nearbyLayoutRadar : t.settingsPage.nearbyLayoutGrid,
        child: LsSegmented(
          options: [t.settingsPage.nearbyLayoutGrid, t.settingsPage.nearbyLayoutRadar],
          index: vm.settings.nearbyLayout == NearbyLayout.radar ? 1 : 0,
          onChanged: (index) async {
            await ref.notifier(settingsProvider).setNearbyLayout(index == 0 ? NearbyLayout.grid : NearbyLayout.radar);
          },
        ),
      ),
      SettingsRow(
        id: 'appearance.language',
        label: t.settingsTab.general.language,
        kind: SettingsRowKind.trailing,
        value: vm.settings.locale?.getLocaleName() ?? t.settingsTab.general.languageOptions.system,
        child: TextButton(
          onPressed: () async => vm.onTapLanguage(context),
          child: Text(
            vm.settings.locale?.getLocaleName() ?? t.settingsTab.general.languageOptions.system,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ),
      SettingsRow(
        id: 'appearance.animations',
        label: t.settingsTab.general.animations,
        kind: SettingsRowKind.trailing,
        on: vm.settings.enableAnimations,
        child: LsSwitch(
          value: vm.settings.enableAnimations,
          label: t.settingsTab.general.animations,
          onChanged: (value) async {
            await ref.notifier(settingsProvider).setEnableAnimations(value);
          },
        ),
      ),
    ];
  },
  tags: (context, vm) => const [],
);

// ------------------------------------------------------------------ network

SettingsSection _networkSection() => SettingsSection(
  id: SettingsSectionId.network,
  title: t.settingsPage.groupNetworkSection,
  icon: LucideIcons.server,
  rows: (context, vm) {
    final ref = context.ref;
    final filtered = vm.settings.networkWhitelist != null || vm.settings.networkBlacklist != null;
    return [
      SettingsRow(
        id: 'network.server',
        label: t.settingsTab.network.server,
        description: vm.serverState == null ? t.general.offline : null,
        kind: SettingsRowKind.trailing,
        on: vm.serverState != null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LsIconButton(
              icon: vm.serverState == null ? LucideIcons.play : LucideIcons.refreshCw,
              tooltip: vm.serverState == null ? t.general.start : t.general.restart,
              onPressed: () async {
                if (vm.serverState == null) {
                  vm.onTapStartServer(context);
                } else {
                  vm.onTapRestartServer(context);
                }
              },
            ),
            LsIconButton(
              icon: LucideIcons.square,
              tooltip: t.general.stop,
              onPressed: vm.serverState == null ? null : () async => vm.onTapStopServer(),
            ),
          ],
        ),
      ),
      SettingsRow(
        id: 'network.port',
        label: t.settingsTab.network.port,
        description: vm.settings.port != defaultPort ? t.settingsTab.network.portWarning(defaultPort: defaultPort) : null,
        kind: SettingsRowKind.stacked,
        value: vm.settings.port.toString(),
        child: TextFieldTv(
          name: t.settingsTab.network.port,
          controller: vm.portController,
          onChanged: (value) async {
            final port = int.tryParse(value);
            if (port != null) {
              await ref.notifier(settingsProvider).setPort(port);
            }
          },
        ),
      ),
      ..._restartHint(context, vm, ServerSetting.port),
      SettingsRow(
        id: 'network.multicast',
        label: t.settingsTab.network.multicastGroup,
        description: vm.settings.multicastGroup != defaultMulticastGroup
            ? t.settingsTab.network.multicastGroupWarning(defaultMulticast: defaultMulticastGroup)
            : null,
        kind: SettingsRowKind.stacked,
        value: vm.settings.multicastGroup,
        child: TextFieldTv(
          name: t.settingsTab.network.multicastGroup,
          controller: vm.multicastController,
          onChanged: (value) async {
            await ref.notifier(settingsProvider).setMulticastGroup(value);
          },
        ),
      ),
      ..._restartHint(context, vm, ServerSetting.multicastGroup),
      SettingsRow(
        id: 'network.timeout',
        label: t.settingsTab.network.discoveryTimeout,
        kind: SettingsRowKind.stacked,
        value: vm.settings.discoveryTimeout.toString(),
        child: TextFieldTv(
          name: t.settingsTab.network.discoveryTimeout,
          controller: vm.timeoutController,
          onChanged: (value) async {
            final timeout = int.tryParse(value);
            if (timeout != null) {
              await ref.notifier(settingsProvider).setDiscoveryTimeout(timeout);
            }
          },
        ),
      ),
      ..._restartHint(context, vm, ServerSetting.discoveryTimeout),
      SettingsRow(
        id: 'network.interfaces',
        label: t.settingsTab.network.network,
        kind: SettingsRowKind.trailing,
        value: filtered ? t.settingsTab.network.networkOptions.filtered : t.settingsTab.network.networkOptions.all,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LsChip.text(filtered ? t.settingsTab.network.networkOptions.filtered : t.settingsTab.network.networkOptions.all),
            const SizedBox(width: 6),
            LsIconButton(
              icon: LucideIcons.chevronRight,
              tooltip: t.settingsTab.network.network,
              onPressed: () async => context.push(() => const NetworkInterfacesPage()),
            ),
          ],
        ),
      ),
      ..._restartHint(context, vm, ServerSetting.networkInterfaces),
      SettingsRow(
        id: 'network.debug',
        label: t.settingsPage.debug,
        kind: SettingsRowKind.trailing,
        child: LsIconButton(
          icon: LucideIcons.chevronRight,
          tooltip: t.settingsPage.debug,
          onPressed: () async => context.push(() => const DebugPage()),
        ),
      ),
    ];
  },
  tags: (context, vm) => [
    SettingsTag(label: vm.serverState == null ? t.general.offline : t.general.online, on: vm.serverState != null),
  ],
);

// ------------------------------------------------------------------ desktop

SettingsSection _desktopSection() => SettingsSection(
  id: SettingsSectionId.desktop,
  title: t.settingsPage.groupDesktopSection,
  icon: LucideIcons.monitor,
  desktopOnly: true,
  rows: (context, vm) {
    final ref = context.ref;
    return [
      if (checkPlatformIsDesktop())
        SettingsRow(
          id: 'desktop.alwaysOnTop',
          label: t.settingsTab.general.alwaysOnTop,
          description: checkPlatformIsNotWaylandDesktop() ? null : t.settingsTab.general.alwaysOnTopUnavailable,
          kind: SettingsRowKind.trailing,
          on: checkPlatformIsNotWaylandDesktop() && vm.settings.alwaysOnTop,
          child: LsSwitch(
            value: checkPlatformIsNotWaylandDesktop() && vm.settings.alwaysOnTop,
            label: t.settingsTab.general.alwaysOnTop,
            onChanged: checkPlatformIsNotWaylandDesktop()
                ? (value) async {
                    await ref.notifier(settingsProvider).setAlwaysOnTop(value);
                  }
                : null,
          ),
        ),
      if (checkPlatformIsDesktop() && checkPlatformIsNotWaylandDesktop())
        SettingsRow(
          id: 'desktop.windowPlacement',
          label: defaultTargetPlatform == TargetPlatform.windows
              ? t.settingsTab.general.saveWindowPlacementWindows
              : t.settingsTab.general.saveWindowPlacement,
          kind: SettingsRowKind.trailing,
          on: vm.settings.saveWindowPlacement,
          child: LsSwitch(
            value: vm.settings.saveWindowPlacement,
            label: t.settingsTab.general.saveWindowPlacement,
            onChanged: (value) async {
              await ref.notifier(settingsProvider).setSaveWindowPlacement(value);
            },
          ),
        ),
      if (checkPlatformIsDesktop() && checkPlatformHasTray())
        SettingsRow(
          id: 'desktop.tray',
          label: t.settingsTab.general.minimizeToTray,
          kind: SettingsRowKind.trailing,
          on: vm.settings.minimizeToTray,
          child: LsSwitch(
            value: vm.settings.minimizeToTray,
            label: t.settingsTab.general.minimizeToTray,
            onChanged: (value) async {
              await ref.notifier(settingsProvider).setMinimizeToTray(value);
            },
          ),
        ),
      if (checkPlatformIsDesktop()) ...[
        SettingsRow(
          id: 'desktop.autostart',
          label: t.settingsTab.general.launchAtStartup,
          kind: SettingsRowKind.trailing,
          on: vm.autoStart,
          child: LsSwitch(
            value: vm.autoStart,
            label: t.settingsTab.general.launchAtStartup,
            onChanged: (_) async => vm.onToggleAutoStart(context),
          ),
        ),
        if (vm.autoStart)
          SettingsRow(
            id: 'desktop.autostartHidden',
            label: t.settingsTab.general.launchMinimized,
            kind: SettingsRowKind.trailing,
            on: vm.autoStartLaunchHidden,
            child: LsSwitch(
              value: vm.autoStartLaunchHidden,
              label: t.settingsTab.general.launchMinimized,
              onChanged: (_) async => vm.onToggleAutoStartLaunchHidden(context),
            ),
          ),
        if (checkPlatform([TargetPlatform.windows]))
          SettingsRow(
            id: 'desktop.contextMenu',
            label: t.settingsTab.general.showInContextMenu,
            kind: SettingsRowKind.trailing,
            on: vm.showInContextMenu,
            child: LsSwitch(
              value: vm.showInContextMenu,
              label: t.settingsTab.general.showInContextMenu,
              onChanged: (_) async => vm.onToggleShowInContextMenu(context),
            ),
          ),
      ],
    ];
  },
  tags: (context, vm) => const [],
);

// -------------------------------------------------------------------- helper

String _quickSaveLabel(SettingsState settings) {
  if (settings.quickSave) {
    return t.settingsPage.quickSaveAll;
  }
  if (settings.quickSaveFromFavorites) {
    return t.settingsPage.quickSaveFavorites;
  }
  return t.settingsPage.quickSaveOff;
}

/// Display name of a device type, e.g. `Desktop` (used in the segmented bar's
/// tooltip and in search results).
String _deviceTypeLabel(DeviceType type) => type.name[0].toUpperCase() + type.name.substring(1);

String _themeLabel(ThemeMode theme) {
  return switch (theme) {
    ThemeMode.system => t.settingsTab.general.brightnessOptions.system,
    ThemeMode.light => t.settingsTab.general.brightnessOptions.light,
    ThemeMode.dark => t.settingsTab.general.brightnessOptions.dark,
  };
}

extension on ColorMode {
  String get humanName {
    return switch (this) {
      ColorMode.system => t.settingsTab.general.colorOptions.system,
      ColorMode.localsend => t.appName,
      ColorMode.oled => t.settingsTab.general.colorOptions.oled,
      ColorMode.yaru => 'Yaru',
      ColorMode.custom => t.settingsTab.general.colorOptions.custom,
    };
  }
}

/// The five preset accents of the redesign; picking one switches the app to
/// `ColorMode.custom` with that seed color.
class _AccentSwatches extends StatelessWidget {
  static const presets = <Color>[
    Color(0xFFC6F24E),
    Color(0xFFFFB020),
    Color(0xFF7AA2FF),
    Color(0xFFF2695E),
    Color(0xFF8A8F98),
  ];

  final Color? selected;
  final ValueChanged<Color> onSelected;

  const _AccentSwatches({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    return Row(
      children: [
        for (final color in presets)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Semantics(
              button: true,
              label: '#${color.toARGB32().toRadixString(16).substring(2)}',
              child: InkWell(
                onTap: () => onSelected(color),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected == color ? tokens.colors.fg : tokens.colors.line,
                      width: selected == color ? 2 : 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------------------- components

/// The "current values" line of a section: plain mono bits and capsule tags.
class SettingsTagsLine extends StatelessWidget {
  final List<SettingsTag> tags;

  const SettingsTagsLine({required this.tags, super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [for (final tag in tags) LsStateTag(label: tag.label, on: tag.on)],
    );
  }
}

/// The hint shown right below a setting that the running server only reads when
/// it starts. Without it, such a change would silently do nothing.
List<SettingsRow> _restartHint(BuildContext context, SettingsTabVm vm, ServerSetting setting) {
  if (!vm.pendingRestart.contains(setting)) {
    return const [];
  }

  return [
    SettingsRow(
      id: 'network.restartHint.${setting.name}',
      label: t.settingsTab.network.needRestart,
      kind: SettingsRowKind.trailing,
      warning: true,
      child: LsButton(
        label: t.general.restart,
        icon: LucideIcons.refreshCw,
        variant: LsButtonVariant.plain,
        onPressed: () => vm.onTapRestartServer(context),
      ),
    ),
  ];
}

/// One settings row: label (+ helper text) and the control, with a temporary
/// accent wash when the row was reached from a search result.
class SettingsRowTile extends StatelessWidget {
  final SettingsRow row;
  final bool highlighted;

  const SettingsRowTile({required this.row, this.highlighted = false, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (row.warning) ...[
              Icon(LucideIcons.alertTriangle, size: 13, color: colors.danger),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(row.label, style: TextStyle(fontSize: 12.5, height: 1.3, color: row.warning ? colors.danger : colors.fg)),
            ),
          ],
        ),
        if (row.description != null) ...[
          const SizedBox(height: 2),
          Text(row.description!, style: tokens.bodySm),
        ],
      ],
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      color: highlighted ? colors.accentSoft : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: row.kind == SettingsRowKind.trailing
            ? Row(
                children: [
                  Expanded(child: label),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Align(alignment: AlignmentDirectional.centerEnd, child: row.child),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label,
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    // A stacked control (field, segmented, swatches) reads better
                    // when it does not stretch across a wide desktop pane.
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Align(alignment: AlignmentDirectional.centerStart, child: row.child),
                  ),
                ],
              ),
      ),
    );
  }
}
