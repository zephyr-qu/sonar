import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/widget/dialogs/cancel_session_dialog.dart';
import 'package:sonar/widget/dialogs/custom_bottom_sheet.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';

void main() {
  /// Pumps a page whose button opens [CancelSessionDialog.open] and returns a
  /// getter for the future that call produced.
  Future<Future<bool> Function()> pumpOpener(WidgetTester tester) async {
    late Future<bool> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => result = CancelSessionDialog.open(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    return () => result;
  }

  testWidgets('desktop shows a centered dialog that confirms cancellation', variant: TargetPlatformVariant.only(TargetPlatform.windows), (
    tester,
  ) async {
    final open = await pumpOpener(tester);
    await tester.pumpAndSettle();

    expect(find.byType(LsDialog), findsOneWidget);
    expect(find.byType(CustomBottomSheet), findsNothing);
    expect(find.text(t.dialogs.cancelSession.title), findsOneWidget);

    await tester.tap(find.widgetWithText(LsButton, t.general.cancel));
    await tester.pumpAndSettle();

    expect(find.byType(LsDialog), findsNothing);
    expect(await open(), isTrue);
  });

  testWidgets('desktop keep-going button does not confirm cancellation', variant: TargetPlatformVariant.only(TargetPlatform.windows), (tester) async {
    final open = await pumpOpener(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(LsButton, t.general.continueStr));
    await tester.pumpAndSettle();

    expect(find.byType(LsDialog), findsNothing);
    expect(await open(), isFalse);
  });

  testWidgets('mobile keeps the bottom sheet', (tester) async {
    final open = await pumpOpener(tester);
    await tester.pumpAndSettle();

    expect(find.byType(CustomBottomSheet), findsOneWidget);
    expect(find.byType(LsDialog), findsNothing);

    await tester.tap(find.widgetWithText(LsButton, t.general.cancel));
    await tester.pumpAndSettle();

    expect(await open(), isTrue);
  });
}
