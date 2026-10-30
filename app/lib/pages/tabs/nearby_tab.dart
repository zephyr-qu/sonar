import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/model/persistence/favorite_device.dart';
import 'package:localsend_app/model/persistence/nearby_layout.dart';
import 'package:localsend_app/model/state/send/send_session_state.dart';
import 'package:localsend_app/pages/device_details_page.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/selected_files_page.dart';
import 'package:localsend_app/pages/settings_page.dart';
import 'package:localsend_app/pages/tabs/nearby_tab_vm.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/provider/device_last_seen_provider.dart';
import 'package:localsend_app/provider/file_transfer_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/radar_layout.dart';
import 'package:localsend_app/util/ui/relative_time.dart';
import 'package:localsend_app/util/ui/snackbar.dart';
import 'package:localsend_app/widget/desktop_scaffold.dart';
import 'package:localsend_app/widget/dialogs/quick_save_notice.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:localsend_app/widget/ls/ls_buttons.dart';
import 'package:localsend_app/widget/ls/ls_chip.dart';
import 'package:localsend_app/widget/ls/ls_header.dart';
import 'package:localsend_app/widget/ls/ls_progress_bar.dart';
import 'package:localsend_app/widget/ls/ls_radar.dart';
import 'package:localsend_app/widget/ls/ls_search_field.dart';
import 'package:localsend_app/widget/ls/ls_section_label.dart';
import 'package:localsend_app/widget/ls/ls_switch.dart';
import 'package:localsend_app/widget/ls/ls_tile.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:localsend_isolates/util/file_size_helper.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

enum _NearbyFilter { all, online, favorites }

/// Diameter of the radar center bubble. The radar layout's file tray must not
/// grow past it, otherwise the pending files out-shout "me".
const double _radarSelfSize = 76;

/// The "Nearby" tab of the redesign: signal header, pending files, device grid
/// or radar layout depending on the persisted [NearbyLayout].
class NearbyTab extends StatelessWidget {
  /// Whether the desktop shell layout (rail + content + aside) is used.
  final bool desktop;

  const NearbyTab({this.desktop = false});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      provider: (ref) => nearbyTabVmProvider,
      init: (context) async => context.global.dispatchAsync(NearbyTabInitAction()),
      builder: (context, vm) => _NearbyView(vm: vm, desktop: desktop),
    );
  }
}

class _NearbyView extends StatefulWidget {
  final NearbyTabVm vm;
  final bool desktop;

  const _NearbyView({required this.vm, required this.desktop});

  @override
  State<_NearbyView> createState() => _NearbyViewState();
}

class _NearbyViewState extends State<_NearbyView> {
  final TextEditingController _query = TextEditingController();
  final Set<String> _picked = {};
  _NearbyFilter _filter = _NearbyFilter.all;

  /// `null` follows the persisted send mode; a value overrides it for this session.
  bool? _multiOverride;
  bool _filesOpen = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  NearbyTabVm get vm => widget.vm;

  bool get _multiActive {
    if (widget.desktop) {
      return true;
    }
    return _multiOverride ?? false;
  }

  /// Favorites that are saved but not currently discovered.
  int get _offlineFavoriteCount {
    return vm.favoriteDevices.where((favorite) => !vm.devices.any((device) => device.fingerprint == favorite.fingerprint)).length;
  }

  void _toggleMulti({String? preselect}) {
    final active = _multiActive;
    setState(() {
      _multiOverride = !active;
      if (active) {
        _picked.clear();
      } else if (preselect != null) {
        _picked.add(preselect);
      }
      _filesOpen = false;
    });
  }

  Future<void> _onDeviceTap(Device device) async {
    if (_multiActive) {
      setState(() {
        if (!_picked.remove(device.fingerprint)) {
          _picked.add(device.fingerprint);
        }
      });
      return;
    }
    await vm.onTapDevice(context, device);
  }

  Future<void> _onDeviceLongPress(Device device) async {
    await HapticFeedback.mediumImpact();
    if (_multiActive) {
      setState(() {
        if (!_picked.remove(device.fingerprint)) {
          _picked.add(device.fingerprint);
        }
      });
      return;
    }
    _toggleMulti(preselect: device.fingerprint);
    if (mounted) {
      context.showSnackBar(t.nearbyTab.selected(n: _picked.length));
    }
  }

