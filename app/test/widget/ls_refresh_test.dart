import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonar/config/theme.dart';
import 'package:sonar/model/persistence/color_mode.dart';
import 'package:sonar/widget/ls/ls_refresh.dart';

/// The mobile nearby tab rescans by pulling the list instead of by tapping a button, and the gesture
/// has to work even when the device grid is shorter than the viewport.
void main() {
  late int calls;

  setUp(() => calls = 0);

  Widget wrap({int items = 30}) {
    return MaterialApp(
      theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark),
      home: Scaffold(
        body: LsRefreshIndicator(
          onRefresh: () => calls++,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items,
            itemBuilder: (context, index) => SizedBox(height: 40, child: Text('device $index')),
          ),
        ),
      ),
    );
  }

  final line = find.byKey(const ValueKey('ls_refresh_line'));

  Future<void> pull(WidgetTester tester, double distance) async {
    await tester.drag(find.byType(ListView), Offset(0, distance));
    await tester.pumpAndSettle();
  }

  testWidgets('pulling an overflowing list past the threshold triggers the refresh once', (tester) async {
    await tester.pumpWidget(wrap());

    await pull(tester, 150);

    expect(calls, 1);
  });

  testWidgets('a list shorter than the viewport can still be pulled', (tester) async {
    await tester.pumpWidget(wrap(items: 1));

    // Without the always-scrollable physics the drag would be swallowed here, and a near-empty
    // device grid is the usual case.
    await pull(tester, 150);

    expect(calls, 1);
  });

  testWidgets('a short pull does nothing', (tester) async {
    await tester.pumpWidget(wrap());

    await pull(tester, 20);

    expect(calls, 0);
  });

  testWidgets('the line is gone right after the release, without waiting for any work', (tester) async {
    var running = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark),
        home: Scaffold(
          body: LsRefreshIndicator(
            // Work that never finishes: the material spinner this replaced would turn forever.
            onRefresh: () => running = true,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: 1,
              itemBuilder: (context, index) => const SizedBox(height: 40),
            ),
          ),
        ),
      ),
    );

    await pull(tester, 150);

    expect(running, isTrue);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.byType(RefreshIndicator), findsNothing);
    expect(line, findsNothing);
  });

  testWidgets('the line grows out of the centre and stops short of the screen width', (tester) async {
    await tester.pumpWidget(wrap());
    final listWidth = tester.getSize(find.byType(ListView)).width;

    final gesture = await tester.startGesture(tester.getCenter(find.byType(ListView)));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    final early = tester.getSize(line).width;
    expect(early, greaterThan(0));
    expect(early, lessThan(152));
    // Symmetric growth: the line stays centred on the list.
    expect(tester.getTopLeft(line).dx + early / 2, closeTo(listWidth / 2, 1));

    await gesture.moveBy(const Offset(0, 400));
    await tester.pump();
    final armed = tester.getSize(line).width;
    expect(armed, closeTo(152, 0.5));
    expect(tester.getTopLeft(line).dx + armed / 2, closeTo(listWidth / 2, 1));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the line disappears when the pull is released unarmed', (tester) async {
    await tester.pumpWidget(wrap());

    await pull(tester, 20);

    expect(line, findsNothing);
  });
}
