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
import 'package:sonar/util/favorites.dart';
import 'package:sonar/util/ui/snackbar.dart';
import 'package:sonar/widget/ls/ls_chip.dart';
import 'package:sonar/widget/ls/ls_header.dart';
import 'package:sonar/widget/ls/ls_search_field.dart';
import 'package:sonar/widget/ls/ls_section_label.dart';
import 'package:sonar/widget/ls/ls_tile.dart';
import 'package:sonar_isolates/model/device.dart';
import 'package:sonar_isolates/util/file_size_helper.dart';

/// The stacked layout: pending files, search, filters, the device grid and the collapsible file tray.
class NearbyGridView {
  final NearbyTabVm vm;
  final NearbyUi _ui;
  final bool desktop;
  final NearbyActions _actions;

  const NearbyGridView({
    required this.vm,
    required NearbyUi ui,
    required this.desktop,
    required NearbyActions actions,
  }) : _ui = ui,
       _actions = actions;

  bool get _multiActive => desktop || (_ui.multiOverride ?? false);

  Widget _chip(String label, NearbyFilter value) => NearbyFilterChip(label: label, value: value, ui: _ui, actions: _actions);
  List<Widget> content(
    BuildContext context, {

    /// Whether the online card's dot may breathe while a scan runs (the reduced-motion setting).
    required bool animations,
    required List<Device> favoritesSection,
    required List<Device> onlineSection,
    required List<FavoriteDevice> offlineSection,
  }) {
    final tokens = context.ls;
    final files = vm.selectedFiles;
    final onlineCount = vm.devices.length;
    final totalCount = onlineCount + offlineFavoriteCount(vm);

    // Favorites that are online get a section of their own, so the remaining online devices need a
    // label that does not read like the "Online" filter chip sitting right above them.
    final splitFavorites = favoritesSection.isNotEmpty;

    // Only the favorites filter drops the online section; the offline section is then the first one
    // under the chip row, which already leaves 10px below it, so it must not add its own lead-in.
    final showsOnline = _ui.filter != NearbyFilter.favorites;
    final offlineFollowsSection = splitFavorites || showsOnline;

    return [
      _miniRadar(context, onlineCount: onlineCount, totalCount: totalCount, pulse: vm.scanning && animations),
      if (files.isEmpty)
        _addFilesBar(context)
      else if (_ui.filesOpen)
        Padding(padding: const EdgeInsets.only(top: 10), child: _inlineTray(context))
      else
        Padding(padding: const EdgeInsets.only(top: 10), child: _fileBar(context)),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: LsSearchField(
          controller: _actions.query,
          hint: t.nearbyTab.search,
          onChanged: (_) => _actions.onQueryChanged(),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Same row as the radar: the three filters on the left, the multi chip on the
            // right edge. The filters wrap instead of overflowing, because the four chips
            // do not fit a 320 px phone; the multi chip keeps its place at the end either way.
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
      if (splitFavorites) ...[
        LsSectionLabel(label: t.nearbyTab.favorites, count: '${favoritesSection.length}', padding: const EdgeInsets.only(bottom: 8)),
        _deviceGrid(context, favoritesSection),
      ],
      if (showsOnline) ...[
        LsSectionLabel(
          label: splitFavorites ? t.nearbyTab.onlineSectionOthers : t.nearbyTab.onlineSection,
          count: '${onlineSection.length}',
          // The chip row already leaves 10px below it; only a section that follows another one
          // needs the extra lead-in. Otherwise switching filters visibly moves the hairline.
          padding: EdgeInsets.only(top: splitFavorites ? 14 : 0, bottom: 8),
        ),
        if (onlineSection.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(t.nearbyTab.noOnlineMatch, style: tokens.bodySm),
          )
        else
          _deviceGrid(context, onlineSection),
      ],
      if (offlineSection.isNotEmpty) ...[
        LsSectionLabel(
          label: t.nearbyTab.offlineSection,
          count: '${offlineSection.length}',
          padding: EdgeInsets.only(top: offlineFollowsSection ? 14 : 0, bottom: 8),
        ),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            // Same cell as the device grid, grown with the system font (see [deviceTileHeight]).
            mainAxisExtent: deviceTileHeight(context),
          ),
          itemCount: offlineSection.length,
          itemBuilder: (context, index) => _OfflineFavoriteTile(
            favorite: offlineSection[index],
            onRemove: () async => await vm.onToggleFavoriteOffline(offlineSection[index]),
          ),
        ),
      ],
      if (vm.devices.isEmpty && vm.favoriteDevices.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Text(t.nearbyTab.noDevices, style: tokens.bodySm),
        ),
    ];
  }

  /// [pulse] keeps the dot breathing while a scan runs: the count above already ticks up as devices
  /// arrive, so an empty network needs something that still moves.
  Widget _miniRadar(BuildContext context, {required int onlineCount, required int totalCount, required bool pulse}) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: tokens.tileRadius,
        border: Border.all(color: colors.line),
        gradient: LinearGradient(
          colors: [colors.accentSoft, colors.accent.withValues(alpha: 0)],
          stops: const [0, 0.7],
        ),
      ),
      child: Row(
        children: [
          LsStatusDot(on: onlineCount > 0, pulse: pulse),
          const SizedBox(width: 8),
          Text(
            '$onlineCount',
            style: tokens.bodyStrong.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              // The bold count already shows the online number, so the label only carries the total.
              t.nearbyTab.onlineSuffix(total: totalCount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.label,
            ),
          ),
          const SizedBox(width: 6),
          LsChip.text(t.nearbyTab.linkReceive, onTap: () async => vm.onOpenLink(context)),
          const SizedBox(width: 6),
          LsChip.text(t.nearbyTab.manualIp, onTap: () async => vm.onManualIp(context)),
        ],
      ),
    );
  }

  Widget _deviceGrid(BuildContext context, List<Device> devices) {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        // The tile grows with the system font instead of overflowing its cell (see [deviceTileHeight]).
        mainAxisExtent: deviceTileHeight(context),
      ),
      itemCount: devices.length,
      itemBuilder: (context, index) => _deviceTile(context, devices[index]),
    );
  }

  Widget _deviceTile(BuildContext context, Device device) {
    final favorite = vm.favoriteDevices.containsDevice(device);
    final info = [
      if (device.transmissionMethods.isNotEmpty) device.transmissionMethods.first.label,
      // Measured on the register request that confirmed the device.
      if (device.rttMs != null) '${device.rttMs} ms',
      if (device.deviceModel != null) device.deviceModel!,
    ].join('  ');

    return LsDeviceTile(
      glyph: Icon(device.deviceType.icon),
      name: device.alias,
      meta: info.isEmpty ? (device.ip ?? '') : '$info  ${device.ip ?? ''}',
      selected: _ui.picked.contains(device.fingerprint),
      favorite: favorite,
      multi: _multiActive && !desktop,
      showFavoriteButton: desktop || !_multiActive,
      onTap: () async => _actions.onDeviceTap(device),
      onLongPress: () async => _actions.onDeviceLongPress(device),
      onFavorite: () async => _actions.onToggleFavorite(device),
      onDetails: () async => context.push(() => DeviceDetailsPage(device: device)),
    );
  }

  Widget _addFilesBar(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: tokens.tileRadius,
          side: BorderSide(color: colors.lineStrong, width: tokens.hairlineOf(context)),
        ),
        child: InkWell(
          onTap: () async => vm.onAddFiles(context),
          borderRadius: tokens.tileRadius,
          hoverColor: colors.accentSoft,
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.plus, size: 16, color: colors.accent),
                const SizedBox(width: 6),
                Text(
                  t.nearbyTab.addFile,
                  style: tokens.bodySm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fileBar(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final files = vm.selectedFiles;
    final totalSize = files.fold<int>(0, (sum, file) => sum + file.size);
    return Material(
      color: colors.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: tokens.tileRadius,
        side: BorderSide(color: colors.lineStrong, width: tokens.hairlineOf(context)),
      ),
      child: InkWell(
        onTap: () => _actions.onFilesOpenChanged(true),
        borderRadius: tokens.tileRadius,
        hoverColor: colors.bg3,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(LucideIcons.inbox, size: 15, color: colors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.nearbyTab.pending(files: files.length, size: totalSize.asReadableFileSize),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.bodySm.copyWith(color: colors.fg),
                ),
              ),
              Text(t.nearbyTab.expand, style: tokens.monoSm.copyWith(color: colors.faint)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inlineTray(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final files = vm.selectedFiles;
    final totalSize = files.fold<int>(0, (sum, file) => sum + file.size);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colors.bg2,
        borderRadius: tokens.cardRadius,
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.nearbyTab.pending(files: files.length, size: totalSize.asReadableFileSize),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.eyebrow.copyWith(color: colors.muted),
                ),
              ),
              LsChip.text(t.nearbyTab.clear, onTap: () async => vm.onClearFiles(context)),
              const SizedBox(width: 6),
              LsChip.text(t.nearbyTab.collapse, onTap: () => _actions.onFilesOpenChanged(false)),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: colors.line),
          const SizedBox(height: 8),
          NearbyFileGrid(vm: vm, columns: 4),
        ],
      ),
    );
  }
}

/// An offline favorite is the same cell as an online device, so it reuses
/// [LsDeviceTile]: only the glyph, the meta line and the missing details action
/// differ (the tile itself dims the cell and announces it as offline). The glyph is the device
/// type remembered in the favorite, because an offline peer no longer announces itself.
///
/// A widget rather than a builder helper because [offlineLabel] watches the
/// last-seen provider, which Refena only allows inside a build method.
class _OfflineFavoriteTile extends StatelessWidget {
  final FavoriteDevice favorite;
  final Future<void> Function() onRemove;

  const _OfflineFavoriteTile({required this.favorite, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return LsDeviceTile(
      glyph: Icon(favorite.deviceType.icon),
      name: favorite.alias,
      meta: offlineLabel(context, favorite),
      offline: true,
      // Still a favorite, and the only action left: tapping the star forgets it.
      favorite: true,
      onTap: () => context.showSnackBar(t.nearbyTab.offlineHint),
      onFavorite: onRemove,
    );
  }
}
