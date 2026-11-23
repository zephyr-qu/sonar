import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/persistence/color_mode.dart';
import 'package:sonar/model/persistence/favorite_device.dart';
import 'package:sonar/model/persistence/nearby_layout.dart';
import 'package:sonar/model/persistence/quick_save_mode.dart';
import 'package:sonar/model/persistence/transfer_history_session.dart';
import 'package:sonar/provider/window_dimensions_provider.dart';
import 'package:sonar/util/alias_generator.dart';
import 'package:sonar/util/native/autostart_helper.dart';
import 'package:sonar/util/native/context_menu_helper.dart';
import 'package:sonar/util/native/platform_check.dart';
import 'package:sonar/util/security_helper.dart';
import 'package:sonar/util/shared_preferences/shared_preferences_file.dart';
import 'package:sonar/util/shared_preferences/shared_preferences_portable.dart';
import 'package:sonar/util/ui/animations_status.dart';
import 'package:sonar_isolates/constants.dart';
import 'package:sonar_isolates/model/device.dart';
import 'package:sonar_isolates/model/file_type.dart';
import 'package:sonar_isolates/model/stored_security_context.dart';
import 'package:uuid/uuid.dart';

part 'persistence_provider_migrations.dart';

final _logger = Logger('PersistenceService');

String get _windowsFile {
  final appData = Platform.environment['APPDATA'];
  return '$appData\\Sonar\\settings.json';
}

String get _windowsLegacyFile {
  final appData = Platform.environment['APPDATA'];
  return '$appData\\org.localsend\\localsend_app\\shared_preferences.json';
}

// Version of the storage
const _version = 'ls_version';

// Security keys (generated on first app start)
const _securityContext = 'ls_security_context';

// WebRTC
const _signalingServers = 'ls_signaling_servers';
const _stunServers = 'ls_stun_servers';

// Transfer history, one entry per finished session
const _transferHistory = 'ls_transfer_history';

// Favorites
const _favorites = 'ls_favorites';

// Last time each device fingerprint was confirmed on the network
const _deviceLastSeen = 'ls_device_last_seen';

// App Window Offset and Size info
const _windowOffsetX = 'ls_window_offset_x';
const _windowOffsetY = 'ls_window_offset_y';
const _windowWidth = 'ls_window_width';
const _windowHeight = 'ls_window_height';
const _saveWindowPlacement = 'ls_save_window_placement';
const _alwaysOnTop = 'ls_always_on_top';

// Settings
const _showToken = 'ls_show_token';
const _aliasKey = 'ls_alias';
const _themeKey = 'ls_theme'; // now called brightness
const _colorKey = 'ls_color';
const _customColorKey = 'ls_custom_color'; // RRGGBB hex, used by ColorMode.custom
const _localeKey = 'ls_locale';
const _portKey = 'ls_port';
const _networkWhitelistKey = 'ls_network_whitelist';
const _networkBlacklistKey = 'ls_network_blacklist';
const _timeoutKey = 'ls_timeout';
const _multicastGroupKey = 'ls_multicast_group';
const _destinationKey = 'ls_destination';
const _saveToGallery = 'ls_save_to_gallery';
const _saveToHistory = 'ls_save_to_history';
const _quickSave = 'ls_quick_save'; // a QuickSaveMode; was a bool until storage version 2 ('ls_quick_save_from_favorites' is merged into this key)
const _receivePin = 'ls_receive_pin';
const _autoFinish = 'ls_auto_finish';
const _minimizeToTray = 'ls_minimize_to_tray';
const _https = 'ls_https';
// Versioned on purpose: the redesign makes the radar the default, so bumping the key drops a
// stale grid choice once (the old `ls_nearby_layout` value is simply ignored). After that the
// user's own choice persists under this key.
const _nearbyLayout = 'ls_nearby_layout_v2';
const _enableAnimations = 'ls_enable_animations';
const _deviceType = 'ls_device_type';
const _deviceModel = 'ls_device_model';
const _shareViaLinkAutoAccept = 'ls_share_via_link_auto_accept';
const _receiveViaLinkAutoAccept = 'ls_receive_via_link_auto_accept';
const _createChecksums = 'ls_create_checksums';
const _verifyChecksums = 'ls_verify_checksums';
const _whatsNewKey = 'ls_whats_new';

