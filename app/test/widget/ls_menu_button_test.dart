import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sonar/config/theme.dart';
import 'package:sonar/model/persistence/color_mode.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_menu.dart';

void main() {
  testWidgets('the trigger uses the 38px icon plate instead of the Material icon button', (tester) async {
    await tester.pumpWidget(_host(onSelected: (_) {}));

    final plate = tester.getSize(find.byType(LsIconButton));
    expect(plate, const Size(38, 38));
  });

  testWidgets('tapping the trigger opens the menu without selecting anything', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(_host(onSelected: selected.add));

    expect(find.text('Exclude system apps'), findsNothing);

    await tester.tap(find.byIcon(LucideIcons.slidersHorizontal));
    await tester.pumpAndSettle();

    expect(find.text('Exclude system apps'), findsOneWidget);
    expect(find.text('Exclude apps without launch intent'), findsOneWidget);
    expect(selected, isEmpty);
  });

  testWidgets('only the checked entry draws a check', (tester) async {
    await tester.pumpWidget(_host(onSelected: (_) {}));

    await tester.tap(find.byIcon(LucideIcons.slidersHorizontal));
    await tester.pumpAndSettle();

    // One check for the checked entry; the unchecked one keeps an empty slot so
    // both labels stay left-aligned.
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
  });

  testWidgets('tapping an entry reports its value and closes the menu', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(_host(onSelected: selected.add));

    await tester.tap(find.byIcon(LucideIcons.slidersHorizontal));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exclude apps without launch intent'));
    await tester.pumpAndSettle();

    expect(selected, [1]);
    expect(find.text('Exclude apps without launch intent'), findsNothing);
  });

  testWidgets('compact drops the 38px plate for a bare 15px glyph but opens the same menu', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(_host(onSelected: selected.add, compact: true));

    expect(find.byType(LsIconButton), findsNothing);
    expect(tester.getSize(find.byIcon(LucideIcons.slidersHorizontal)), const Size(15, 15));

    await tester.tap(find.byIcon(LucideIcons.slidersHorizontal));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exclude system apps'));
    await tester.pumpAndSettle();

    expect(selected, [0]);
  });

  testWidgets('an omitted tooltip falls back to the localized show-menu string', (tester) async {
    await tester.pumpWidget(_host(onSelected: (_) {}, compact: true, tooltip: null));

    expect(find.byTooltip('Show menu'), findsOneWidget);
  });
}

Widget _host({required ValueChanged<int> onSelected, bool compact = false, String? tooltip = 'Filters'}) {
  return MaterialApp(
    theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark),
    home: Scaffold(
      body: Center(
        child: LsMenuButton<int>(
          icon: LucideIcons.slidersHorizontal,
          compact: compact,
          tooltip: tooltip,
          items: const [
            LsMenuItem(value: 0, label: 'Exclude system apps', checked: true),
            LsMenuItem(value: 1, label: 'Exclude apps without launch intent'),
          ],
          onSelected: onSelected,
        ),
      ),
    ),
  );
}
