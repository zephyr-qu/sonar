import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:localsend_app/gen/assets.gen.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:tray_manager/tray_manager.dart' as tm;
import 'package:window_manager/window_manager.dart';

final _logger = Logger('TrayHelper');

enum TrayEntry {
  open,
  close,
}

Future<void> initTray() async {
  if (!checkPlatformHasTray()) {
    return;
  }
  try {
    if (checkPlatform([TargetPlatform.windows])) {
      await tm.trayManager.setIcon(Assets.img.logo);
    } else if (checkPlatform([TargetPlatform.macOS])) {
      // The menu bar icon will created in AppDelegate.swift
      return;
    } else if (checkPlatform([TargetPlatform.linux])) {
      String icon;
      if (await File('/.flatpak-info').exists()) {
        // Icon for Flatpak, which must exist in /app/share/icons/hicolor/*x*/apps.
        icon = 'org.localsend.localsend_app-tray';
      } else {
        icon = Assets.img.logo32White.path;
      }
      _logger.info('Using "$icon" as path of system tray icon');
      await tm.trayManager.setIcon(icon);
    } else {
      await tm.trayManager.setIcon(Assets.img.logo32.path);
    }

    final items = [
      tm.MenuItem(
        key: TrayEntry.open.name,
        label: t.tray.open,
      ),
      tm.MenuItem(
        key: TrayEntry.close.name,
        label: defaultTargetPlatform == TargetPlatform.windows ? t.tray.closeWindows : t.tray.close,
      ),
    ];
    await tm.trayManager.setContextMenu(tm.Menu(items: items));
    // No Linux implementation for setToolTip available as of tray_manager 0.2.2
    // https://pub.dev/packages/tray_manager#api
    if (!checkPlatform([TargetPlatform.linux])) {
      await tm.trayManager.setToolTip(t.appName);
    }
  } catch (e) {
    _logger.warning('Failed to init tray', e);
  }
}

/// Hides the window into the tray.
///
/// [updateSleepState] must be `false` when called before the Refena container is
/// mounted (e.g. `startHidden` during bootstrap): `RefenaScope.defaultRef` is a
/// `late` field that only exists once `RefenaScope` is built, so touching a
/// notifier then throws `LateInitializationError`. The state is seeded by
/// `sleepProvider.overrideWithInitialState` right after the mount instead.
Future<void> hideToTray({bool updateSleepState = true}) async {
  await windowManager.hide();
  if (checkPlatform([TargetPlatform.macOS])) {
    // This will crash on Windows
    // https://github.com/localsend/localsend/issues/32
    await windowManager.setSkipTaskbar(true);
  }

  if (updateSleepState) {
    // Disable animations
    _updateSleepState(sleeping: true);
  }
}

/// Shows and focuses the window from the tray.
///
/// See [hideToTray] for why [updateSleepState] can be `false`.
Future<void> showFromTray({bool updateSleepState = true}) async {
  await windowManager.show();
  await windowManager.focus();
  if (checkPlatform([TargetPlatform.macOS])) {
    // This will crash on Windows
    // https://github.com/localsend/localsend/issues/32
    await windowManager.setSkipTaskbar(false);
  }

  if (updateSleepState) {
    // Enable animations
    _updateSleepState(sleeping: false);
  }
}

/// Mirrors the sleeping flag into [sleepProvider], which pauses the animations.
///
/// Never throws when Refena is not mounted: the failure is only reported at
/// [Level.FINEST] because the bootstrap call sites are expected to skip it.
void _updateSleepState({required bool sleeping}) {
  try {
    RefenaScope.defaultRef.notifier(sleepProvider).setState((_) => sleeping);
  } catch (e) {
    _logger.finest('Failed to update sleep state (Refena is not mounted yet)', e);
  }
}

Future<void> destroyTray() async {
  if (!checkPlatform([TargetPlatform.linux])) {
    await tm.trayManager.destroy();
  }
}

/// Quits the app the way a window close does: the tray icon goes first, so
/// neither the tray menu nor the Ctrl+Q shortcut leaves an orphan icon behind.
Future<void> quitApp() async {
  await destroyTray();
  exit(0);
}