final persistenceProvider = Provider<PersistenceService>((ref) {
  throw Exception('persistenceProvider not initialized');
});

/// This service abstracts the persistence layer.
/// Parses the persisted `NearbyLayout` name.
///
/// Unknown or missing values (older installations) fall back to the radar: it is the layout the
/// "signal" redesign is built around. An explicit choice is always respected.
NearbyLayout parseNearbyLayout(String? name) {
  return NearbyLayout.values.firstWhereOrNull((layout) => layout.name == name) ?? NearbyLayout.radar;
}

class PersistenceService {
  final SharedPreferences _prefs;
  final bool isFirstAppStart;

  /// Decoded once in [initialize], so that a corrupted value is repaired there instead of failing
  /// every startup. The security context is a derived device identity, not user data.
  StoredSecurityContext _securityContextValue;

  PersistenceService._(this._prefs, this.isFirstAppStart, this._securityContextValue);

  static Future<PersistenceService> initialize() async {
    SharedPreferences prefs;

    final portableStore = SharedPreferencesPortable();
    bool usingLegacyStore = false;
    if (checkPlatform(const [TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS]) && portableStore.exists()) {
      _logger.info('Using portable settings.');
      SharedPreferencesStorePlatform.instance = portableStore;
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      final legacyStore = SharedPreferencesFile(filePath: _windowsLegacyFile);
      if (legacyStore.exists()) {
        _logger.info('Using legacy settings. Will migrate in the next step.');
        SharedPreferencesStorePlatform.instance = legacyStore;
        usingLegacyStore = true;
      } else {
        SharedPreferencesStorePlatform.instance = SharedPreferencesFile(filePath: _windowsFile);
      }
    }

    final bool isFirstAppStart;
    final existingPrefs = await SharedPreferencesStorePlatform.instance.getAll();
    final existingVersion = existingPrefs['flutter.$_version'] as int?;
    _logger.info('Existing version: $existingVersion');
    isFirstAppStart = existingVersion == null && !usingLegacyStore && !existingPrefs.keys.any((key) => key.startsWith('flutter.ls_'));
    if (isFirstAppStart) {
      await SharedPreferencesStorePlatform.instance.setValue('Int', 'flutter.$_version', _latestVersion);
    } else {
      // Unversioned profiles in the current store may already contain string modes.
      // Only apply the repair migration; older migrations would replace those modes.
      final fromVersion = existingVersion ?? (usingLegacyStore ? 1 : 3);
      if (fromVersion < _latestVersion) {
        await _runMigrations(fromVersion);
      }
    }

    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      if (checkPlatform([TargetPlatform.windows])) {
        _logger.info('Could not initialize SharedPreferences, trying to delete corrupted settings file', e);
        File(_windowsFile).deleteSync();
        prefs = await SharedPreferences.getInstance();
      } else {
        throw Exception('Could not initialize SharedPreferences');
      }
    }

    // Locale configuration upon persistence initialisation to prevent unlocalised Alias generation
    final persistedLocale = prefs.getString(_localeKey);
    if (persistedLocale == null) {
      await LocaleSettings.useDeviceLocale();
    } else {
      await LocaleSettings.setLocaleRaw(persistedLocale);
    }

    if (prefs.getString(_showToken) == null) {
      await prefs.setString(_showToken, const Uuid().v4());
    }

    if (prefs.getString(_aliasKey) == null) {
      await prefs.setString(_aliasKey, generateRandomAlias());
    }

