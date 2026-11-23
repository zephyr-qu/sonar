import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:refena_flutter/addons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/font_licenses.dart';
import 'package:sonar/config/init.dart';
import 'package:sonar/config/init_error.dart';
import 'package:sonar/config/theme.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/persistence/color_mode.dart';
import 'package:sonar/pages/home_page.dart';
import 'package:sonar/provider/app_lifecycle_provider.dart';
import 'package:sonar/provider/local_ip_provider.dart';
import 'package:sonar/provider/network/server/server_provider.dart';
import 'package:sonar/provider/settings_provider.dart';
import 'package:sonar/util/native/platform_check.dart';
import 'package:sonar/util/native/request_notification.dart';
import 'package:sonar/widget/watcher/life_cycle_watcher.dart';
import 'package:sonar/widget/watcher/shortcut_watcher.dart';
import 'package:sonar/widget/watcher/tray_watcher.dart';
import 'package:sonar/widget/watcher/window_brightness_watcher.dart';
import 'package:sonar/widget/watcher/window_watcher.dart';
import 'package:sonar_isolates/isolate.dart';
import 'package:system_date_time_format/system_date_time_format.dart';

Future<void> main(List<String> args) async {
  registerFontLicenses();

  final RefenaContainer container;
  try {
    container = await preInit(args);
  } catch (e, stackTrace) {
    showInitErrorApp(
      error: e,
      stackTrace: stackTrace,
    );
    return;
  }

  runApp(
    RefenaScope.withContainer(
      container: container,
      child: SDTFScope(
        child: TranslationProvider(
          child: const SonarApp(),
        ),
      ),
    ),
  );
}

class SonarApp extends StatelessWidget {
  const SonarApp();

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final (themeMode, colorMode, customColor) = ref.watch(
      settingsProvider.select((settings) => (settings.theme, settings.colorMode, settings.customColor)),
    );
    return TrayWatcher(
      child: WindowWatcher(
        child: LifeCycleWatcher(
          onChangedState: (AppLifecycleState state) {
            ref.notifier(appLifecycleProvider).set(state);
            switch (state) {
              case AppLifecycleState.resumed:
                ref.redux(localIpProvider).dispatch(InitLocalIpAction());
                if (checkPlatform([TargetPlatform.iOS, TargetPlatform.android])) {
                  // The OS may have invalidated the sockets of the suspended app without any error ever reaching the accept loop.
                  // ignore: discarded_futures
                  ref.notifier(serverProvider).ensureRunning();
                }
                if (checkPlatform([TargetPlatform.iOS])) {
                  // The multicast sockets die the same silent way but cannot be probed, so always rebind them.
                  ref.redux(parentIsolateProvider).dispatch(IsolateDiscoveryRestartAction());
                }
                // The app is in the foreground here, which is the only moment Android shows the
                // notification permission dialog. The incoming request notification needs it, and
                // it cannot ask at the moment a request arrives (that is always in the background).
                RequestNotification.ensurePermission();

                // The notification and the request dialog announce the same request: with the app
                // back in front, the dialog is what the user acts on, and a notification left over
                // from an app that was killed in the meantime would open nothing.
                RequestNotification.cancel();
                break;
              case AppLifecycleState.detached:
                // The main isolate is only exited when all child isolates are exited.
                // https://github.com/localsend/localsend/issues/1568
                ref.redux(parentIsolateProvider).dispatch(IsolateDisposeAction());
                break;
              default:
                break;
            }
          },
          child: ShortcutWatcher(
            child: MaterialApp(
              title: t.appName,
              locale: TranslationProvider.of(context).flutterLocale,
              supportedLocales: AppLocaleUtils.supportedLocales,
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              debugShowCheckedModeBanner: false,
              theme: getTheme(colorMode, customColor, Brightness.light),
              darkTheme: getTheme(colorMode, customColor, Brightness.dark),
              themeMode: colorMode == ColorMode.oled ? ThemeMode.dark : themeMode,
              builder: (context, child) => WindowBrightnessWatcher(child: child!),
              navigatorKey: context.read(navigationProvider).key,
              home: RouterinoHome(
                builder: () => const HomePage(
                  initialTab: HomeTab.nearby,
                  appStart: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
