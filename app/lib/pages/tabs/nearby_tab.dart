import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/favorite_device.dart';
import 'package:localsend_app/model/persistence/nearby_layout.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/settings_page.dart';
import 'package:localsend_app/pages/tabs/nearby/nearby_desktop_view.dart';
import 'package:localsend_app/pages/tabs/nearby/nearby_grid_view.dart';
import 'package:localsend_app/pages/tabs/nearby/nearby_radar_view.dart';
import 'package:localsend_app/pages/tabs/nearby/nearby_ui.dart';
import 'package:localsend_app/pages/tabs/nearby_tab_vm.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/ui/snackbar.dart';
import 'package:localsend_app/widget/desktop_scaffold.dart';
import 'package:localsend_app/widget/ls/ls_buttons.dart';
import 'package:localsend_app/widget/ls/ls_header.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/util/file_size_helper.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

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

  /// Ephemeral view state of this page. Replaced through [NearbyUi.copyWith], never mutated in place.
  NearbyUi _ui = const NearbyUi.initial();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  NearbyTabVm get vm => widget.vm;

  bool get _multiActive => widget.desktop || (_ui.multiOverride ?? false);

  /// Built on demand: the views only need callbacks, so there is nothing to cache.
  NearbyActions get _actions => NearbyActions(
    query: _query,
    onQueryChanged: () => setState(() {}),
    onFilterChanged: (filter) => setState(() => _ui = _ui.copyWith(filter: filter)),
    onFilesOpenChanged: (open) => setState(() => _ui = _ui.copyWith(filesOpen: open)),
    onToggleMulti: _toggleMulti,
    onDeviceTap: _onDeviceTap,
    onDeviceLongPress: _onDeviceLongPress,
    onToggleFavorite: _onToggleFavorite,
    onPickedCleared: () => setState(() => _ui = _ui.copyWith(picked: const <String>{}, clearMultiOverride: true)),
  );

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
    _toggleMulti(preselect: device.fingerprint);
    if (mounted) {
      context.showSnackBar(t.nearbyTab.selected(n: _ui.picked.length));
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
    final favoritesSection = _ui.filter == NearbyFilter.online ? <Device>[] : favoriteDevices.where(matches).toList();
    final onlineSection = _ui.filter == NearbyFilter.favorites
        ? <Device>[]
        : (_ui.filter == NearbyFilter.online
              ? [...favoriteDevices.where(matches), ...onlineDevices.where(matches)]
              : onlineDevices.where(matches).toList());
    final offlineSection = _ui.filter == NearbyFilter.online ? <FavoriteDevice>[] : offlineFavorites;

    if (widget.desktop) {
      final view = NearbyDesktopView(vm: vm, ui: _ui, actions: _actions);
      return Column(
        children: [
          _desktopHeader(context),
          Expanded(
            child: LsDesktopLayout(
              content: ListView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
                children: view.content(context, favoritesSection, onlineSection, offlineSection),
              ),
              aside: view.aside(context),
            ),
          ),
        ],
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
            favoritesSection: favoritesSection,
            onlineSection: onlineSection,
            offlineSection: offlineSection,
          );

    return Column(
      children: [
        _header(context),
        Expanded(
          child: Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(tokens.pad, 0, tokens.pad, _multiActive ? 120 : 18),
                children: sections,
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