  Future<void> _onToggleFavorite(Device device) async {
    final nowFavorite = await vm.onToggleFavorite(device);
    if (mounted) {
      context.showSnackBar(nowFavorite ? t.nearbyTab.favorited : t.nearbyTab.unfavorited);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final layout = context.watch(settingsProvider.select((settings) => settings.nearbyLayout));
    final animations = context.watch(animationProvider);

    final query = _query.text.trim().toLowerCase();
    bool matchesAlias(String alias, String? ip) {
      if (query.isEmpty) {
        return true;
      }
      return alias.toLowerCase().contains(query) || (ip ?? '').toLowerCase().contains(query);
    }

    final favoriteDevices = vm.devices.where((device) => vm.favoriteDevices.containsDevice(device)).toList()..sort(_byAlias);
    final onlineDevices = vm.devices.where((device) => !vm.favoriteDevices.containsDevice(device)).toList()..sort(_byAlias);
    final offlineFavorites = vm.favoriteDevices.where((favorite) {
      final discovered = vm.devices.any((device) => device.fingerprint == favorite.fingerprint);
      return !discovered && matchesAlias(favorite.alias, favorite.ip);
    }).toList();

    bool matches(Device device) => matchesAlias(device.alias, device.ip);
    final favoritesSection = _filter == _NearbyFilter.online ? <Device>[] : favoriteDevices.where(matches).toList();
    final onlineSection = _filter == _NearbyFilter.favorites
        ? <Device>[]
        : (_filter == _NearbyFilter.online
              ? [...favoriteDevices.where(matches), ...onlineDevices.where(matches)]
              : onlineDevices.where(matches).toList());
    final offlineSection = _filter == _NearbyFilter.online ? <FavoriteDevice>[] : offlineFavorites;

    if (widget.desktop) {
      return Column(
        children: [
          _desktopHeader(context),
          Expanded(
            child: LsDesktopLayout(
              content: ListView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
                children: _desktopContent(context, favoritesSection, onlineSection, offlineSection),
              ),
              aside: _desktopAside(context),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _header(context),
        Expanded(
          child: Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(tokens.pad, 0, tokens.pad, _multiActive ? 120 : 18),
                children: layout == NearbyLayout.radar
                    ? _radarContent(
                        context,
                        animations: animations,
                        favoritesSection: favoritesSection,
                        onlineSection: onlineSection,
                        offlineSection: offlineSection,
                      )
                    : _gridContent(
                        context,
                        favoritesSection: favoritesSection,
                        onlineSection: onlineSection,
                        offlineSection: offlineSection,
                      ),
              ),
              if (_multiActive)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: _multiBar(context),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    final tokens = context.ls;
    final ip = vm.localIps.isNotEmpty ? vm.localIps.first : t.general.unknown;
    return LsScreenHeader(
      mark: const Icon(LucideIcons.radar),
      title: vm.alias,
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LsStatusDot(on: vm.visible),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '${vm.visible ? t.nearbyTab.visible : t.nearbyTab.hidden} · $ip',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.mono,
            ),
          ),
        ],
      ),
      actions: [
        LsIconButton(
          icon: vm.visible ? LucideIcons.eye : LucideIcons.eyeOff,
          tooltip: vm.visible ? t.nearbyTab.hide : t.nearbyTab.show,
          active: vm.visible,
          onPressed: () async => vm.onToggleVisibility(context),
        ),
        LsIconButton(
          icon: LucideIcons.slidersHorizontal,
          tooltip: t.settingsTab.title,
          onPressed: () async => context.push(() => const SettingsPage()),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- grid layout

  // ------------------------------------------------------------- desktop shell

  Widget _desktopHeader(BuildContext context) => const LsDesktopDeviceHeader();

  List<Widget> _desktopContent(
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
                  selected: _picked.contains(device.fingerprint),
                  favorite: vm.favoriteDevices.containsDevice(device),
                  onTap: () async => _onDeviceTap(device),
                  onFavorite: () async => _onToggleFavorite(device),
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
            value: _offlineLabel(context, favorite),
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

  Widget _desktopAside(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final settings = context.watch(settingsProvider);
    final files = vm.selectedFiles;
    final totalSize = files.fold<int>(0, (sum, file) => sum + file.size);
    final picked = vm.devices.where((device) => _picked.contains(device.fingerprint)).toList();
    final sendSessions = context
        .watch(sendProvider)
        .values
        .where((session) => session.status == SessionStatus.waiting || session.status == SessionStatus.sending)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LsSectionLabel(
          label: t.nearbyTab.tray,
          count: totalSize.asReadableFileSize,
          padding: const EdgeInsets.only(bottom: 8),
        ),
        if (files.isEmpty)
          _dropZone(context)
        else ...[
          for (var index = 0; index < files.length; index++)
            LsFileRow(
              kind: _kindOf(files[index]),
              name: files[index].displayName,
              meta: files[index].size.asReadableFileSize,
              trailing: LsIconButton(
                icon: LucideIcons.x,
                tooltip: files[index].name,
                onPressed: () => vm.onRemoveFile(index),
              ),
            ),
          LsLinkRow(
            label: t.selectedFilesPage.title,
            leading: const Icon(LucideIcons.list),
            onTap: () async => context.push(() => const SelectedFilesPage()),
          ),
          LsLinkRow(
            label: t.nearbyTab.addFile,
            leading: const Icon(LucideIcons.plus),
            onTap: () async => vm.onAddFiles(context),
          ),
          const SizedBox(height: 12),
          LsButton(
            label: t.nearbyTab.send,
            icon: LucideIcons.send,
            expand: true,
            onPressed: (picked.isEmpty || files.isEmpty)
                ? null
                : () async {
                    final started = await vm.onSendToMany(picked);
                    if (started && mounted) {
                      setState(_picked.clear);
                    }
                  },
          ),
          const SizedBox(height: 8),
          Text(
            picked.isEmpty ? t.nearbyTab.selectTarget : picked.map((device) => device.alias).join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tokens.bodySm,
          ),
        ],
        LsSectionLabel(label: t.nearbyTab.inProgress),
        if (sendSessions.isEmpty)
          Text(
            t.transferTab.noActive,
            style: tokens.monoSm.copyWith(letterSpacing: 0.6),
          )
        else
          for (final session in sendSessions) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.target.alias,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.bodySm.copyWith(color: colors.fg),
                  ),
                ),
                _SessionProgressBuilder(
                  sessionId: session.sessionId,
                  builder: (context, transfer) => Text(
                    '${(_sendProgress(session, transfer) * 100).round()}%',
                    style: tokens.monoSm,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _SessionProgressBuilder(
              sessionId: session.sessionId,
              builder: (context, transfer) => LsProgressBar(value: _sendProgress(session, transfer)),
            ),
            const SizedBox(height: 8),
            LsButton(
              label: t.transferTab.cancel,
              variant: LsButtonVariant.ghost,
              onPressed: () => context.notifier(sendProvider).cancelSession(session.sessionId),
            ),
            const SizedBox(height: 10),
          ],
        LsSectionLabel(label: t.nearbyTab.receivePolicy),
        Row(
          children: [
            Expanded(
              child: Text(
                [
                  '${t.general.quickSave}: ${settings.quickSave ? t.general.on : t.general.off}',
                  settings.destination ?? t.settingsTab.receive.downloads,
                ].join(' · '),
                style: tokens.bodySm,
              ),
            ),
            LsSwitch(
              value: settings.quickSave,
              label: t.general.quickSave,
              onChanged: (value) async {
                final wasQuickSave = settings.quickSave;
                final settingsNotifier = context.notifier(settingsProvider);
                await settingsNotifier.setQuickSave(value);
                await settingsNotifier.setQuickSaveFromFavorites(false);
                if (value && !wasQuickSave && context.mounted) {
                  await QuickSaveNotice.open(context);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        LsLinkRow(
          label: t.nearbyTab.securitySettings,
          leading: const Icon(LucideIcons.shield),
          showTopBorder: false,
          onTap: () => context.redux(homePageControllerProvider).dispatch(ChangeTabAction(HomeTab.settings)),
        ),
      ],
    );
  }

  double _sendProgress(SendSessionState session, FileTransferNotifier transfer) {
    final accepted = session.files.values.where((file) => file.token != null);
    final total = accepted.fold<int>(0, (sum, file) => sum + file.file.size);
    if (total == 0) {
      return 0;
    }
    final transferred = accepted.fold<int>(
      0,
      (sum, file) => sum + (transfer.getProgress(sessionId: session.sessionId, fileId: file.file.id) * file.file.size).round(),
    );
    return (transferred / total).clamp(0.0, 1.0);
  }

  Widget _dropZone(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: tokens.tileRadius,
        side: BorderSide(color: colors.lineStrong, width: tokens.hairlineOf(context)),
      ),
      child: InkWell(
        onTap: () async => vm.onAddFiles(context),
        borderRadius: tokens.tileRadius,
        hoverColor: colors.accentSoft,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.plus, size: 16, color: colors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t.nearbyTab.dropHere, style: tokens.body.copyWith(color: colors.muted)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(t.nearbyTab.dropHint, style: tokens.bodySm),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _gridContent(
    BuildContext context, {
    required List<Device> favoritesSection,
    required List<Device> onlineSection,
    required List<FavoriteDevice> offlineSection,
  }) {
    final tokens = context.ls;
    final files = vm.selectedFiles;
    final onlineCount = vm.devices.length;
    final totalCount = onlineCount + _offlineFavoriteCount;

    return [
      _miniRadar(context, onlineCount: onlineCount, totalCount: totalCount),
      if (files.isEmpty)
        _addFilesBar(context)
      else if (_filesOpen)
        Padding(padding: const EdgeInsets.only(top: 10), child: _inlineTray(context))
      else
        Padding(padding: const EdgeInsets.only(top: 10), child: _fileBar(context)),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: LsSearchField(
          controller: _query,
          hint: t.nearbyTab.search,
          onChanged: (_) => setState(() {}),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _filterChip(t.nearbyTab.filterAll, _NearbyFilter.all),
            const SizedBox(width: 8),
            _filterChip(t.nearbyTab.filterOnline, _NearbyFilter.online),
            const SizedBox(width: 8),
            _filterChip(t.nearbyTab.filterFavorites, _NearbyFilter.favorites),
            const Spacer(),
            LsChip.text(
              _multiActive ? t.nearbyTab.multiActive : t.nearbyTab.multi,
              accent: _multiActive,
              onTap: () => _toggleMulti(),
            ),
          ],
        ),
      ),
      if (favoritesSection.isNotEmpty) ...[
        LsSectionLabel(label: t.nearbyTab.favorites, count: '${favoritesSection.length}', padding: const EdgeInsets.only(bottom: 8)),
        _deviceGrid(context, favoritesSection),
      ],
      if (_filter != _NearbyFilter.favorites) ...[
        LsSectionLabel(label: t.nearbyTab.onlineSection, count: '${onlineSection.length}', padding: const EdgeInsets.only(top: 14, bottom: 8)),
        if (onlineSection.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(t.nearbyTab.noOnlineMatch, style: tokens.bodySm),
          )
        else
          _deviceGrid(context, onlineSection),
      ],
      if (offlineSection.isNotEmpty) ...[
        LsSectionLabel(label: t.nearbyTab.offlineSection, count: '${offlineSection.length}', padding: const EdgeInsets.only(top: 14, bottom: 8)),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 62,
          ),
          itemCount: offlineSection.length,
          itemBuilder: (context, index) => _offlineTile(context, offlineSection[index]),
        ),
      ],
      if (vm.devices.isEmpty && vm.favoriteDevices.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Text(t.nearbyTab.noDevices, style: tokens.bodySm),
        ),
    ];
  }

  Widget _miniRadar(BuildContext context, {required int onlineCount, required int totalCount}) {
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
          LsStatusDot(on: onlineCount > 0),
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
          LsIconButton(
            icon: LucideIcons.refreshCw,
            tooltip: t.nearbyTab.scan,
            onPressed: () async => vm.onScan(context),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _NearbyFilter filter) {
    return LsChip.text(
      label,
      accent: _filter == filter,
      onTap: () => setState(() => _filter = filter),
    );
  }

  Widget _deviceGrid(BuildContext context, List<Device> devices) {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 62,
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
    ].join(' · ');

    return LsDeviceTile(
      glyph: Icon(device.deviceType.icon),
      name: device.alias,
      meta: info.isEmpty ? (device.ip ?? '') : '$info · ${device.ip ?? ''}',
      selected: _picked.contains(device.fingerprint),
      favorite: favorite,
      multi: _multiActive && !widget.desktop,
      showFavoriteButton: widget.desktop || !_multiActive,
      onTap: () async => _onDeviceTap(device),
      onLongPress: () async => _onDeviceLongPress(device),
      onFavorite: () async => _onToggleFavorite(device),
      onDetails: () async => context.push(() => DeviceDetailsPage(device: device)),
    );
  }

  /// "离线" plus when the device was last confirmed, when that is known.
  String _offlineLabel(BuildContext context, FavoriteDevice favorite) {
    final lastSeen = context.watch(deviceLastSeenProvider)[favorite.fingerprint];
    if (lastSeen == null) {
      return t.nearbyTab.offline;
    }
    return '${t.nearbyTab.offline} · ${relativeAgo(lastSeen)}';
  }

  Widget _offlineTile(BuildContext context, FavoriteDevice favorite) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Opacity(
      opacity: 0.55,
      child: Material(
        color: colors.bg2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.line, width: tokens.hairlineOf(context)),
        ),
        child: InkWell(
          onTap: () => context.showSnackBar(t.nearbyTab.offlineHint),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 24, 8),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: colors.bg3, borderRadius: BorderRadius.circular(8)),
                  child: Icon(LucideIcons.monitor, size: 16, color: colors.fg),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        favorite.alias,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.bodyStrong,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _offlineLabel(context, favorite),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.monoSm,
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () async {
                    await vm.onToggleFavoriteOffline(favorite);
                  },
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: Icon(LucideIcons.star, size: 13, color: colors.accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- file tray

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
                  '${t.nearbyTab.addFile} · ${t.nearbyTab.filesEmpty}',
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
        onTap: () => setState(() => _filesOpen = true),
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
              LsChip.text(t.nearbyTab.linkReceive, onTap: () async => vm.onOpenLink(context)),
              const SizedBox(width: 6),
              LsChip.text(t.nearbyTab.clear, onTap: () async => vm.onClearFiles(context)),
              const SizedBox(width: 6),
              LsChip.text(t.nearbyTab.collapse, onTap: () => setState(() => _filesOpen = false)),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: colors.line),
          const SizedBox(height: 8),
          _fileGrid(context, columns: 4),
        ],
      ),
    );
  }

