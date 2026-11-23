import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/persistence/favorite_device.dart';
import 'package:sonar/pages/device_details_page.dart';
import 'package:sonar/pages/tabs/nearby/file_grid.dart';
import 'package:sonar/pages/tabs/nearby/nearby_filter_chips.dart';
import 'package:sonar/pages/tabs/nearby/nearby_ui.dart';
import 'package:sonar/pages/tabs/nearby_tab_vm.dart';
import 'package:sonar/util/device_type_ext.dart';
import 'package:sonar/util/radar_layout.dart';
import 'package:sonar/util/ui/snackbar.dart';
import 'package:sonar/widget/ls/ls_chip.dart';
import 'package:sonar/widget/ls/ls_radar.dart';
import 'package:sonar_isolates/model/device.dart';
import 'package:sonar_isolates/util/file_size_helper.dart';

/// Diameter of the radar center bubble. The radar layout's file tray must not
/// grow past it, otherwise the pending files out-shout "me".
const double _radarSelfSize = 76;

/// The radar layout: peers orbiting the local device, with the pending-file tray underneath.
class NearbyRadarView {
  final NearbyTabVm vm;
  final NearbyUi _ui;
  final NearbyActions _actions;

  const NearbyRadarView({
    required this.vm,
    required NearbyUi ui,
    required NearbyActions actions,
  }) : _ui = ui,
       _actions = actions;

  /// The radar layout only renders in the stacked (non-desktop) path, so it never forces multi-select.
  bool get _multiActive => _ui.multiOverride ?? false;

  Widget _chip(String label, NearbyFilter value) => NearbyFilterChip(label: label, value: value, ui: _ui, actions: _actions);

  List<Widget> content(
    BuildContext context, {
    required bool animations,
    required List<Device> favoritesSection,
    required List<Device> onlineSection,
    required List<FavoriteDevice> offlineSection,
  }) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final files = vm.selectedFiles;
    final totalSize = files.fold<int>(0, (sum, file) => sum + file.size);

    final visibleOnline = [...favoritesSection, ...onlineSection];
    final radarOnline = visibleOnline.take(maxRadarOnlineDevices).toList();
    final radarOffline = offlineSection.isNotEmpty ? offlineSection.first : null;
    // Slot angles/sizes include the offline favorite, so a sixth device does not land on it.
    final slots = layoutRadarSlots(onlineCount: radarOnline.length, hasOffline: radarOffline != null);
    final shown = slots.length;
    final total = visibleOnline.length + offlineSection.length;
    final size = math.min(MediaQuery.sizeOf(context).width - 32, 344.0);

