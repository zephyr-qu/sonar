import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/persistence/color_mode.dart';
import 'package:sonar/model/persistence/nearby_layout.dart';
import 'package:sonar/model/persistence/quick_save_mode.dart';
import 'package:sonar/model/state/settings_state.dart';
import 'package:sonar/provider/persistence_provider.dart';
import 'package:sonar/provider/settings_provider.dart';
import 'package:sonar_isolates/isolate.dart';
import 'package:sonar_isolates/model/device.dart';
import 'package:sonar_isolates/model/device_info_result.dart';
import 'package:sonar_isolates/model/dto/multicast_dto.dart';
import 'package:sonar_isolates/model/stored_security_context.dart';

import '../../mocks.mocks.dart';

/// One setting: how it is changed, what it must write, and where the new value shows up.
class _SettingCase {
  final String name;
  final Future<void> Function(SettingsService service) apply;
  final void Function() verifyPersisted;
  final Object? Function(SettingsState state) read;
  final Object? expected;

  const _SettingCase({
    required this.name,
    required this.apply,
    required this.verifyPersisted,
    required this.read,
    required this.expected,
  });
}

/// The sync state the child isolates start with, used as the reference for the settings they read.
SyncState testSyncState() => SyncState(
  rootIsolateToken: 'test-token',
  securityContext: const StoredSecurityContext(
    privateKey: 'private-key',
    publicKey: 'public-key',
    certificate: 'certificate',
    certificateHash: 'certificate-hash',
  ),
  deviceInfo: DeviceInfoResult(
    deviceType: DeviceType.mobile,
    deviceModel: null,
    androidSdkInt: null,
  ),
  alias: 'old-alias',
  port: 53317,
  networkWhitelist: null,
  networkBlacklist: null,
  protocol: ProtocolType.https,
  multicastGroup: '224.0.0.168',
  discoveryTimeout: 500,
  serverRunning: true,
  download: false,
);

