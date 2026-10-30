import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/util/radar_layout.dart';
import 'package:localsend_app/widget/ls/ls_radar.dart';

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
        theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark, null),
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
}
