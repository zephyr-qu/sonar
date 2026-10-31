import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/favorite_device.dart';
import 'package:localsend_app/pages/device_details_page.dart';
import 'package:localsend_app/pages/tabs/nearby/nearby_ui.dart';
import 'package:localsend_app/pages/tabs/nearby_tab_vm.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/ui/snackbar.dart';
import 'package:localsend_app/widget/desktop_tray.dart';
import 'package:localsend_app/widget/ls/ls_buttons.dart';
import 'package:localsend_app/widget/ls/ls_section_label.dart';
import 'package:localsend_app/widget/ls/ls_tile.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:routerino/routerino.dart';

/// The desktop shell's three columns (favorites / online / offline) plus the picked-devices aside.
class NearbyDesktopView {
  final NearbyTabVm vm;
  final NearbyUi _ui;
  final NearbyActions _actions;

  const NearbyDesktopView({
    required this.vm,
    required NearbyUi ui,
    required NearbyActions actions,
  }) : _ui = ui,
       _actions = actions;
  List<Widget> content(
    BuildContext context,
    List<Device> favoritesSection,
    List<Device> onlineSection,
    List<FavoriteDevice> offlineSection,
  ) {
    final tokens = context.ls;
    final devices = [...favoritesSection, ...onlineSection];

    return [
      Text(t.sendTab.nearbyDevices, style: tokens.pageTitle),
      const SizedBox(height: 6),
      Text(
        t.nearbyTab.desktopLede(online: devices.length),
        style: tokens.bodySm,
      ),
      const SizedBox(height: 16),
      if (devices.isEmpty)
        Text(t.nearbyTab.noDevices, style: tokens.bodySm)
      else
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = math.max(1, (constraints.maxWidth / 240).floor());
            return GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 136,
              ),
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return LsDeviceCard(
                  glyph: Icon(device.deviceType.icon),
                  name: device.alias,
                  meta: [
                    ...device.transmissionMethods.map((method) => method.label),
                    if (device.rttMs != null) '${device.rttMs} ms',
                  ].join(' · '),
                  metaSecondary: device.ip ?? '',
                  selected: _ui.picked.contains(device.fingerprint),
                  favorite: vm.favoriteDevices.containsDevice(device),
                  onTap: () async => _actions.onDeviceTap(device),
                  onFavorite: () async => _actions.onToggleFavorite(device),
                  onDetails: () async => context.push(() => DeviceDetailsPage(device: device)),
                );
              },
            );
          },
        ),
      if (offlineSection.isNotEmpty) ...[
        LsSectionLabel(label: t.nearbyTab.offlineSection, count: '${offlineSection.length}'),
        for (final favorite in offlineSection)
          LsLinkRow(
            label: favorite.alias,
            value: offlineLabel(context, favorite),
            showTopBorder: false,
            onTap: () => context.showSnackBar(t.nearbyTab.offlineHint),
          ),
      ],
      const SizedBox(height: 18),
      Row(
        children: [
          LsButton(
            label: t.nearbyTab.manualIp,
            icon: LucideIcons.mapPin,
            variant: LsButtonVariant.ghost,
            onPressed: () async => vm.onManualIp(context),
          ),
          const SizedBox(width: 10),
          LsButton(
            label: t.nearbyTab.linkReceive,
            icon: LucideIcons.link,
            variant: LsButtonVariant.ghost,
            onPressed: () async => vm.onOpenLink(context),
          ),
        ],
      ),
    ];
  }

  Widget aside(BuildContext context) {
    final picked = vm.devices.where((device) => _ui.picked.contains(device.fingerprint)).toList();
    return LsDesktopTray(
      showSend: true,
      picked: picked,
      onSend: vm.onSendToMany,
      onSent: _actions.onPickedCleared,
    );
  }
}
