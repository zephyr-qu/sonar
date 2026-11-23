part of 'persistence_provider.dart';

const _latestVersion = 7;

Future<void> _runMigrations(int from) async {
  if (from < 2) {
    await _migrate2();
    await SharedPreferencesStorePlatform.instance.setValue('Int', 'flutter.$_version', 2);
  }
  if (from < 3) {
    await _migrate3();
    await SharedPreferencesStorePlatform.instance.setValue('Int', 'flutter.$_version', 3);
  }
  if (from < 4) {
    await _migrate4();
    await SharedPreferencesStorePlatform.instance.setValue('Int', 'flutter.$_version', 4);
  }
  if (from < 5) {
    await _migrate5();
    await SharedPreferencesStorePlatform.instance.setValue('Int', 'flutter.$_version', 5);
  }
  if (from < 6) {
    await _migrate6();
    await SharedPreferencesStorePlatform.instance.setValue('Int', 'flutter.$_version', 6);
  }
  if (from < 7) {
    await _migrate7();
    await SharedPreferencesStorePlatform.instance.setValue('Int', 'flutter.$_version', 7);
  }
}

Future<void> _migrate2() async {
  _logger.info('Migrating to version 2');
  if (SharedPreferencesStorePlatform.instance is! SharedPreferencesPortable) {
    await enableContextMenu();

    if (defaultTargetPlatform == TargetPlatform.windows) {
      final newFolder = File(_windowsFile).parent;
      if (!newFolder.existsSync()) {
        newFolder.createSync(recursive: true);
      }

      final legacyFile = File(_windowsLegacyFile);
      legacyFile.copySync(_windowsFile);
      try {
        legacyFile.parent.parent.deleteSync(recursive: true);
      } catch (e) {
        _logger.warning('Failed to delete legacy folder: $e');
      }
      SharedPreferencesStorePlatform.instance = SharedPreferencesFile(filePath: _windowsFile);
    }
  }
}

Future<void> _migrate3() async {
  _logger.info('Migrating to version 3');
  final prefs = await SharedPreferencesStorePlatform.instance.getAll();

  // ls_quick_save becomes a QuickSaveMode: keep "on" if it was enabled, otherwise apply the new default "paired"
  // (which is what ls_quick_save_from_favorites used to do)
  final quickSave = prefs['flutter.$_quickSave'] == true ? QuickSaveMode.on : QuickSaveMode.paired;
  await SharedPreferencesStorePlatform.instance.setValue('String', 'flutter.$_quickSave', quickSave.name);
  await SharedPreferencesStorePlatform.instance.remove('flutter.ls_quick_save_from_favorites');

  // some users disabled HTTPS for performance reasons which no longer apply since the Rust migration
  await SharedPreferencesStorePlatform.instance.setValue('Bool', 'flutter.$_https', true);
}

Future<void> _migrate4() async {
  _logger.info('Migrating to version 4');
  final prefs = await SharedPreferencesStorePlatform.instance.getAll();
  final value = prefs['flutter.$_quickSave'];
  if (value is bool) {
    // Match migration 3 and the favorites-only default announced in What's new in 1.18.0.
    final quickSave = value ? QuickSaveMode.on : QuickSaveMode.paired;
    await SharedPreferencesStorePlatform.instance.setValue('String', 'flutter.$_quickSave', quickSave.name);
  }
}

Future<void> _migrate5() async {
  _logger.info('Migrating to version 5');

  // The advanced settings and the send mode are gone from the settings page; their
  // stored values would otherwise sit in the profile forever, read by nobody.
  final store = SharedPreferencesStorePlatform.instance;
  for (final key in ['ls_advanced_settings', 'ls_send_mode']) {
    await store.remove('flutter.$key');
  }
}

const _legacyHistoryKeys = {
  TransferHistoryDirection.send: 'ls_send_history',
  TransferHistoryDirection.receive: 'ls_receive_history',
};

/// The transfer history used to be one entry per file, in two separate lists.
/// It is now one entry per finished session: group the old entries back into
/// sessions (one per sender/receiver alias and minute) so existing installations
/// do not lose their history.
Future<void> _migrate6() async {
  _logger.info('Migrating to version 6');

  final store = SharedPreferencesStorePlatform.instance;
  final prefs = await store.getAll();

  final sessions = <String, TransferHistorySession>{};
  var sessionCounter = 0;
  for (final MapEntry(key: direction, value: legacyKey) in _legacyHistoryKeys.entries) {
    final raw = prefs['flutter.$legacyKey'];
    if (raw is! List) {
      continue;
    }

    for (final item in raw) {
      if (item is! String) {
        continue;
      }
      final Map<String, dynamic> legacy;
      try {
        legacy = jsonDecode(item) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }

      final fileName = legacy['fileName'] as String?;
      final timestamp = DateTime.tryParse(legacy['timestamp'] as String? ?? '')?.toUtc();
      if (fileName == null || timestamp == null) {
        continue;
      }

      final alias = (legacy['senderAlias'] ?? legacy['receiverAlias'] as String? ?? '') as String;
      final groupKey = '${direction.name}|$alias|${timestamp.year}-${timestamp.month}-${timestamp.day}-${timestamp.hour}-${timestamp.minute}';
      final file = TransferHistoryFile(
        id: legacy['id'] as String? ?? '$groupKey-$sessionCounter',
        fileName: fileName,
        fileType: FileType.values.firstWhereOrNull((type) => type.name == legacy['fileType']) ?? FileType.other,
        fileSize: legacy['fileSize'] as int? ?? 0,
        path: legacy['path'] as String?,
        savedToGallery: legacy['savedToGallery'] == true,
        isMessage: legacy['isMessage'] == true,
        modified: null, // the old schema did not store it
      );

      final existing = sessions[groupKey];
      if (existing == null) {
        sessionCounter++;
        sessions[groupKey] = TransferHistorySession(
          id: 'legacy-$sessionCounter',
          peerAlias: alias,
          direction: direction,
          timestamp: timestamp,
          files: [file],
        );
      } else {
        sessions[groupKey] = existing.withFiles([...existing.files, file]);
      }
    }
  }

  if (sessions.isNotEmpty) {
    final sorted = sessions.values.sorted((a, b) => b.timestamp.compareTo(a.timestamp));
    await store.setValue('StringList', 'flutter.$_transferHistory', [for (final session in sorted) jsonEncode(session.toJson())]);
  }
  for (final key in ['ls_receive_history', 'ls_send_history']) {
    await store.remove('flutter.$key');
  }
}

/// `ColorMode` lost its `system` (dynamic colors) and `yaru` entries: the accent row
/// now offers the brand accent, the presets and OLED. Both removed values fall back to
/// the brand accent, which is also what `getColorMode` does for an unknown name.
Future<void> _migrate7() async {
  _logger.info('Migrating to version 7');

  final store = SharedPreferencesStorePlatform.instance;
  final value = (await store.getAll())['flutter.$_colorKey'];
  if (value == 'system' || value == 'yaru') {
    await store.setValue('String', 'flutter.$_colorKey', ColorMode.localsend.name);
  }
}
