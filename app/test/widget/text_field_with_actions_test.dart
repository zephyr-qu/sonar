import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonar/config/theme.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/persistence/color_mode.dart';
import 'package:sonar/widget/dialogs/text_field_with_actions.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';

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

  testWidgets('a rejected text keeps confirm disabled and is never committed', (tester) async {
    final controller = TextEditingController(text: 'Old name');
    final closed = <String>[];

    await tester.pumpWidget(
      _host(controller: controller, onClosed: closed.add, validator: (value) => value.trim().isEmpty ? 'Required' : null),
    );

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsOneWidget);
    expect(tester.widget<LsButton>(find.widgetWithText(LsButton, t.general.confirm)).onPressed, isNull);

    // Dismissing the dialog still closes it, but the rejected text must not be persisted.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(closed, isEmpty);
  });

  testWidgets('the shortcuts share one row with the confirm button, below the field', (tester) async {
    final controller = TextEditingController(text: 'Old name');
    final shortcuts = [
      IconButton(onPressed: () {}, icon: const Icon(Icons.casino)),
      IconButton(onPressed: () {}, icon: const Icon(Icons.desktop_windows)),
    ];

    await tester.pumpWidget(_host(controller: controller, onClosed: (_) {}, actions: shortcuts));
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    final field = tester.getRect(find.byType(TextFormField));
    final first = tester.getRect(find.byIcon(Icons.casino));
    final second = tester.getRect(find.byIcon(Icons.desktop_windows));
    final confirm = tester.getRect(find.widgetWithText(LsButton, t.general.confirm));

    expect(first.top, greaterThan(field.bottom), reason: 'the shortcuts belong below the field');
    expect((first.center.dy - second.center.dy).abs(), lessThan(1), reason: 'both shortcuts stay on one row');
    expect((second.center.dy - confirm.center.dy).abs(), lessThan(4), reason: 'the confirm button joins that row');
    expect(second.right, lessThan(confirm.left), reason: 'shortcuts left, confirm right');
  });

  group('a controller the dialog owns', () {
    // The closing route keeps building the field while it fades out, so the
    // controller may only die with the dialog. Disposing it when the future
    // completes used to throw "A TextEditingController was used after being
    // disposed" on the way out, however the dialog was dismissed.
    testWidgets('survives the barrier dismissal and dies with the dialog', (tester) async {
      final finalTexts = <String>[];

      await tester.pumpWidget(_ownedHost(finalTexts));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'New name');
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(finalTexts, ['New name']);
    });

    testWidgets('survives the confirm button', (tester) async {
      final finalTexts = <String>[];

      await tester.pumpWidget(_ownedHost(finalTexts));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'New name');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(LsButton, t.general.confirm));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(finalTexts, ['New name']);
    });
  });
}

/// Opens the dialog with a controller of its own, the way the device name
/// dialog does, and records the text read right after the dialog closed.
Widget _ownedHost(List<String> finalTexts) {
  return MaterialApp(
    theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark, null),
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final controller = TextEditingController(text: 'Old name');
              await showTextFieldDialog(
                context,
                name: 'Alias',
                controller: controller,
                disposeController: true,
              );
              finalTexts.add(controller.text);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Widget _host({
  required TextEditingController controller,
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onClosed,
  String? Function(String value)? validator,
  List<Widget> actions = const [],
}) {
  return MaterialApp(
    theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark, null),
    home: Scaffold(
      body: Center(
        child: TextFieldWithActions(
          name: 'Alias',
          controller: controller,
          onChanged: onChanged,
          onClosed: onClosed,
          validator: validator,
          actions: actions,
        ),
      ),
    ),
  );
}
