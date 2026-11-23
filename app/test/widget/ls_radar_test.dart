import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonar/config/theme.dart';
import 'package:sonar/model/persistence/color_mode.dart';
import 'package:sonar/util/radar_layout.dart';
import 'package:sonar/widget/ls/ls_dashed.dart';
import 'package:sonar/widget/ls/ls_radar.dart';

/// The radar now sizes every bubble from `layoutRadarSlots`; render the busiest case
/// (six online devices plus the offline favorite) and check it lays out cleanly.
void main() {
  testWidgets('the radar lays out six devices plus the offline favorite', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final slots = layoutRadarSlots(onlineCount: 6, hasOffline: true);

    await tester.pumpWidget(
      MaterialApp(
        theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark),
        home: Scaffold(
          body: Center(
            child: LsRadar(
              size: 344,
              animate: false,
              center: const CircleAvatar(radius: 38),
              peers: [
                for (var i = 0; i < slots.length; i++)
                  LsRadarPeer(
                    child: const Icon(Icons.smartphone),
                    label: slots[i].offline ? 'NAS-STORAGE' : 'Device $i',
                    angle: slots[i].angle,
                    radius: slots[i].radius,
                    size: slots[i].size,
                    offline: slots[i].offline,
                    labelAbove: i.isOdd || slots[i].offline,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Device 0'), findsOneWidget);
    expect(find.text('NAS-STORAGE'), findsOneWidget);
    expect(find.byType(LsRadar), findsOneWidget);
  });

  /// An offline favorite is not reachable, so its bubble is the one place the radar
  /// says "offline" without a gesture: a dashed outline instead of the online hairline.
  testWidgets('the offline peer is dashed, the online peer keeps a hairline', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark),
        home: Scaffold(
          body: Center(
            child: LsRadar(
              size: 344,
              animate: false,
              center: const CircleAvatar(radius: 38),
              peers: const [
                LsRadarPeer(child: Icon(Icons.smartphone), label: 'ONLINE', angle: 180, radius: 90, size: 60),
                LsRadarPeer(child: Icon(Icons.monitor), label: 'OFFLINE', angle: 0, radius: 90, size: 44, offline: true),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // One ring for the radar rim, one for the 44 px offline bubble — the online bubble is bare.
    expect(find.byType(LsDashedRing), findsNWidgets(2));
    expect(find.byWidgetPredicate((widget) => widget is LsDashedRing && widget.size == 43), findsOneWidget);

    BoxBorder? borderOf(IconData icon) {
      final bubble = find.ancestor(of: find.byIcon(icon), matching: find.byType(AnimatedContainer));
      return (tester.widget<AnimatedContainer>(bubble.first).decoration! as BoxDecoration).border;
    }

    expect(borderOf(Icons.smartphone), isNotNull, reason: 'the online bubble still draws a solid hairline');
    expect(borderOf(Icons.monitor), isNull, reason: 'the offline dashes are painted over an empty border');
  });
}
