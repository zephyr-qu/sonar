import 'package:flutter/widgets.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// The lifecycle state the app last reported.
///
/// Notifiers cannot watch, so the app's lifecycle is mirrored here by `LifeCycleWatcher` in
/// `main.dart`. Callers that need it (e.g. the incoming request notification, which must not fire
/// while the request dialog is on screen) then read it synchronously.
final appLifecycleProvider = NotifierProvider<AppLifecycleNotifier, AppLifecycleState>(
  (ref) => AppLifecycleNotifier(),
  debugLabel: 'appLifecycleProvider',
);

class AppLifecycleNotifier extends Notifier<AppLifecycleState> {
  @override
  AppLifecycleState init() {
    // The first frame is drawn by an app that is on screen.
    return AppLifecycleState.resumed;
  }

  void set(AppLifecycleState lifecycleState) {
    if (state == lifecycleState) {
      return;
    }
    state = lifecycleState;
  }
}
