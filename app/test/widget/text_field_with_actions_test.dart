import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/widget/dialogs/text_field_with_actions.dart';
import 'package:localsend_app/widget/ls/ls_buttons.dart';

/// The alias row writes through `onClosed` instead of `onChanged`, so typing
/// must not touch persistence while closing the dialog must commit exactly once.
void main() {
  testWidgets('onClosed commits the final text once, after the dialog closes', (tester) async {
    final controller = TextEditingController(text: 'Old name');
    final changes = <String>[];
    final closed = <String>[];

    await tester.pumpWidget(_host(controller: controller, onChanged: changes.add, onClosed: closed.add));

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(closed, isEmpty, reason: 'opening the dialog must not commit');

    await tester.enterText(find.byType(TextFormField), 'New name');
    await tester.pumpAndSettle();
    expect(changes, isNotEmpty, reason: 'keystrokes still stream through onChanged');
    expect(closed, isEmpty, reason: 'typing must not commit the setting');

    await tester.tap(find.widgetWithText(LsButton, t.general.confirm));
    await tester.pumpAndSettle();

    expect(controller.text, 'New name');
    expect(closed, ['New name']);
  });

  testWidgets('closing the dialog without editing still commits the current text once', (tester) async {
    final controller = TextEditingController(text: 'Old name');
    final closed = <String>[];

    await tester.pumpWidget(_host(controller: controller, onClosed: closed.add));

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(LsButton, t.general.confirm));
    await tester.pumpAndSettle();

    // A write of the unchanged value is harmless: the persistence layer is idempotent.
    expect(closed, ['Old name']);
  });

  testWidgets('works without an onChanged callback', (tester) async {
    final controller = TextEditingController(text: 'Old name');
    final closed = <String>[];

    await tester.pumpWidget(_host(controller: controller, onClosed: closed.add));

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Typed only');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(LsButton, t.general.confirm));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(closed, ['Typed only']);
  });
}

Widget _host({required TextEditingController controller, ValueChanged<String>? onChanged, ValueChanged<String>? onClosed}) {
  return MaterialApp(
    theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark, null),
    home: Scaffold(
      body: Center(
        child: TextFieldWithActions(
          name: 'Alias',
          controller: controller,
          onChanged: onChanged,
          onClosed: onClosed,
          actions: const [],
        ),
      ),
    ),
  );
}
