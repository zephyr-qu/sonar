import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonar/model/persistence/color_mode.dart';
import 'package:sonar/model/persistence/nearby_layout.dart';
import 'package:sonar/model/state/settings_state.dart';
import 'package:sonar/provider/persistence_provider.dart';

SettingsState _state() {
  return const SettingsState(
    showToken: 'token',
    alias: 'Phone',
    theme: ThemeMode.system,
    colorMode: ColorMode.localsend,
    customColor: Colors.teal,
    locale: null,
    port: 53317,
    networkWhitelist: null,
    networkBlacklist: null,
    multicastGroup: '224.0.0.167',
    destination: null,
    saveToGallery: false,
    saveToHistory: true,
    quickSave: false,
    quickSaveFromFavorites: true,
    receivePin: null,
    autoFinish: false,
    minimizeToTray: false,
    https: true,
    saveWindowPlacement: false,
    alwaysOnTop: false,
    enableAnimations: true,
    deviceType: null,
    deviceModel: null,
    shareViaLinkAutoAccept: false,
    receiveViaLinkAutoAccept: false,
    createChecksums: true,
    verifyChecksums: true,
    discoveryTimeout: 500,
    nearbyLayout: NearbyLayout.radar,
  );
}

void main() {
  test('the nearby layout defaults to the radar', () {
    expect(_state().nearbyLayout, NearbyLayout.radar);
  });

  test('copyWith keeps the nearby layout in sync', () {
    final state = _state().copyWith(nearbyLayout: NearbyLayout.radar);

    expect(state.nearbyLayout, NearbyLayout.radar);
    expect(state.alias, 'Phone');
  });

  test('unknown or missing persisted names fall back to the radar', () {
    expect(parseNearbyLayout(null), NearbyLayout.radar);
    expect(parseNearbyLayout('grid'), NearbyLayout.grid);
    expect(parseNearbyLayout('radar'), NearbyLayout.radar);
    expect(parseNearbyLayout('wetware'), NearbyLayout.radar);
  });

  test('the persisted layout names stay stable', () {
    // PersistenceService stores `NearbyLayout.name`; renaming an enum value would
    // silently reset the user's choice.
    expect(NearbyLayout.values.map((layout) => layout.name), ['grid', 'radar']);
  });
}