    // A corrupted or incompatible (schema changed) security context must not brick the app: it is
    // regenerated, and peers simply see this device as a new one.
    final storedSecurityContext = prefs.getString(_securityContext);
    var securityContext = _decodeOrNull<StoredSecurityContext>(
      storedSecurityContext,
      (json) => StoredSecurityContext.fromJson(json as Map<String, dynamic>),
    );
    if (securityContext == null) {
      if (storedSecurityContext != null) {
        _logger.warning('Security context is unreadable, generating a new one');
      }
      securityContext = await generateSecurityContext();
      await prefs.setString(_securityContext, jsonEncode(securityContext));
    }

    if (isFirstAppStart) {
      final systemAnimations = await getSystemAnimationsStatus();
      if (!systemAnimations) {
        _logger.info('System animations are disabled, disabling animations in the app.');
        await prefs.setBool(_enableAnimations, false);
      }
    }

    if (prefs.getString(_colorKey) == null) {
      await _initColorSetting(prefs);
    }

    // migrate legacy auto start settings (current implementation is stateless and relies on the Windows registry / file system)
    const launchAtStartupLegacyKey = 'ls_launch_at_startup';
    const launchMinimizedLegacyKey = 'ls_auto_start_launch_minimized';
    if (prefs.getBool(launchAtStartupLegacyKey) == true) {
      _logger.info('Enable auto start on legacy settings');
      await prefs.remove(launchAtStartupLegacyKey);
      await enableAutoStart(startHidden: prefs.getBool(launchMinimizedLegacyKey) == true);
      await prefs.remove(launchMinimizedLegacyKey);
    }

