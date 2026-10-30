import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/widget/ls/ls_tile.dart';
import 'package:lucide_icons/lucide_icons.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: ThemeData(brightness: Brightness.dark),
    home: Scaffold(
      body: Center(child: SizedBox(width: 320, height: 70, child: child)),
    ),
  );
}

void main() {
  testWidgets('LsDeviceTile forwards tap, long press, favorite and details', (tester) async {
    var taps = 0;
    var longPresses = 0;
    var favorites = 0;
    var details = 0;

    await tester.pumpWidget(
      _host(
        LsDeviceTile(
          glyph: const Icon(Icons.smartphone),
          name: 'Pixel 8',
          meta: 'HTTP · 192.168.1.31',
          onTap: () => taps++,
          onLongPress: () => longPresses++,
          onFavorite: () => favorites++,
          onDetails: () => details++,
        ),
      ),
    );

    await tester.tap(find.text('Pixel 8'));
    await tester.longPress(find.text('Pixel 8'));
    await tester.tap(find.byIcon(LucideIcons.star));
    await tester.tap(find.byIcon(LucideIcons.info));
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(longPresses, 1);
    expect(favorites, 1);
    expect(details, 1);
  });

  testWidgets('LsDeviceTile shows the selection state instead of the star in multi mode', (tester) async {
    await tester.pumpWidget(
      _host(
        const LsDeviceTile(
          glyph: Icon(Icons.smartphone),
          name: 'Pixel 8',
          meta: 'HTTP',
          selected: true,
          multi: true,
        ),
      ),
    );

    expect(find.byIcon(LucideIcons.checkCircle), findsOneWidget);
    expect(find.byIcon(LucideIcons.star), findsNothing);
  });

  testWidgets('LsDeviceTile renders the offline state faded', (tester) async {
    await tester.pumpWidget(
      _host(
        const LsDeviceTile(
          glyph: Icon(Icons.dns),
          name: 'NAS',
          meta: 'Offline',
          offline: true,
        ),
      ),
    );

    final tileOpacity = tester.widget<Opacity>(
      find.descendant(of: find.byType(LsDeviceTile), matching: find.byType(Opacity)).first,
    );
    expect(tileOpacity.opacity, lessThan(1));
  });

  testWidgets('device tile keeps long alias and meta inside a 320px grid cell', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 2,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                mainAxisExtent: 62,
              ),
              itemBuilder: (context, index) => LsDeviceTile(
                glyph: const Icon(Icons.smartphone),
                name: 'Kai 的 iPhone 15 Pro Max',
                meta: 'HTTP · 12 ms · iPhone 15 Pro · 192.168.100.200',
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    // Overflow of the two-line name inside the 62 px cell would surface here.
    expect(tester.takeException(), isNull);
  });
}
