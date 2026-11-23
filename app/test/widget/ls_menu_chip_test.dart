import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sonar/config/theme.dart';
import 'package:sonar/model/persistence/color_mode.dart';
import 'package:sonar/widget/ls/ls_menu.dart';

const _items = [
  LsMenuItem(value: 0, label: 'Date', checked: true),
  LsMenuItem(value: 1, label: 'Name'),
  LsMenuItem(value: 2, label: 'Size'),
];

void main() {
  testWidgets('the trigger keeps the current value and marks itself as a menu', (tester) async {
    await tester.pumpWidget(_host(onSelected: (_) {}));

    expect(find.text('Date'), findsOneWidget);
    expect(find.byIcon(LucideIcons.chevronDown), findsOneWidget);
  });

  testWidgets('tapping the chip lists every option without selecting one', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(_host(onSelected: selected.add));

    await tester.tap(find.text('Date'));
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Size'), findsOneWidget);
    expect(selected, isEmpty);
  });

  testWidgets('the entry in effect carries the accent check', (tester) async {
    await tester.pumpWidget(_host(onSelected: (_) {}));

    await tester.tap(find.text('Date'));
    await tester.pumpAndSettle();

    // One check for the entry in effect; the others keep the empty slot.
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
  });

  testWidgets('choosing an entry reports it and closes the panel', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(_host(onSelected: selected.add));

    await tester.tap(find.text('Date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Size'));
    await tester.pumpAndSettle();

    expect(selected, [2]);
    expect(find.text('Size'), findsNothing);
  });

  testWidgets('the panel hugs its widest label instead of a 150px floor', (tester) async {
    await tester.pumpWidget(_host(onSelected: (_) {}));

    await tester.tap(find.text('Date'));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(MenuItemButton).first).width, lessThan(150));
  });

  testWidgets('dense shrinks the panel rows to 30px', (tester) async {
    await tester.pumpWidget(_host(onSelected: (_) {}));

    await tester.tap(find.text('Date'));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(MenuItemButton).first).height, 30);
  });

  testWidgets('a chip on the bottom edge opens its panel above itself', (tester) async {
    await tester.pumpWidget(_footerHost());

    await tester.tap(find.text('Date'));
    await tester.pumpAndSettle();

    final rows = find.byType(MenuItemButton);
    expect(rows, findsNWidgets(3));
    // The footer has no room below, so the panel must flip up instead of
    // squeezing itself against the bottom of the window.
    expect(tester.getRect(rows.last).bottom, lessThanOrEqualTo(tester.getRect(find.byIcon(LucideIcons.chevronDown)).top));
  });
}

Widget _host({required ValueChanged<int> onSelected}) {
  return MaterialApp(
    theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark),
    home: Scaffold(
      body: Center(
        child: LsMenuChip<int>(label: 'Date', tooltip: 'Sort', items: _items, onSelected: onSelected),
      ),
    ),
  );
}

Widget _footerHost() {
  return MaterialApp(
    theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark),
    home: Scaffold(
      body: Column(
        children: [
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(10),
            child: LsMenuChip<int>(label: 'Date', items: _items, onSelected: (_) {}),
          ),
        ],
      ),
    ),
  );
}
