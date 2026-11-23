import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:sonar/util/native/platform_check.dart';
import 'package:sonar_isolates/util/foreground_service.dart';

final _logger = Logger('RequestNotification');

/// The channel of `MainActivity` (`app/android/app/src/main/kotlin/com/zephyr/sonar/MainActivity.kt`).
const _methodChannel = MethodChannel('com.zephyr.sonar/localsend');

/// A notification for a file request that arrives while the app is not on screen.
///
/// A pending request only pushes a dialog, which nobody sees from the background. The foreground
/// service notification cannot be reused for this (Android 12+ forbids starting a foreground
/// service from the background, and it would replace the transfer progress), so Android posts a
/// second notification natively. iOS does not run in the background at all, so no request ever
/// arrives there.
class RequestNotification {
  RequestNotification._();

  static bool get _isSupported => checkPlatform([TargetPlatform.android]);

  /// Shows the notification. A previous one is replaced, because only one request can be pending.
  static void show({
    required String title,
    required String text,
    required String channelName,
  }) {
    if (!_isSupported) {
      return;
    }
    unawaited(
      _invoke('showRequestNotification', {
        'title': title,
        'text': text,
        'channelName': channelName,
      }),
    );
  }

  /// Removes the notification once the request was answered, declined or cancelled.
  static void cancel() {
    if (!_isSupported) {
      return;
    }
    unawaited(_invoke('cancelRequestNotification', null));
  }

  /// Asks for the notification permission while the app is in the foreground.
  ///
  /// It cannot be asked for at the moment a request arrives, because that is exactly when the app
  /// is in the background and Android shows no permission dialog there. Asking at app start keeps
  /// both this notification and the transfer notification working for users who never transferred
  /// anything before.
  static void ensurePermission() {
    if (!_isSupported) {
      return;
    }
    ForegroundService.ensureNotificationPermission();
  }

  /// Fire and forget: the request is already pending, so a failing platform call must neither
  /// escape into the server event loop nor block it.
  static Future<void> _invoke(String method, Map<String, String>? arguments) async {
    try {
      await _methodChannel.invokeMethod<void>(method, arguments);
    } catch (e, st) {
      _logger.warning('Could not call $method', e, st);
    }
  }
}
