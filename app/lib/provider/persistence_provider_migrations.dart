part of 'persistence_provider.dart';

const _latestVersion = 5;

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