    return [
      Padding(
        padding: const EdgeInsets.only(top: 6),
        // Same row as the grid: the three filters on the left, the multi chip on the right
        // edge. The filters wrap instead of overflowing, because the four chips do not fit
        // a 320 px phone; the multi chip keeps its place at the end either way.
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(t.nearbyTab.filterAll, NearbyFilter.all),
                  _chip(t.nearbyTab.filterOnline, NearbyFilter.online),
                  _chip(t.nearbyTab.filterFavorites, NearbyFilter.favorites),
                ],
              ),
            ),
            const SizedBox(width: 8),
            LsChip.text(
              _multiActive ? t.nearbyTab.multiActive : t.nearbyTab.multi,
              accent: _multiActive,
              onTap: () => _actions.onToggleMulti(),
            ),
          ],
        ),
      ),
      // The radar's peer labels are drawn outside the ring bounds, so it needs
      // breathing room above and below instead of sitting flush against the
      // filter chips and the divider.
      Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 18),
        child: Center(
          child: LsRadar(
            size: size,
            animate: animations,
            center: _radarSelf(context),
            // The count the top line used to carry, folded into one fraction in the corner
            // of the radar square: how much of what the filters leave is actually drawn.
            corner: total == 0 ? null : Text('$shown/$total', style: tokens.monoSm.copyWith(color: colors.faint)),
            peers: [
              for (var i = 0; i < radarOnline.length; i++)
                LsRadarPeer(
                  child: Icon(radarOnline[i].deviceType.icon),
                  label: radarOnline[i].alias,
                  angle: slots[i].angle,
                  radius: slots[i].radius,
                  size: slots[i].size,
                  labelAbove: i.isOdd,
                  // Multi-select feedback: picked peers get the accent ring + wash.
                  selected: _ui.picked.contains(radarOnline[i].fingerprint),
                  tooltip: radarOnline[i].alias,
                  onTap: () async => _actions.onDeviceTap(radarOnline[i]),
                  // Same as the device grid: long press enters multi-select and
                  // preselects this device.
                  onLongPress: () async => _actions.onDeviceLongPress(radarOnline[i]),

                  // The bubble owns tap (send) and long press (multi-select), so the label
                  // is the only surface left for the details page. Inside multi-select it
                  // toggles the pick instead, exactly like the bubble.
                  onLabelTap: () async =>
                      _multiActive ? _actions.onDeviceTap(radarOnline[i]) : context.push(() => DeviceDetailsPage(device: radarOnline[i])),
                ),
              if (radarOffline != null)
                LsRadarPeer(
                  child: Icon(radarOffline.deviceType.icon),
                  label: radarOffline.alias,
                  angle: slots.last.angle,
                  radius: slots.last.radius,
                  size: slots.last.size,
                  offline: true,
                  labelAbove: true,
                  tooltip: '${radarOffline.alias}  ${t.nearbyTab.offline}',
                  onTap: () => context.showSnackBar(t.nearbyTab.offlineHint),
                ),
            ],
          ),
        ),
      ),
      if (total == 0)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            t.nearbyTab.noDevices,
            textAlign: TextAlign.center,
            style: tokens.mono.copyWith(color: colors.faint),
          ),
        ),
      const SizedBox(height: 4),
      Container(height: 1, color: colors.line),
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                t.nearbyTab.pending(files: files.length, size: totalSize.asReadableFileSize),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.eyebrow.copyWith(color: colors.muted),
              ),
            ),
            const SizedBox(width: 8),
            // Three chips do not fit beside the pending line on a 320 px phone: wrapping keeps
            // them on a second row instead of overflowing the edge.
            Flexible(
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (files.isNotEmpty) LsChip.text(t.nearbyTab.clear, onTap: () async => vm.onClearFiles(context)),
                  LsChip.text(t.nearbyTab.linkReceive, onTap: () async => vm.onOpenLink(context)),
                  LsChip.text(t.nearbyTab.manualIp, onTap: () async => vm.onManualIp(context)),
                ],
              ),
            ),
          ],
        ),
      ),
      // Radar mode keeps the pending-file squares at or below the center bubble.
      NearbyFileGrid(vm: vm, columns: 4, maxTileWidth: _radarSelfSize),
    ];
  }

  Widget _radarSelf(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final files = vm.selectedFiles;
    return Material(
      color: colors.accent,
      shape: const CircleBorder(),
      clipBehavior: Clip.none,
      child: InkWell(
        onTap: () async => vm.onAddFiles(context),
        customBorder: const CircleBorder(),
        child: Container(
          width: _radarSelfSize,
          height: _radarSelfSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: colors.accentSoft, spreadRadius: 10)],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(child: Icon(LucideIcons.smartphone, size: 24, color: colors.accentFg)),
              if (files.isNotEmpty)
                Positioned(
                  top: -5,
                  left: -5,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.fg,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [BoxShadow(color: colors.bg, spreadRadius: 3)],
                    ),
                    child: Text(
                      '${files.length}',
                      style: tokens.label.copyWith(fontWeight: FontWeight.w600, color: colors.bg),
                    ),
                  ),
                )
              else
                Positioned(
                  top: -5,
                  left: -5,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.bg2,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.lineStrong),
                    ),
                    child: Icon(LucideIcons.plus, size: 12, color: colors.accent),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
