import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mockito/mockito.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/config/theme.dart';
import 'package:sonar/model/persistence/color_mode.dart';
import 'package:sonar/model/persistence/favorite_device.dart';
import 'package:sonar/pages/tabs/nearby/nearby_grid_view.dart';
import 'package:sonar/pages/tabs/nearby/nearby_ui.dart';
import 'package:sonar/pages/tabs/nearby_tab_vm.dart';
import 'package:sonar/provider/persistence_provider.dart';
import 'package:sonar/widget/ls/ls_section_label.dart';
import 'package:sonar/widget/ls/ls_tile.dart';
import 'package:sonar_isolates/model/device.dart';

import '../mocks.mocks.dart';

/// The offline favorites grid uses the same 62px cells as the online one, so a two-line alias has to
/// fit there as well; it used to overflow by ~6px until the title picked up the tight leading.
void main() {
  testWidgets('offline favorite tile keeps a two-line alias inside the 62px grid cell', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final persistence = MockPersistenceService();
    when(persistence.getDeviceLastSeen()).thenReturn(const {});
    final favorite = FavoriteDevice(
      id: 'device-id',
      fingerprint: 'fingerprint',
      ip: '192.168.1.2',
      port: 53317,
      alias: 'Kai 的 iPhone 15 Pro Max',
    );
    final view = NearbyGridView(vm: _vm(favorite), ui: const NearbyUi.initial(), desktop: false, actions: _actions());

    await tester.pumpWidget(
      RefenaScope(
        overrides: [persistenceProvider.overrideWithValue(persistence)],
        child: MaterialApp(
          theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark),
          home: Scaffold(
            body: Builder(
              // Only the offline grid: the surrounding chrome (filter chips, radar row) is irrelevant
              // here and its labels do not fit the test font's metrics.
              builder: (context) => ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                children: [
                  view.content(context, animations: false, favoritesSection: const [], onlineSection: const [], offlineSection: [favorite]).last,
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // The offline cell is the online cell: same widget, same geometry, only the
    // glyph, the meta line and the missing details action differ.
    expect(find.byType(LsDeviceTile), findsOneWidget);
    expect(find.text(favorite.alias), findsOneWidget);
    // Overflow of the two-line name inside the 62px cell would surface here.
    expect(tester.takeException(), isNull);
  });

  // The offline grid used to hard-code the desktop glyph, so a favorited phone or tablet turned into
  // a computer the moment it went offline. The favorite remembers the announced type now, and the
  // glyph has to follow it instead of falling back to that hard-coded value.
  testWidgets('offline favorite tile shows the remembered device type glyph', (tester) async {
    final persistence = MockPersistenceService();
    when(persistence.getDeviceLastSeen()).thenReturn(const {});
    final favorite = FavoriteDevice(
      id: 'device-id',
      fingerprint: 'fingerprint',
      ip: '192.168.1.2',
      port: 53317,
      alias: 'iPad',
      deviceType: DeviceType.tablet,
    );
    final view = NearbyGridView(vm: _vm(favorite), ui: const NearbyUi.initial(), desktop: false, actions: _actions());

    await tester.pumpWidget(
      RefenaScope(
        overrides: [persistenceProvider.overrideWithValue(persistence)],
        child: MaterialApp(
          theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark),
          home: Scaffold(
            body: Builder(
              builder: (context) => ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                children: [
                  view.content(context, animations: false, favoritesSection: const [], onlineSection: const [], offlineSection: [favorite]).last,
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(LucideIcons.tablet), findsOneWidget);
    expect(find.byIcon(LucideIcons.monitor), findsNothing);
  });

  // The offline section used to hard-code a 14px lead-in. Under the favorites filter it is the first
  // section below the chip row (which already leaves 10px), so it sat 14px lower than the online
  // section does under "All".
  testWidgets('offline section lead-in depends on whether a section precedes it', (tester) async {
    final persistence = MockPersistenceService();
    when(persistence.getDeviceLastSeen()).thenReturn(const {});
    final favorite = FavoriteDevice(id: 'device-id', fingerprint: 'fingerprint', ip: '192.168.1.2', port: 53317, alias: 'Phone');
    final vm = _vm(favorite);
    final actions = _actions();

    Future<EdgeInsetsGeometry> offlineLabelPadding(NearbyFilter filter) async {
      await tester.pumpWidget(
        RefenaScope(
          overrides: [persistenceProvider.overrideWithValue(persistence)],
          child: MaterialApp(
            theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark),
            home: Scaffold(
              body: Builder(
                // Only the last section label: the grid and the chrome are irrelevant to the spacing.
                builder: (context) => ListView(
                  children: [
                    NearbyGridView(
                          vm: vm,
                          ui: NearbyUi.initial().copyWith(filter: filter),
                          desktop: false,
                          actions: actions,
                        )
                        .content(
                          context,
                          animations: false,
                          favoritesSection: const [],
                          onlineSection: const [],
                          offlineSection: [favorite],
                        )
                        .whereType<LsSectionLabel>()
                        .last,
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      return tester.widget<LsSectionLabel>(find.byType(LsSectionLabel)).padding;
    }

    // First section under the chip row: no additional lead-in.
    expect(await offlineLabelPadding(NearbyFilter.favorites), const EdgeInsets.only(bottom: 8));
    // Follows the online section: the usual lead-in.
    expect(await offlineLabelPadding(NearbyFilter.all), const EdgeInsets.only(top: 14, bottom: 8));
  });
}

NearbyTabVm _vm(FavoriteDevice favorite) => NearbyTabVm(
  alias: 'This device',
  visible: false,
  port: 53317,
  https: false,
  scanning: false,
  localIps: const [],
  selectedFiles: const [],
  devices: const [],
  favoriteDevices: [favorite],
  onToggleVisibility: (_) async {},
  onManualIp: (_) async {},
  onScan: (_) async {},
  onAddFiles: (_) async {},
  onOpenLink: (_) async {},
  onClearFiles: (_) async {},
  onTapDevice: (_, _) async {},
  onSendToMany: (_) async => false,
  onToggleFavorite: (_) async => false,
  onToggleFavoriteOffline: (_) async {},
  onRemoveFile: (_) {},
);

NearbyActions _actions() {
  final query = TextEditingController();
  final searchFocus = FocusNode();
  addTearDown(query.dispose);
  addTearDown(searchFocus.dispose);
  return NearbyActions(
    query: query,
    searchFocus: searchFocus,
    onQueryChanged: () {},
    onFilterChanged: (_) {},
    onFilesOpenChanged: (_) {},
    onToggleMulti: ({String? preselect}) {},
    onOpenLink: (_) async {},
    onDeviceTap: (_) async {},
    onDeviceLongPress: (_) async {},
    onToggleFavorite: (_) async {},
    onPickedCleared: () {},
  );
}