    return PersistenceService._(prefs, isFirstAppStart, securityContext);
  }

  static Future<void> _initColorSetting(SharedPreferences prefs) async {
    await prefs.setString(_colorKey, ColorMode.localsend.name);
  }

  bool isPortableMode() {
    return SharedPreferencesStorePlatform.instance is SharedPreferencesPortable;
  }

  /// Parses a persisted JSON document, returning `null` when it is unreadable.
  ///
  /// Startup reads happen before any error UI exists and are not awaited by a global handler, so a
  /// single corrupted value (interrupted write, full disk, old schema) would otherwise break every
  /// launch. Callers treat `null` as "not set" and fall back to a default or regenerate the value.
  static T? _decodeOrNull<T>(String? raw, T Function(dynamic) parse) {
    if (raw == null) {
      return null;
    }

    try {
      return parse(jsonDecode(raw));
    } catch (e) {
      _logger.warning('Discarding unreadable persisted value', e);
      return null;
    }
  }

  static List<String> _parseStringList(dynamic json) => List<String>.from(json as List);

  /// Decodes stores where every list entry is its own JSON document, dropping unreadable entries.
  ///
  /// Returns the readable entries and whether anything was dropped, so the caller can heal the store.
  static (List<T>, bool) _decodeEntries<T>(List<String> raw, T Function(dynamic) parse) {
    final entries = <T>[];
    var dropped = false;
    for (final entry in raw) {
      final decoded = _decodeOrNull<T>(entry, parse);
      if (decoded == null) {
        dropped = true;
        continue;
      }
      entries.add(decoded);
    }
    return (entries, dropped);
  }

  StoredSecurityContext getSecurityContext() => _securityContextValue;

  Future<void> setSecurityContext(StoredSecurityContext context) async {
    _securityContextValue = context;
    await _prefs.setString(_securityContext, jsonEncode(context));
  }

  List<String>? getSignalingServers() => _decodeOrNull(_prefs.getString(_signalingServers), _parseStringList);

  Future<void> setSignalingServers(List<String> servers) async {
    await _prefs.setString(_signalingServers, jsonEncode(servers));
  }

  List<String>? getStunServers() => _decodeOrNull(_prefs.getString(_stunServers), _parseStringList);

  Future<void> setStunServers(List<String> servers) async {
    await _prefs.setString(_stunServers, jsonEncode(servers));
  }

  List<TransferHistorySession> getTransferHistory() {
    final historyRaw = _prefs.getStringList(_transferHistory) ?? const [];
    final (sessions, dropped) = _decodeEntries<TransferHistorySession>(
      historyRaw,
      (json) => TransferHistorySession.fromJson(json as Map<String, dynamic>),
    );
    if (dropped) {
      // Heal the store so the corruption does not resurface on every start.
      unawaited(setTransferHistory(sessions));
    }
    return sessions;
  }

  Future<void> setTransferHistory(List<TransferHistorySession> sessions) async {
    final historyRaw = sessions.map((session) => jsonEncode(session.toJson())).toList();
    await _prefs.setStringList(_transferHistory, historyRaw);
  }

  Map<String, DateTime> getDeviceLastSeen() {
    final raw = _prefs.getString(_deviceLastSeen);
    final decoded = _decodeOrNull<Map<String, dynamic>>(raw, (json) => Map<String, dynamic>.from(json as Map));
    if (decoded == null) {
      if (raw != null) {
        unawaited(setDeviceLastSeen({}));
      }
      return {};
    }

    final entries = <String, DateTime>{};
    decoded.forEach((fingerprint, value) {
      final time = value is String ? DateTime.tryParse(value) : null;
      if (time != null) {
        entries[fingerprint] = time;
      }
    });
    if (entries.length != decoded.length) {
      unawaited(setDeviceLastSeen(entries));
    }
    return entries;
  }

  Future<void> setDeviceLastSeen(Map<String, DateTime> entries) async {
    await _prefs.setString(_deviceLastSeen, jsonEncode(entries.map((fingerprint, time) => MapEntry(fingerprint, time.toIso8601String()))));
  }

  List<FavoriteDevice> getFavorites() {
    final favoritesRaw = _prefs.getStringList(_favorites) ?? const [];
    final (favorites, dropped) = _decodeEntries<FavoriteDevice>(favoritesRaw, (json) => FavoriteDevice.fromJson(json as Map<String, dynamic>));
    if (dropped) {
      unawaited(setFavorites(favorites));
    }
    return favorites;
  }

  Future<void> setFavorites(List<FavoriteDevice> entries) async {
    final favoritesRaw = entries.map((entry) => jsonEncode(entry.toJson())).toList();
    await _prefs.setStringList(_favorites, favoritesRaw);
  }

  String getShowToken() {
    return _prefs.getString(_showToken)!;
  }

  String getAlias() {
    return _prefs.getString(_aliasKey) ?? generateRandomAlias();
  }

  Future<void> setAlias(String alias) async {
    await _prefs.setString(_aliasKey, alias);
  }

  ThemeMode getTheme() {
    final value = _prefs.getString(_themeKey);
    if (value == null) {
      return _defaultTheme;
    }
    return ThemeMode.values.firstWhereOrNull((theme) => theme.name == value) ?? _defaultTheme;
  }

  /// The theme before the user has picked one (and the fallback for an
  /// unreadable value): desktop is dark-first, so it opens in the dark palette
  /// even when the OS is in light mode, while mobile follows the system.
  ThemeMode get _defaultTheme => checkPlatformIsDesktop() ? ThemeMode.dark : ThemeMode.system;

  Future<void> setTheme(ThemeMode theme) async {
    await _prefs.setString(_themeKey, theme.name);
  }

  ColorMode getColorMode() {
    final value = _prefs.getString(_colorKey);
    if (value == null) {
      return ColorMode.localsend;
    }
    return ColorMode.values.firstWhereOrNull((color) => color.name == value) ?? ColorMode.localsend;
  }

  Future<void> setColorMode(ColorMode color) async {
    await _prefs.setString(_colorKey, color.name);
  }

  Color getCustomColor() {
    final value = _prefs.getString(_customColorKey);
    final rgb = value == null ? null : int.tryParse(value, radix: 16);
    if (rgb == null) {
      return Colors.teal;
    }
    return Color(0xff000000 | rgb);
  }

  Future<void> setCustomColor(Color color) async {
    await _prefs.setString(_customColorKey, color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2));
  }

  AppLocale? getLocale() {
    final value = _prefs.getString(_localeKey);
    if (value == null) {
      return null;
    }
    return AppLocale.values.firstWhereOrNull((locale) => locale.languageTag == value);
  }

  Future<void> setLocale(AppLocale? locale) async {
    if (locale == null) {
      await _prefs.remove(_localeKey);
    } else {
      await _prefs.setString(_localeKey, locale.languageTag);
    }
  }

  int getPort() {
    return _prefs.getInt(_portKey) ?? defaultPort;
  }

  Future<void> setPort(int port) async {
    await _prefs.setInt(_portKey, port);
  }

  List<String>? getNetworkWhitelist() {
    return _prefs.getStringList(_networkWhitelistKey);
  }

  Future<void> setNetworkWhitelist(List<String>? whitelist) async {
    if (whitelist == null) {
      await _prefs.remove(_networkWhitelistKey);
    } else {
      await _prefs.setStringList(_networkWhitelistKey, whitelist);
    }
  }

  List<String>? getNetworkBlacklist() {
    return _prefs.getStringList(_networkBlacklistKey);
  }

  Future<void> setNetworkBlacklist(List<String>? blacklist) async {
    if (blacklist == null) {
      await _prefs.remove(_networkBlacklistKey);
    } else {
      await _prefs.setStringList(_networkBlacklistKey, blacklist);
    }
  }

  int getDiscoveryTimeout() {
    return _prefs.getInt(_timeoutKey) ?? defaultDiscoveryTimeout;
  }

  Future<void> setDiscoveryTimeout(int timeout) async {
    await _prefs.setInt(_timeoutKey, timeout);
  }

  bool getShareViaLinkAutoAccept() {
    return _prefs.getBool(_shareViaLinkAutoAccept) ?? false;
  }

  Future<void> setShareViaLinkAutoAccept(bool shareViaLinkAutoAccept) async {
    await _prefs.setBool(_shareViaLinkAutoAccept, shareViaLinkAutoAccept);
  }

  bool getReceiveViaLinkAutoAccept() {
    return _prefs.getBool(_receiveViaLinkAutoAccept) ?? false;
  }

  Future<void> setReceiveViaLinkAutoAccept(bool receiveViaLinkAutoAccept) async {
    await _prefs.setBool(_receiveViaLinkAutoAccept, receiveViaLinkAutoAccept);
  }

  bool getCreateChecksums() {
    return _prefs.getBool(_createChecksums) ?? true;
  }

  Future<void> setCreateChecksums(bool createChecksums) async {
    await _prefs.setBool(_createChecksums, createChecksums);
  }

  bool getVerifyChecksums() {
    return _prefs.getBool(_verifyChecksums) ?? true;
  }

  Future<void> setVerifyChecksums(bool verifyChecksums) async {
    await _prefs.setBool(_verifyChecksums, verifyChecksums);
  }

  String getMulticastGroup() {
    return _prefs.getString(_multicastGroupKey) ?? defaultMulticastGroup;
  }

  Future<void> setMulticastGroup(String group) async {
    await _prefs.setString(_multicastGroupKey, group);
  }

  String? getDestination() {
    return _prefs.getString(_destinationKey);
  }

  Future<void> setDestination(String? destination) async {
    if (destination == null) {
      await _prefs.remove(_destinationKey);
    } else {
      await _prefs.setString(_destinationKey, destination);
    }
  }

  bool isSaveToGallery() {
    return _prefs.getBool(_saveToGallery) ?? true;
  }

  Future<void> setSaveToGallery(bool saveToGallery) async {
    await _prefs.setBool(_saveToGallery, saveToGallery);
  }

  bool isSaveToHistory() {
    return _prefs.getBool(_saveToHistory) ?? true;
  }

  Future<void> setSaveToHistory(bool saveToHistory) async {
    await _prefs.setBool(_saveToHistory, saveToHistory);
  }

  QuickSaveMode getQuickSave() {
    final value = _prefs.getString(_quickSave);
    return QuickSaveMode.values.firstWhereOrNull((mode) => mode.name == value) ?? QuickSaveMode.paired;
  }

  Future<void> setQuickSave(QuickSaveMode mode) async {
    await _prefs.setString(_quickSave, mode.name);
  }

  String? getReceivePin() {
    return _prefs.getString(_receivePin);
  }

  Future<void> setReceivePin(String? pin) async {
    if (pin == null) {
      await _prefs.remove(_receivePin);
    } else {
      await _prefs.setString(_receivePin, pin);
    }
  }

  bool isAutoFinish() {
    return _prefs.getBool(_autoFinish) ?? false;
  }

  Future<void> setAutoFinish(bool autoFinish) async {
    await _prefs.setBool(_autoFinish, autoFinish);
  }

  bool isMinimizeToTray() {
    return _prefs.getBool(_minimizeToTray) ?? false;
  }

  Future<void> setMinimizeToTray(bool minimizeToTray) async {
    await _prefs.setBool(_minimizeToTray, minimizeToTray);
  }

  bool isHttps() {
    return _prefs.getBool(_https) ?? true;
  }

  Future<void> setHttps(bool https) async {
    await _prefs.setBool(_https, https);
  }

  NearbyLayout getNearbyLayout() {
    return parseNearbyLayout(_prefs.getString(_nearbyLayout));
  }

  Future<void> setNearbyLayout(NearbyLayout layout) async {
    await _prefs.setString(_nearbyLayout, layout.name);
  }

  Future<void> setWindowOffsetX(double x) async {
    await _prefs.setDouble(_windowOffsetX, x);
  }

  Future<void> setWindowOffsetY(double y) async {
    await _prefs.setDouble(_windowOffsetY, y);
  }

  Future<void> setWindowHeight(double height) async {
    await _prefs.setDouble(_windowHeight, height);
  }

  Future<void> setWindowWidth(double width) async {
    await _prefs.setDouble(_windowWidth, width);
  }

  WindowDimensions? getWindowLastDimensions() {
    Size? size;
    Offset? position;
    final offsetX = _prefs.getDouble(_windowOffsetX);
    final offsetY = _prefs.getDouble(_windowOffsetY);
    final width = _prefs.getDouble(_windowWidth);
    final height = _prefs.getDouble(_windowHeight);

    if (width != null && height != null) {
      size = Size(width, height);
    }

    if (offsetX != null && offsetY != null) {
      position = Offset(offsetX, offsetY);
    }

    if (size == null || position == null) {
      return null;
    }

    return WindowDimensions(
      position: position,
      size: size,
    );
  }

  Future<void> setSaveWindowPlacement(bool savePlacement) async {
    await _prefs.setBool(_saveWindowPlacement, savePlacement);
  }

  bool getSaveWindowPlacement() {
    if (!checkPlatformIsNotWaylandDesktop()) return false;
    return _prefs.getBool(_saveWindowPlacement) ?? true;
  }

  Future<void> setAlwaysOnTop(bool alwaysOnTop) async {
    await _prefs.setBool(_alwaysOnTop, alwaysOnTop);
  }

  bool getAlwaysOnTop() {
    return _prefs.getBool(_alwaysOnTop) ?? false;
  }

  Future<void> setEnableAnimations(bool enableAnimations) async {
    await _prefs.setBool(_enableAnimations, enableAnimations);
  }

  bool getEnableAnimations() {
    return _prefs.getBool(_enableAnimations) ?? true;
  }

  DeviceType? getDeviceType() {
    return DeviceType.values.firstWhereOrNull((m) => m.name == _prefs.getString(_deviceType));
  }

  Future<void> setDeviceType(DeviceType deviceType) async {
    await _prefs.setString(_deviceType, deviceType.name);
  }

  String? getDeviceModel() {
    return _prefs.getString(_deviceModel);
  }

  Future<void> setDeviceModel(String deviceModel) async {
    await _prefs.setString(_deviceModel, deviceModel);
  }

  String? getWhatsNew() {
    return _prefs.getString(_whatsNewKey);
  }

  Future<void> setWhatsNew(String version) async {
    await _prefs.setString(_whatsNewKey, version);
  }

  Future<void> clear() async {
    await _prefs.clear();
  }
}
