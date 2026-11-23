import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/cross_file.dart';
import 'package:sonar/model/persistence/favorite_device.dart';
import 'package:sonar/model/persistence/nearby_layout.dart';
import 'package:sonar/pages/home_page.dart';
import 'package:sonar/pages/home_page_controller.dart';
import 'package:sonar/pages/settings_page.dart';
import 'package:sonar/pages/tabs/nearby/nearby_desktop_view.dart';
import 'package:sonar/pages/tabs/nearby/nearby_grid_view.dart';
import 'package:sonar/pages/tabs/nearby/nearby_radar_view.dart';
import 'package:sonar/pages/tabs/nearby/nearby_ui.dart';
import 'package:sonar/pages/tabs/nearby_tab_vm.dart';
import 'package:sonar/pages/web_share_page.dart';
import 'package:sonar/provider/animation_provider.dart';
import 'package:sonar/provider/selection/selected_sending_files_provider.dart';
import 'package:sonar/provider/settings_provider.dart';
import 'package:sonar/util/favorites.dart';
import 'package:sonar/util/ui/snackbar.dart';
import 'package:sonar/widget/desktop_scaffold.dart';
import 'package:sonar/widget/dialogs/device_name_dialog.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_header.dart';
import 'package:sonar/widget/ls/ls_refresh.dart';
import 'package:sonar_isolates/model/device.dart';
import 'package:sonar_isolates/util/file_size_helper.dart';

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

  /// Bound to the desktop search field so the Ctrl/Cmd+F shortcut can focus it.
  final FocusNode _searchFocus = FocusNode();

  /// Ephemeral view state of this page. Replaced through [NearbyUi.copyWith], never mutated in place.
  NearbyUi _ui = const NearbyUi.initial();

  /// Non-null while the desktop share panel replaces the device grid.
  /// `_webShareFiles == null` inside an open panel means "receive via link".
  List<CrossFile>? _webShareFiles;
  bool _webShareOpen = false;
  @override
  void dispose() {
    _query.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  NearbyTabVm get vm => widget.vm;

  bool get _multiActive => widget.desktop || (_ui.multiOverride ?? false);

  /// Built on demand: the views only need callbacks, so there is nothing to cache.
  NearbyActions get _actions => NearbyActions(
    query: _query,
    searchFocus: _searchFocus,
    onQueryChanged: () => setState(() {}),
    onFilterChanged: (filter) => setState(() => _ui = _ui.copyWith(filter: filter)),
    onFilesOpenChanged: (open) => setState(() => _ui = _ui.copyWith(filesOpen: open)),
    onToggleMulti: _toggleMulti,
    onDeviceTap: _onDeviceTap,
    onDeviceLongPress: _onDeviceLongPress,
    onToggleFavorite: _onToggleFavorite,
    onPickedCleared: () => setState(() => _ui = _ui.copyWith(picked: const <String>{}, clearMultiOverride: true)),
    onOpenLink: _onOpenLink,
  );

  /// Puts the cursor in the search field. The tabs keep their state (and their focus)
  /// alive in the PageView, so the handler only fires for the visible tab.
  void _focusSearch() {
    if (context.read(homePageControllerProvider).currentTab != HomeTab.nearby) {
      return;
    }
    _searchFocus.requestFocus();
  }

  void _toggleMulti({String? preselect}) {
    final active = _multiActive;
    setState(() {
      _ui = _ui.copyWith(
        multiOverride: !active,
        picked: active ? const <String>{} : (preselect == null ? _ui.picked : {..._ui.picked, preselect}),
        filesOpen: false,
      );
    });
  }

  /// Pulling the list replaces the rescan button the grid layout used to carry.
  ///
  /// The scan is not awaited: it keeps probing subnets for seconds after the devices are already
  /// back on screen, and the gesture must end when the finger lifts, not when the last probe does.
  void _onRefresh() {
    // Picking targets hides the actions behind the bottom bar; a rescan under an open selection
    // would only reshuffle the grid, so the gesture is ignored while it is active.
    if (_multiActive) {
      return;
    }
    unawaited(vm.onScan(context));
  }

  Future<void> _onDeviceTap(Device device) async {
    if (_multiActive) {
      setState(() => _ui = _ui.toggled(device.fingerprint));
      return;
    }
    await vm.onTapDevice(context, device);
  }

  Future<void> _onDeviceLongPress(Device device) async {
    await HapticFeedback.mediumImpact();
    if (_multiActive) {
      setState(() => _ui = _ui.toggled(device.fingerprint));
      return;
    }
    // The multi-select bar at the bottom already reports the picked count, so no
    // snackbar here — it would only duplicate it.
    _toggleMulti(preselect: device.fingerprint);
  }

  Future<void> _onToggleFavorite(Device device) async {
    final nowFavorite = await vm.onToggleFavorite(device);
    if (mounted) {
      context.showSnackBar(nowFavorite ? t.nearbyTab.favorited : t.nearbyTab.unfavorited);
    }
  }

  /// Mobile pushes the share page; desktop swaps the grid for the panel so the
  /// rail and the device header stay reachable while a link is shared.
  Future<void> _onOpenLink(BuildContext context) async {
    if (!widget.desktop) {
      await vm.onOpenLink(context);
      return;
    }
    final files = context.read(selectedSendingFilesProvider);
    setState(() {
      _webShareFiles = files.isEmpty ? null : files;
      _webShareOpen = true;
    });
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
    final favoritesSection = _ui.filter == NearbyFilter.online ? <Device>[] : favoriteDevices.where(matches).toList();
    final onlineSection = _ui.filter == NearbyFilter.favorites
        ? <Device>[]
        : (_ui.filter == NearbyFilter.online
              ? [...favoriteDevices.where(matches), ...onlineDevices.where(matches)]
              : onlineDevices.where(matches).toList());
    final offlineSection = _ui.filter == NearbyFilter.online ? <FavoriteDevice>[] : offlineFavorites;

    if (widget.desktop) {
      final view = NearbyDesktopView(vm: vm, ui: _ui, actions: _actions);
      // Ctrl/Cmd+F anywhere inside the tab. The binding is scoped to this subtree,
      // which also keeps it from stealing the shortcut on the other tabs.
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): _focusSearch,
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _focusSearch,
        },
        child: Column(
          children: [
            _desktopHeader(context),
            Expanded(
              child: _webShareOpen
                  ? WebSharePanel(
                      files: _webShareFiles,
                      onClosed: () => setState(() => _webShareOpen = false),
                    )
                  : LsDesktopLayout(
                      content: ListView(
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
                        children: view.content(context, favoritesSection, onlineSection, offlineSection),
                      ),
                      aside: view.aside(context),
                    ),
            ),
          ],
        ),
      );
    }

    final sections = layout == NearbyLayout.radar
        ? NearbyRadarView(vm: vm, ui: _ui, actions: _actions).content(
            context,
            animations: animations,
            favoritesSection: favoritesSection,
            onlineSection: onlineSection,
            offlineSection: offlineSection,
          )
        : NearbyGridView(vm: vm, ui: _ui, desktop: widget.desktop, actions: _actions).content(
            context,
            animations: animations,
            favoritesSection: favoritesSection,
            onlineSection: onlineSection,
            offlineSection: offlineSection,
          );

    return Column(
      children: [
        _header(context, animations),
        Expanded(
          child: Stack(
            children: [
              // Pull-to-refresh is the mobile rescan gesture (the grid layout's refresh button is
              // gone). It sits on the ListView rather than on the Stack so the indicator is not
              // painted under the multi-select bar, and the physics keep the pull available when
              // the content is shorter than the viewport.
              LsRefreshIndicator(
                onRefresh: _onRefresh,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(tokens.pad, 0, tokens.pad, _multiActive ? 120 : 18),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: sections,
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

  /// [animations] gates the dot's breath; the status text is appended rather than replaced, because
  /// "visible + ip" is what the user came to the header for and a scan only lasts a couple of seconds.
  Widget _header(BuildContext context, bool animations) {
    final tokens = context.ls;
    final ip = vm.localIps.isNotEmpty ? vm.localIps.first : t.general.unknown;
    return LsScreenHeader(
      mark: const Icon(LucideIcons.radar),
      title: vm.alias,
      titleTooltip: t.settingsTab.network.alias,
      onTitleTap: () => showDeviceNameDialog(context),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LsStatusDot(on: vm.visible, pulse: vm.scanning && animations),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              // Appended, not replaced: visibility and ip stay readable while a scan runs.
              '${vm.visible ? t.nearbyTab.visible : t.nearbyTab.hidden}  $ip'
              '${vm.scanning ? '  ·  ${t.nearbyTab.scanning}' : ''}',
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

  // -------------------------------------------------------------- multi action

  Widget _multiBar(BuildContext context) {
    final tokens = context.ls;
    final files = vm.selectedFiles;
    final totalSize = files.fold<int>(0, (sum, file) => sum + file.size);
    final picked = vm.devices.where((device) => _ui.picked.contains(device.fingerprint)).toList();

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
                  '${files.length}  ${totalSize.asReadableFileSize}',
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
                    if (!context.mounted) {
                      return;
                    }
                    if (!started) {
                      // Nothing started: every picked device already has a running session, and
                      // the target must not be stacked a second time.
                      context.showSnackBar(t.nearbyTab.inProgress);
                      return;
                    }
                    setState(() => _ui = _ui.copyWith(picked: const <String>{}, clearMultiOverride: true));
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
