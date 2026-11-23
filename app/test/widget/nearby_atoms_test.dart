import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/config/theme.dart';
import 'package:sonar/model/persistence/color_mode.dart';
import 'package:sonar/widget/ls/ls_card.dart';
import 'package:sonar/widget/ls/ls_chip.dart';
import 'package:sonar/widget/ls/ls_header.dart';
import 'package:sonar/widget/ls/ls_radar.dart';
import 'package:sonar/widget/ls/ls_search_field.dart';
import 'package:sonar/widget/ls/ls_segmented.dart';
import 'package:sonar/widget/ls/ls_switch.dart';
import 'package:sonar/widget/ls/ls_tile.dart';

/// Renders the redesign atoms at the prototype viewport (390 x 844) and fails on
/// overflow or layout assertions.
void main() {
  testWidgets('the signal theme exposes the design tokens', (tester) async {
    late LsTokens tokens;
    await tester.pumpWidget(
      MaterialApp(
        theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark),
        home: Builder(
          builder: (context) {
            tokens = context.ls;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(tokens.colors.bg, const Color(0xFF0A0B0D));
    expect(tokens.colors.accent, const Color(0xFFC6F24E));
    expect(tokens.radius, 16);
    // The prototype faces are bundled, with the platform CJK font as fallback.
    expect(tokens.monoFamily, 'JetBrains Mono');
    expect(tokens.mono.fontFamily, 'JetBrains Mono');
    expect(Theme.of(tester.element(find.byType(SizedBox).first)).textTheme.bodyMedium?.fontFamily, 'Archivo');
    expect(Theme.of(tester.element(find.byType(SizedBox).first)).textTheme.titleLarge?.letterSpacing, lessThan(0));
  });

  testWidgets('oled mode keeps the surface pure black', (tester) async {
    late LsTokens tokens;
    await tester.pumpWidget(
      MaterialApp(
        theme: getTheme(ColorMode.oled, Colors.teal, Brightness.dark),
        home: Builder(
          builder: (context) {
            tokens = context.ls;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(tokens.colors.bg, Colors.black);
  });

  testWidgets('custom mode keeps the picked accent instead of a tonal shift', (tester) async {
    const picked = Color(0xFF7AA2FF);
    late LsTokens tokens;
    late ThemeData theme;

    Future<void> pump(Color color, Brightness brightness) async {
      theme = getTheme(ColorMode.custom, color, brightness);
      await tester.pumpWidget(
        MaterialApp(
          // MaterialApp cross-fades theme changes; the assertions read the theme right
          // after the pump, so the transition has to be instantaneous here.
          themeAnimationDuration: Duration.zero,
          theme: theme,
          home: Builder(
            builder: (context) {
              tokens = context.ls;
              return const SizedBox();
            },
          ),
        ),
      );
    }

    // The swatch shows the picked color verbatim, so the accent (and the M3 primary
    // the framework widgets read) must be that color, not a tone-40/80 variant.
    await pump(picked, Brightness.light);
    expect(theme.colorScheme.primary, picked);
    expect(tokens.colors.accent, picked);
    expect(tokens.colors.accentInk.computeLuminance(), lessThan(picked.computeLuminance()));

    await pump(picked, Brightness.dark);
    expect(theme.colorScheme.primary, picked);
    expect(tokens.colors.accent, picked);
    expect(tokens.colors.accentInk, picked);

    // The brand lime keeps the hand-tuned light-mode ink of the prototype.
    await pump(const Color(0xFFC6F24E), Brightness.light);
    expect(tokens.colors.accentInk, const Color(0xFF5F7A0F));
  });

  testWidgets('the nearby atoms fit the phone viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const LsScreenHeader(mark: Icon(Icons.wifi_tethering), title: 'Kai iPhone'),
              Row(
                children: [
                  LsChip.text('All', accent: true),
                  const SizedBox(width: 8),
                  LsChip.text('Online'),
                  const Spacer(),
                  LsChip.text('Select'),
                ],
              ),
              const SizedBox(height: 12),
              LsSearchField(hint: 'Search device name or IP'),
              const SizedBox(height: 12),
              LsSegmented(options: const ['Grid', 'Radar'], index: 0, onChanged: (_) {}),
              const SizedBox(height: 12),
              Center(
                child: LsRadar(
                  size: 300,
                  animate: false,
                  center: const CircleAvatar(radius: 38),
                  peers: [
                    for (var i = 0; i < 5; i++)
                      LsRadarPeer(
                        child: const Icon(Icons.smartphone),
                        label: 'Device $i',
                        angle: -90 + (360 / 5) * i,
                        radius: 108,
                        labelAbove: i.isOdd,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                mainAxisExtent: 62,
                children: const [
                  LsDeviceTile(glyph: Icon(Icons.smartphone), name: 'Pixel 8', meta: 'HTTP  192.168.1.31'),
                  LsDeviceTile(glyph: Icon(Icons.computer), name: 'MacBook Pro', meta: 'HTTP  192.168.1.24', favorite: true),
                ],
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                // 4 columns inside 390 - 2*16 padding - 3*8 gaps => ~83px tiles, plus the label row.
                mainAxisExtent: 100,
                children: const [
                  LsFileTile(kind: 'HEIC', name: 'IMG_2481.HEIC'),
                  LsFileTile(kind: 'PDF', name: 'invoice.pdf'),
                  LsAddFileTile(label: 'Add file', onTap: _noop),
                ],
              ),
              const SizedBox(height: 12),
              LsCard(
                child: Row(
                  children: [
                    const Expanded(child: Text('Require PIN')),
                    LsSwitch(value: true, onChanged: _noopBool),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Device 0'), findsOneWidget);
    expect(find.byType(LsFileTile), findsNWidgets(2));
  });

  testWidgets('the prototype fonts are bundled', (tester) async {
    final archivo = await rootBundle.load('assets/fonts/Archivo-Regular.ttf');
    final archivoBold = await rootBundle.load('assets/fonts/Archivo-Bold.ttf');
    final jetBrainsMono = await rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf');

    expect(archivo.lengthInBytes, greaterThan(100000));
    expect(archivoBold.lengthInBytes, greaterThan(100000));
    expect(jetBrainsMono.lengthInBytes, greaterThan(100000));
  });
}

void _noop() {}

void _noopBool(bool value) {}