  Widget _fileGrid(BuildContext context, {required int columns, double? maxTileWidth}) {
    final files = vm.selectedFiles;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final cellWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        // Radar mode caps the squares at the center bubble size; the cells stay
        // in the 4-column rhythm, the extra width becomes gutter.
        final tileWidth = maxTileWidth == null ? cellWidth : math.min(cellWidth, maxTileWidth);
        Widget cell(Widget child) => Center(
          child: SizedBox(width: tileWidth, child: child),
        );
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 192),
          child: GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            // the tray caps at 192px; keep the grid scrollable so no file becomes unreachable
            physics: const ClampingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
              mainAxisExtent: tileWidth + 16,
            ),
            itemCount: files.length + 1,
            itemBuilder: (context, index) {
              if (index == files.length) {
                return cell(
                  LsAddFileTile(
                    label: t.nearbyTab.addFile,
                    onTap: () async => vm.onAddFiles(context),
                  ),
                );
              }
              final file = files[index];
              final kind = _kindOf(file);
              return cell(
                LsFileTile(
                  kind: kind,
                  name: file.name,
                  meta: file.size.asReadableFileSize,
                  tint: lsKindTint[kind],
                  thumbnail: SmartFileThumbnail.fromCrossFile(file),
                  onRemove: () => vm.onRemoveFile(index),
                  onTap: () async => context.push(() => const SelectedFilesPage()),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------- radar layout

  List<Widget> _radarContent(
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
      Row(
        children: [
          Expanded(
            child: Text(
              t.nearbyTab.online(online: vm.devices.length, total: vm.devices.length + _offlineFavoriteCount),
              style: tokens.eyebrow,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (total > shown)
            Text(
              t.nearbyTab.radarHidden(shown: shown, total: total),
              style: tokens.monoSm.copyWith(color: colors.faint),
            ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        // Wraps instead of overflowing: the four chips do not fit a 320 px phone.
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip(t.nearbyTab.filterAll, _NearbyFilter.all),
            _filterChip(t.nearbyTab.filterOnline, _NearbyFilter.online),
            _filterChip(t.nearbyTab.filterFavorites, _NearbyFilter.favorites),
            LsChip.text(
              _multiActive ? t.nearbyTab.multiActive : t.nearbyTab.multi,
              accent: _multiActive,
              onTap: () => _toggleMulti(),
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
                  selected: _picked.contains(radarOnline[i].fingerprint),
                  tooltip: radarOnline[i].alias,
                  onTap: () async => _onDeviceTap(radarOnline[i]),
                  // Same as the device grid: long press enters multi-select and
                  // preselects this device.
                  onLongPress: () async => _onDeviceLongPress(radarOnline[i]),
                ),
              if (radarOffline != null)
                LsRadarPeer(
                  child: const Icon(LucideIcons.monitor),
                  label: radarOffline.alias,
                  angle: slots.last.angle,
                  radius: slots.last.radius,
                  size: slots.last.size,
                  offline: true,
                  labelAbove: true,
                  tooltip: '${radarOffline.alias} · ${t.nearbyTab.offline}',
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
            if (files.isNotEmpty) ...[
              LsChip.text(t.nearbyTab.clear, onTap: () async => vm.onClearFiles(context)),
              const SizedBox(width: 6),
            ],
            LsChip.text(t.nearbyTab.linkReceive, onTap: () async => vm.onOpenLink(context)),
            const SizedBox(width: 6),
            LsChip.text(t.nearbyTab.manualIp, onTap: () async => vm.onManualIp(context)),
          ],
        ),
      ),
      // Radar mode keeps the pending-file squares at or below the center bubble.
      _fileGrid(context, columns: 4, maxTileWidth: _radarSelfSize),
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

  // -------------------------------------------------------------- multi action

  Widget _multiBar(BuildContext context) {
    final tokens = context.ls;
    final files = vm.selectedFiles;
    final totalSize = files.fold<int>(0, (sum, file) => sum + file.size);
    final picked = vm.devices.where((device) => _picked.contains(device.fingerprint)).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: tokens.colors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.colors.lineStrong),
        boxShadow: [BoxShadow(color: _shadowColor(context), blurRadius: 34, offset: const Offset(0, 14))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  picked.isEmpty ? t.nearbyTab.selectTarget : t.nearbyTab.selected(n: picked.length),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.bodyStrong,
                ),
                Text(
                  '${files.length} · ${totalSize.asReadableFileSize}',
                  style: tokens.mono,
                ),
              ],
            ),
          ),
          LsButton(
            label: t.nearbyTab.send,
            icon: LucideIcons.send,
            onPressed: (picked.isEmpty || files.isEmpty)
                ? null
                : () async {
                    final started = await vm.onSendToMany(picked);
                    if (!started || !context.mounted) {
                      return;
                    }
                    setState(() {
                      _picked.clear();
                      _multiOverride = null;
                    });
                    context.redux(homePageControllerProvider).dispatch(ChangeTabAction(HomeTab.transfer));
                  },
          ),
        ],
      ),
    );
  }
}

Color _shadowColor(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Colors.black.withValues(alpha: dark ? 0.5 : 0.12);
}

int _byAlias(Device a, Device b) => a.alias.toLowerCase().compareTo(b.alias.toLowerCase());

String _kindOf(CrossFile file) {
  final name = file.name;
  final dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) {
    return 'FILE';
  }
  final kind = name.substring(dot + 1).toUpperCase();
  return kind.length > 4 ? kind.substring(0, 4) : kind;
}

/// Rebuilds only [builder] when the progress of [sessionId] changes.
///
/// Progress events arrive up to 50 times per second, so watching
/// [fileTransferProvider] would rebuild the whole page (radar and device grid
/// included) for every single tick.
class _SessionProgressBuilder extends StatelessWidget {
  final String sessionId;
  final Widget Function(BuildContext context, FileTransferNotifier transfer) builder;

  const _SessionProgressBuilder({required this.sessionId, required this.builder});

  @override
  Widget build(BuildContext context) {
    final transfer = context.ref.read(fileTransferProvider);
    return ValueListenableBuilder<int>(
      valueListenable: transfer.sessionTick(sessionId),
      builder: (context, _, _) => builder(context, transfer),
    );
  }
}
