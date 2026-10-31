import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/model/persistence/nearby_layout.dart';
import 'package:localsend_app/model/state/server/server_state.dart';
import 'package:localsend_app/model/state/settings_state.dart';
import 'package:localsend_app/pages/settings/settings_sections.dart';
import 'package:localsend_app/pages/tabs/settings_tab_vm.dart';
import 'package:localsend_app/widget/ls/ls_buttons.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/device_info_result.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// The setting row each restart hint belongs to.
const _settingRows = {
  ServerSetting.alias: 'device.alias',
  ServerSetting.port: 'network.port',
  ServerSetting.https: 'security.encryption',
  ServerSetting.multicastGroup: 'network.multicast',
  ServerSetting.discoveryTimeout: 'network.timeout',
  ServerSetting.networkInterfaces: 'network.interfaces',
};

const _hintPrefix = 'network.restartHint.';

void main() {
  group('restart hints', () {
    testWidgets('no hint rows while the server runs with the current settings', (tester) async {
      final rows = await _renderRows(tester, pendingRestart: const {});

      expect(rows.where((row) => row.id.startsWith(_hintPrefix)), isEmpty);
    });

    testWidgets('every pending setting adds a warning row right below its setting', (tester) async {
      final rows = await _renderRows(tester, pendingRestart: ServerSetting.values.toSet());
      final ids = [for (final row in rows) row.id];

      for (final entry in _settingRows.entries) {
        final settingRow = ids.indexOf(entry.value);
        expect(settingRow, isNot(-1), reason: '${entry.value} is missing');

        final hintId = '$_hintPrefix${entry.key.name}';
        expect(ids[settingRow + 1], hintId, reason: '${entry.key.name} hint is not directly below ${entry.value}');

        final hint = rows[settingRow + 1];
        expect(hint.warning, isTrue, reason: '$hintId is not rendered as a warning');
        expect(hint.label, t.settingsTab.network.needRestart);
        expect(hint.kind, SettingsRowKind.trailing);
      }
    });

    testWidgets('only the pending settings get a hint row', (tester) async {
      final rows = await _renderRows(tester, pendingRestart: const {ServerSetting.https});
      final hints = [
        for (final row in rows)
          if (row.id.startsWith(_hintPrefix)) row.id,
      ];

      expect(hints, ['${_hintPrefix}https']);
    });

    testWidgets('the hint row offers a restart that reuses the controller callback', (tester) async {
      var restarts = 0;
      final rows = await _renderRows(tester, pendingRestart: const {ServerSetting.port}, onTapRestartServer: (_) => restarts++);
      final hint = rows.firstWhere((row) => row.id.startsWith(_hintPrefix));

      await tester.pumpWidget(_host(children: [SettingsRowTile(row: hint)]));
      await tester.pumpAndSettle();

      final button = find.widgetWithText(LsButton, t.general.restart);
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(restarts, 1);
    });
  });

  group('search matching', () {
    test('matches the label, the description and the current value', () {
      const row = SettingsRow(
        id: 'network.port',
        label: 'Port',
        description: 'Must be the same on every device',
        kind: SettingsRowKind.stacked,
        value: '53317',
        child: SizedBox(),
      );

      expect(row.matches('port'), isTrue);
      expect(row.matches('same on every'), isTrue);
      expect(row.matches('53317'), isTrue);
      expect(row.matches('multicast'), isFalse);
    });
  });
}

/// Rows of every section, built from a fake view model without mounting a page.
Future<List<SettingsRow>> _renderRows(
  WidgetTester tester, {
  required Set<ServerSetting> pendingRestart,
  void Function(BuildContext context)? onTapRestartServer,
}) async {
  late List<SettingsRow> rows;
  await tester.pumpWidget(
    RefenaScope(
      child: MaterialApp(
        theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark, null),
        home: Builder(
          builder: (context) {
            rows = [
              for (final section in buildSettingsSections()) ...section.buildRows(context, _vm(pendingRestart, onTapRestartServer)),
            ];
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return rows;
}

Widget _host({required List<Widget> children}) {
  return RefenaScope(
    child: MaterialApp(
      theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark, null),
      home: Scaffold(body: ListView(children: children)),
    ),
  );
}

SettingsTabVm _vm(Set<ServerSetting> pendingRestart, void Function(BuildContext context)? onTapRestartServer) {
  return SettingsTabVm(
    aliasController: TextEditingController(text: 'Test device'),
    deviceModelController: TextEditingController(text: 'Model'),
    portController: TextEditingController(text: '53317'),
    timeoutController: TextEditingController(text: '500'),
    multicastController: TextEditingController(text: '224.0.0.167'),
    settings: _settings(),
    serverState: const ServerState(alias: 'Test device', port: 53317, https: true, session: null, web: null),
    deviceInfo: DeviceInfoResult(deviceType: DeviceType.desktop, deviceModel: 'Model', androidSdkInt: null),
    colorModes: [
      for (final mode in ColorMode.values)
        if (mode != ColorMode.custom) mode,
    ],
    autoStart: false,
    autoStartLaunchHidden: false,
    showInContextMenu: false,
    onChangeTheme: (context, mode) {},
    onChangeColorMode: (context, mode) {},
    onTapLanguage: (context) {},
    onToggleAutoStart: (context) {},
    onToggleAutoStartLaunchHidden: (context) {},
    onToggleShowInContextMenu: (context) {},
    onTapRestartServer: onTapRestartServer ?? (context) {},
    onTapStartServer: (context) {},
    onTapStopServer: () {},
    pendingRestart: pendingRestart,
  );
}

SettingsState _settings() {
  return const SettingsState(
    showToken: 'token',
    alias: 'Test device',
    theme: ThemeMode.dark,
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
    quickSaveFromFavorites: false,
    receivePin: null,
    autoFinish: false,
    minimizeToTray: false,
    https: true,
    saveWindowPlacement: false,
    alwaysOnTop: false,
    enableAnimations: true,
    deviceType: DeviceType.desktop,
    deviceModel: 'Model',
    shareViaLinkAutoAccept: false,
    receiveViaLinkAutoAccept: false,
    createChecksums: true,
    verifyChecksums: true,
    discoveryTimeout: 500,
    nearbyLayout: NearbyLayout.radar,
  );
}
