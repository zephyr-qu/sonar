import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/config/theme.dart';
import 'package:sonar/model/persistence/color_mode.dart';
import 'package:sonar/widget/ls/ls_radar.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark),
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

LsRadar _radar({required bool selected, VoidCallback? onTap}) {
  return LsRadar(
    size: 320,
    animate: false,
    center: const SizedBox(width: 76, height: 76),
    peers: [
      LsRadarPeer(
        child: const Icon(Icons.devices),
        label: 'Pixel 8',
        angle: -90,
        radius: 108,
        selected: selected,
        onTap: onTap,
      ),
    ],
  );
}

BoxDecoration _peerDecoration(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
  return container.decoration! as BoxDecoration;
}

Color _peerGlyphColor(WidgetTester tester) {
  final iconTheme = tester.widget<IconTheme>(
    find.descendant(of: find.byType(AnimatedContainer), matching: find.byType(IconTheme)),
  );
  return iconTheme.data.color!;
}

void main() {
  testWidgets('a picked radar peer gets the accent border and soft wash', (tester) async {
    await tester.pumpWidget(_host(_radar(selected: true)));
    final tokens = tester.element(find.byType(LsRadar)).ls;

    final decoration = _peerDecoration(tester);
    expect(decoration.color, tokens.colors.accentSoft);
    expect((decoration.border! as Border).top.color, tokens.colors.accent);
    expect((decoration.border! as Border).top.width, 2);
    expect(_peerGlyphColor(tester), tokens.colors.accentInk);
  });

  testWidgets('an unpicked radar peer keeps the surface fill', (tester) async {
    await tester.pumpWidget(_host(_radar(selected: false)));
    final tokens = tester.element(find.byType(LsRadar)).ls;

    final decoration = _peerDecoration(tester);
    expect(decoration.color, tokens.colors.bg2);
    expect(_peerGlyphColor(tester), tokens.colors.fg);
  });

  testWidgets('tapping a radar peer still reports the tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(_radar(selected: false, onTap: () => taps++)));

    await tester.tap(find.byIcon(Icons.devices));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('long pressing a radar peer enters multi-select without a tooltip', (tester) async {
    var longPresses = 0;
    await tester.pumpWidget(
      _host(
        LsRadar(
          size: 320,
          animate: false,
          center: const SizedBox(width: 76, height: 76),
          peers: [
            LsRadarPeer(
              child: const Icon(Icons.devices),
              label: 'Pixel 8',
              angle: -90,
              radius: 108,
              tooltip: 'Pixel 8',
              onLongPress: () => longPresses++,
            ),
          ],
        ),
      ),
    );

    await tester.longPress(find.byIcon(Icons.devices));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    // Nothing may be thrown while the long press is in flight.
    expect(tester.takeException(), isNull);
    expect(longPresses, 1);
    // The tooltip is skipped for peers that own the long press gesture.
    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets('tapping a radar peer label reports the label tap, not the bubble tap', (tester) async {
    var taps = 0;
    var labelTaps = 0;
    await tester.pumpWidget(
      _host(
        LsRadar(
          size: 320,
          animate: false,
          center: const SizedBox(width: 76, height: 76),
          peers: [
            LsRadarPeer(
              child: const Icon(Icons.devices),
              label: 'Pixel 8',
              angle: -90,
              radius: 108,
              onTap: () => taps++,
              onLabelTap: () => labelTaps++,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Pixel 8'));
    await tester.pumpAndSettle();

    expect(labelTaps, 1);
    expect(taps, 0);
  });

  testWidgets('only a peer that owns a label tap gets the details pill', (tester) async {
    await tester.pumpWidget(_host(_radar(selected: false)));
    expect(find.text('Pixel 8'), findsOneWidget);
    expect(find.byIcon(LucideIcons.info), findsNothing);

    await tester.pumpWidget(
      _host(
        LsRadar(
          size: 320,
          animate: false,
          center: const SizedBox(width: 76, height: 76),
          peers: [
            LsRadarPeer(
              child: const Icon(Icons.devices),
              label: 'Pixel 8',
              angle: -90,
              radius: 108,
              onLabelTap: () {},
            ),
          ],
        ),
      ),
    );

    expect(find.text('Pixel 8'), findsOneWidget);
    expect(find.byIcon(LucideIcons.info), findsOneWidget);
  });
}
