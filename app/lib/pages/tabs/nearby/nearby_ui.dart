import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/favorite_device.dart';
import 'package:localsend_app/pages/tabs/nearby_tab_vm.dart';
import 'package:localsend_app/provider/device_last_seen_provider.dart';
import 'package:localsend_app/util/ui/relative_time.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Which subset of the nearby devices the tab is showing.
enum NearbyFilter { all, online, favorites }

/// Immutable snapshot of the nearby tab's ephemeral view state.
///
/// Kept in the `State` instead of a provider on purpose: it only has to live as long as the page is mounted, and a
/// provider would outlive tab switches and need manual resets. Every mutation goes through [copyWith], so no builder
/// ever observes a half-updated selection.
class NearbyUi {
  final Set<String> picked;
  final NearbyFilter filter;

  /// `null` follows the persisted send mode; a value overrides it for this session.
  final bool? multiOverride;
  final bool filesOpen;

  const NearbyUi({
    required this.picked,
    required this.filter,
    required this.multiOverride,
    required this.filesOpen,
  });

  const NearbyUi.initial() : picked = const <String>{}, filter = NearbyFilter.all, multiOverride = null, filesOpen = false;

  /// [copyWith] cannot express "reset [multiOverride] back to null", so clearing it is a separate operation.
  NearbyUi copyWith({
    Set<String>? picked,
    NearbyFilter? filter,
    bool? multiOverride,
    bool? filesOpen,
    bool clearMultiOverride = false,
  }) {
    return NearbyUi(
      picked: picked ?? this.picked,
      filter: filter ?? this.filter,
      multiOverride: clearMultiOverride ? null : (multiOverride ?? this.multiOverride),
      filesOpen: filesOpen ?? this.filesOpen,
    );
  }

  /// Adds [fingerprint] to [picked], or removes it when it is already there.
  NearbyUi toggled(String fingerprint) {
    if (!picked.contains(fingerprint)) {
      return copyWith(picked: {...picked, fingerprint});
    }
    return copyWith(picked: {...picked}..remove(fingerprint));
  }
}

/// "Offline" plus how long ago the device was last seen, when that is known.
String offlineLabel(BuildContext context, FavoriteDevice favorite) {
  final lastSeen = context.watch(deviceLastSeenProvider)[favorite.fingerprint];
  if (lastSeen == null) {
    return t.nearbyTab.offline;
  }
  return '${t.nearbyTab.offline} · ${relativeAgo(lastSeen)}';
}

/// Favorites that are saved but not currently discovered.
int offlineFavoriteCount(NearbyTabVm vm) {
  return vm.favoriteDevices.where((favorite) => !vm.devices.any((device) => device.fingerprint == favorite.fingerprint)).length;
}

/// The views are dumb: they render a [NearbyUi] and forward user intent here.
///
/// All the state transitions (multi-select toggling, filter changes, haptics, snackbars) stay in the page's `State`,
/// so a view never needs to know *how* a change is applied.
class NearbyActions {
  /// The search field's controller lives in the page so it can be disposed there.
  final TextEditingController query;

  /// Focus node of the same field, so the page can bind Ctrl/Cmd+F to it.
  final FocusNode searchFocus;
  final VoidCallback onQueryChanged;
  final void Function(NearbyFilter filter) onFilterChanged;
  final void Function(bool open) onFilesOpenChanged;
  final void Function({String? preselect}) onToggleMulti;
  final Future<void> Function(Device device) onDeviceTap;
  final Future<void> Function(Device device) onDeviceLongPress;
  final Future<void> Function(Device device) onToggleFavorite;

  /// Leaves multi-select and clears the selection (desktop's "send finished" reset).
  final VoidCallback onPickedCleared;

  const NearbyActions({
    required this.query,
    required this.searchFocus,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onFilesOpenChanged,
    required this.onToggleMulti,
    required this.onDeviceTap,
    required this.onDeviceLongPress,
    required this.onToggleFavorite,
    required this.onPickedCleared,
  });
}