void main() {
  late MockPersistenceService persistence;
  late RefenaContainer container;

  setUp(() {
    persistence = MockPersistenceService();
    when(persistence.isPortableMode()).thenReturn(false);
    container = RefenaContainer(
      overrides: [
        persistenceProvider.overrideWithValue(persistence),
        // The network setters push into the isolates as soon as they run, so every container needs
        // the parent isolate it dispatches to.
        parentIsolateProvider.overrideWithNotifier(
          (ref) => IsolateController(initialState: ParentIsolateState.initial(testSyncState())),
        ),
      ],
    );
  });

  SettingsState currentState() => container.read(settingsProvider);

  // Every stored setting must survive "persisted value -> SettingsState" and every setter must
  // write it back. A setting wired into only one half fails one of these tests.
  group('init', () {
    test('reads every persisted setting', () {
      when(persistence.getShowToken()).thenReturn('token-1');
      when(persistence.getAlias()).thenReturn('alias-1');
      when(persistence.getTheme()).thenReturn(ThemeMode.dark);
      when(persistence.getColorMode()).thenReturn(ColorMode.oled);
      when(persistence.getCustomColor()).thenReturn(const Color(0xFF123456));
      when(persistence.getLocale()).thenReturn(AppLocale.zhCn);
      when(persistence.getPort()).thenReturn(42000);
      when(persistence.getNetworkWhitelist()).thenReturn(['192.168.0.0/24']);
      when(persistence.getNetworkBlacklist()).thenReturn(['10.0.0.1']);
      when(persistence.getMulticastGroup()).thenReturn('239.1.2.3');
      when(persistence.getDestination()).thenReturn('/tmp/sonar');
      when(persistence.isSaveToGallery()).thenReturn(false);
      when(persistence.isSaveToHistory()).thenReturn(false);
      when(persistence.getQuickSave()).thenReturn(QuickSaveMode.paired);
      when(persistence.getReceivePin()).thenReturn('1234');
      when(persistence.isAutoFinish()).thenReturn(true);
      when(persistence.isMinimizeToTray()).thenReturn(false);
      when(persistence.isHttps()).thenReturn(false);
      when(persistence.getSaveWindowPlacement()).thenReturn(false);
      when(persistence.getAlwaysOnTop()).thenReturn(true);
      when(persistence.getEnableAnimations()).thenReturn(false);
      when(persistence.getDeviceType()).thenReturn(DeviceType.tablet);
      when(persistence.getDeviceModel()).thenReturn('Pixel');
      when(persistence.getShareViaLinkAutoAccept()).thenReturn(true);
      when(persistence.getReceiveViaLinkAutoAccept()).thenReturn(true);
      when(persistence.getCreateChecksums()).thenReturn(false);
      when(persistence.getVerifyChecksums()).thenReturn(false);
      when(persistence.getDiscoveryTimeout()).thenReturn(5000);
      when(persistence.getNearbyLayout()).thenReturn(NearbyLayout.grid);

      final state = currentState();

      expect(state.showToken, 'token-1');
      expect(state.alias, 'alias-1');
      expect(state.theme, ThemeMode.dark);
      expect(state.colorMode, ColorMode.oled);
      expect(state.customColor, const Color(0xFF123456));
      expect(state.locale, AppLocale.zhCn);
      expect(state.port, 42000);
      expect(state.networkWhitelist, ['192.168.0.0/24']);
      expect(state.networkBlacklist, ['10.0.0.1']);
      expect(state.multicastGroup, '239.1.2.3');
      expect(state.destination, '/tmp/sonar');
      expect(state.saveToGallery, isFalse);
      expect(state.saveToHistory, isFalse);
      expect(state.quickSave, isFalse);
      expect(state.quickSaveFromFavorites, isTrue);
      expect(state.receivePin, '1234');
      expect(state.autoFinish, isTrue);
      expect(state.minimizeToTray, isFalse);
      expect(state.https, isFalse);
      expect(state.saveWindowPlacement, isFalse);
      expect(state.alwaysOnTop, isTrue);
      expect(state.enableAnimations, isFalse);
      expect(state.deviceType, DeviceType.tablet);
      expect(state.deviceModel, 'Pixel');
      expect(state.shareViaLinkAutoAccept, isTrue);
      expect(state.receiveViaLinkAutoAccept, isTrue);
      expect(state.createChecksums, isFalse);
      expect(state.verifyChecksums, isFalse);
      expect(state.discoveryTimeout, 5000);
      expect(state.nearbyLayout, NearbyLayout.grid);
    });
  });

  group('setters', () {
    final cases = <_SettingCase>[
      _SettingCase(
        name: 'alias',
        apply: (service) => service.setAlias('new-alias'),
        verifyPersisted: () => verify(persistence.setAlias('new-alias')),
        read: (state) => state.alias,
        expected: 'new-alias',
      ),
      _SettingCase(
        name: 'theme',
        apply: (service) => service.setTheme(ThemeMode.dark),
        verifyPersisted: () => verify(persistence.setTheme(ThemeMode.dark)),
        read: (state) => state.theme,
        expected: ThemeMode.dark,
      ),
      _SettingCase(
        name: 'colorMode',
        apply: (service) => service.setColorMode(ColorMode.custom),
        verifyPersisted: () => verify(persistence.setColorMode(ColorMode.custom)),
        read: (state) => state.colorMode,
        expected: ColorMode.custom,
      ),
      _SettingCase(
        name: 'customColor',
        apply: (service) => service.setCustomColor(const Color(0xFF336699)),
        verifyPersisted: () => verify(persistence.setCustomColor(const Color(0xFF336699))),
        read: (state) => state.customColor,
        expected: const Color(0xFF336699),
      ),
      _SettingCase(
        name: 'nearbyLayout',
        apply: (service) => service.setNearbyLayout(NearbyLayout.grid),
        verifyPersisted: () => verify(persistence.setNearbyLayout(NearbyLayout.grid)),
        read: (state) => state.nearbyLayout,
        expected: NearbyLayout.grid,
      ),
      _SettingCase(
        name: 'locale',
        apply: (service) => service.setLocale(AppLocale.zhCn),
        verifyPersisted: () => verify(persistence.setLocale(AppLocale.zhCn)),
        read: (state) => state.locale,
        expected: AppLocale.zhCn,
      ),
      _SettingCase(
        name: 'port',
        apply: (service) => service.setPort(42000),
        verifyPersisted: () => verify(persistence.setPort(42000)),
        read: (state) => state.port,
        expected: 42000,
      ),
      _SettingCase(
        name: 'networkWhitelist',
        apply: (service) => service.setNetworkWhitelist(['192.168.0.0/24']),
        verifyPersisted: () => verify(persistence.setNetworkWhitelist(['192.168.0.0/24'])),
        read: (state) => state.networkWhitelist,
        expected: ['192.168.0.0/24'],
      ),
      _SettingCase(
        name: 'networkBlacklist (cleared)',
        apply: (service) => service.setNetworkBlacklist(null),
        verifyPersisted: () => verify(persistence.setNetworkBlacklist(null)),
        read: (state) => state.networkBlacklist,
        expected: null,
      ),
      _SettingCase(
        name: 'discoveryTimeout',
        apply: (service) => service.setDiscoveryTimeout(5000),
        verifyPersisted: () => verify(persistence.setDiscoveryTimeout(5000)),
        read: (state) => state.discoveryTimeout,
        expected: 5000,
      ),
      _SettingCase(
        name: 'multicastGroup',
        apply: (service) => service.setMulticastGroup('239.1.2.3'),
        verifyPersisted: () => verify(persistence.setMulticastGroup('239.1.2.3')),
        read: (state) => state.multicastGroup,
        expected: '239.1.2.3',
      ),
      _SettingCase(
        name: 'destination',
        apply: (service) => service.setDestination('/tmp/sonar'),
        verifyPersisted: () => verify(persistence.setDestination('/tmp/sonar')),
        read: (state) => state.destination,
        expected: '/tmp/sonar',
      ),
      _SettingCase(
        name: 'saveToGallery',
        apply: (service) => service.setSaveToGallery(false),
        verifyPersisted: () => verify(persistence.setSaveToGallery(false)),
        read: (state) => state.saveToGallery,
        expected: false,
      ),
      _SettingCase(
        name: 'saveToHistory',
        apply: (service) => service.setSaveToHistory(false),
        verifyPersisted: () => verify(persistence.setSaveToHistory(false)),
        read: (state) => state.saveToHistory,
        expected: false,
      ),
      _SettingCase(
        name: 'receivePin',
        apply: (service) => service.setReceivePin('9876'),
        verifyPersisted: () => verify(persistence.setReceivePin('9876')),
        read: (state) => state.receivePin,
        expected: '9876',
      ),
      _SettingCase(
        name: 'autoFinish',
        apply: (service) => service.setAutoFinish(true),
        verifyPersisted: () => verify(persistence.setAutoFinish(true)),
        read: (state) => state.autoFinish,
        expected: true,
      ),
      _SettingCase(
        name: 'minimizeToTray',
        apply: (service) => service.setMinimizeToTray(true),
        verifyPersisted: () => verify(persistence.setMinimizeToTray(true)),
        read: (state) => state.minimizeToTray,
        expected: true,
      ),
      _SettingCase(
        name: 'https',
        apply: (service) => service.setHttps(false),
        verifyPersisted: () => verify(persistence.setHttps(false)),
        read: (state) => state.https,
        expected: false,
      ),
      _SettingCase(
        name: 'saveWindowPlacement',
        apply: (service) => service.setSaveWindowPlacement(false),
        verifyPersisted: () => verify(persistence.setSaveWindowPlacement(false)),
        read: (state) => state.saveWindowPlacement,
        expected: false,
      ),
      _SettingCase(
        name: 'alwaysOnTop',
        apply: (service) => service.setAlwaysOnTop(true),
        verifyPersisted: () => verify(persistence.setAlwaysOnTop(true)),
        read: (state) => state.alwaysOnTop,
        expected: true,
      ),
      _SettingCase(
        name: 'enableAnimations',
        apply: (service) => service.setEnableAnimations(false),
        verifyPersisted: () => verify(persistence.setEnableAnimations(false)),
        read: (state) => state.enableAnimations,
        expected: false,
      ),
      _SettingCase(
        name: 'deviceType',
        apply: (service) => service.setDeviceType(DeviceType.tablet),
        verifyPersisted: () => verify(persistence.setDeviceType(DeviceType.tablet)),
        read: (state) => state.deviceType,
        expected: DeviceType.tablet,
      ),
      _SettingCase(
        name: 'deviceModel',
        apply: (service) => service.setDeviceModel('Pixel'),
        verifyPersisted: () => verify(persistence.setDeviceModel('Pixel')),
        read: (state) => state.deviceModel,
        expected: 'Pixel',
      ),
      _SettingCase(
        name: 'shareViaLinkAutoAccept',
        apply: (service) => service.setShareViaLinkAutoAccept(true),
        verifyPersisted: () => verify(persistence.setShareViaLinkAutoAccept(true)),
        read: (state) => state.shareViaLinkAutoAccept,
        expected: true,
      ),
      _SettingCase(
        name: 'receiveViaLinkAutoAccept',
        apply: (service) => service.setReceiveViaLinkAutoAccept(true),
        verifyPersisted: () => verify(persistence.setReceiveViaLinkAutoAccept(true)),
        read: (state) => state.receiveViaLinkAutoAccept,
        expected: true,
      ),
      _SettingCase(
        name: 'createChecksums',
        apply: (service) => service.setCreateChecksums(false),
        verifyPersisted: () => verify(persistence.setCreateChecksums(false)),
        read: (state) => state.createChecksums,
        expected: false,
      ),
      _SettingCase(
        name: 'verifyChecksums',
        apply: (service) => service.setVerifyChecksums(false),
        verifyPersisted: () => verify(persistence.setVerifyChecksums(false)),
        read: (state) => state.verifyChecksums,
        expected: false,
      ),
    ];

    for (final setting in cases) {
      test('persists and applies ${setting.name}', () async {
        final service = container.notifier(settingsProvider);

        await setting.apply(service);

        setting.verifyPersisted();
        expect(setting.read(currentState()), setting.expected);
      });
    }
  });

  group('clamping', () {
    test('setPort clamps to the bindable TCP range', () async {
      final service = container.notifier(settingsProvider);

      await service.setPort(0);
      expect(currentState().port, minPort);
      verify(persistence.setPort(minPort));

      await service.setPort(70000);
      expect(currentState().port, maxPort);
      verify(persistence.setPort(maxPort));
    });

    test('setDiscoveryTimeout clamps to the supported range', () async {
      final service = container.notifier(settingsProvider);

      await service.setDiscoveryTimeout(0);
      expect(currentState().discoveryTimeout, minDiscoveryTimeout);
      verify(persistence.setDiscoveryTimeout(minDiscoveryTimeout));

      await service.setDiscoveryTimeout(999999);
      expect(currentState().discoveryTimeout, maxDiscoveryTimeout);
      verify(persistence.setDiscoveryTimeout(maxDiscoveryTimeout));
    });
  });

  group('quick save', () {
    // The service reads the current mode back before writing, so the stub has to remember writes.
    late QuickSaveMode storedQuickSave;

    setUp(() {
      storedQuickSave = QuickSaveMode.off;
      when(persistence.getQuickSave()).thenAnswer((_) => storedQuickSave);
      when(persistence.setQuickSave(any)).thenAnswer((invocation) async {
        storedQuickSave = invocation.positionalArguments[0] as QuickSaveMode;
      });
    });
    test('enabling quick save turns on the full mode', () async {
      final service = container.notifier(settingsProvider);

      await service.setQuickSave(true);

      verify(persistence.setQuickSave(QuickSaveMode.on));
      expect(currentState().quickSave, isTrue);
      expect(currentState().quickSaveFromFavorites, isFalse);
    });

    test('enabling favorites only turns on the paired mode', () async {
      final service = container.notifier(settingsProvider);

      await service.setQuickSaveFromFavorites(true);

      verify(persistence.setQuickSave(QuickSaveMode.paired));
      expect(currentState().quickSave, isFalse);
      expect(currentState().quickSaveFromFavorites, isTrue);
    });

    test('the two flags replace each other instead of both being on', () async {
      final service = container.notifier(settingsProvider);

      await service.setQuickSave(true);
      await service.setQuickSaveFromFavorites(true);

      expect(currentState().quickSave, isFalse);
      expect(currentState().quickSaveFromFavorites, isTrue);
      expect(currentState().quickSave || currentState().quickSaveFromFavorites, isTrue);
    });

    test('disabling one flag keeps the other mode intact', () async {
      final service = container.notifier(settingsProvider);

      await service.setQuickSave(true);
      await service.setQuickSaveFromFavorites(false);

      verifyNever(persistence.setQuickSave(QuickSaveMode.off));
      expect(currentState().quickSave, isTrue);
      expect(currentState().quickSaveFromFavorites, isFalse);
    });

    test('disabling the active flag falls back to off', () async {
      final service = container.notifier(settingsProvider);

      await service.setQuickSaveFromFavorites(true);
      await service.setQuickSaveFromFavorites(false);

      verify(persistence.setQuickSave(QuickSaveMode.off));
      expect(currentState().quickSave, isFalse);
      expect(currentState().quickSaveFromFavorites, isFalse);
    });
  });

  // The child isolates read these settings from their own copy of the sync state, so a change that
  // is never pushed leaves discovery and the server on the old value until the app restarts.
  group('isolate sync', () {
    late RefenaContainer isolateContainer;

    setUp(() {
      // The settings state is read back from persistence, so it has to start out matching the
      // sync state; otherwise every unrelated setter looks like a sync-worthy change.
      when(persistence.getMulticastGroup()).thenReturn('224.0.0.168');
      when(persistence.getDiscoveryTimeout()).thenReturn(500);
      isolateContainer = RefenaContainer(
        overrides: [
          persistenceProvider.overrideWithValue(persistence),
          parentIsolateProvider.overrideWithNotifier(
            (ref) => IsolateController(initialState: ParentIsolateState.initial(testSyncState())),
          ),
        ],
      );
    });

    SyncState syncState() => isolateContainer.read(parentIsolateProvider).syncState;

    test('pushes the settings the children read', () async {
      final service = isolateContainer.notifier(settingsProvider);

      await service.setMulticastGroup('239.1.2.3');
      await service.setDiscoveryTimeout(5000);
      await service.setNetworkWhitelist(['192.168.0.0/24']);
      await service.setNetworkBlacklist(['10.0.0.1']);

      expect(syncState().multicastGroup, '239.1.2.3');
      expect(syncState().discoveryTimeout, 5000);
      expect(syncState().networkWhitelist, ['192.168.0.0/24']);
      expect(syncState().networkBlacklist, ['10.0.0.1']);
    });

    test('clearing a network list is pushed as null', () async {
      final service = isolateContainer.notifier(settingsProvider);

      await service.setNetworkWhitelist(['192.168.0.0/24']);
      await service.setNetworkWhitelist(null);

      expect(syncState().networkWhitelist, isNull);
    });

    test('settings the children do not read leave the sync state untouched', () async {
      final service = isolateContainer.notifier(settingsProvider);
      final before = syncState();

      await service.setAlias('new-alias');
      await service.setPort(42000);
      await service.setHttps(false);
      await service.setEnableAnimations(false);

      expect(identical(syncState(), before), isTrue);
    });
  });
}
