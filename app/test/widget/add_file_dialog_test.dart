import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonar/config/theme.dart';
import 'package:sonar/model/persistence/color_mode.dart';
import 'package:sonar/util/native/file_picker.dart';
import 'package:sonar/widget/big_button.dart';
import 'package:sonar/widget/dialogs/add_file_dialog.dart';

/// The options the desktop dialog offers.
const _desktop = [FilePickerOption.file, FilePickerOption.folder, FilePickerOption.text, FilePickerOption.clipboard];

/// The options Android offers, the longest list of any platform.
const _android = [
  FilePickerOption.file,
  FilePickerOption.media,
  FilePickerOption.clipboard,
  FilePickerOption.text,
  FilePickerOption.folder,
  FilePickerOption.app,
];

void main() {
  testWidgets('the four desktop options form a single row', (tester) async {
    final rows = await _pump(tester, options: _desktop, width: 460);

    expect(rows, hasLength(1));
    expect(rows.single, hasLength(4));
  });

  testWidgets('six options form two full rows of three instead of four plus two', (tester) async {
    final rows = await _pump(tester, options: _android, width: 460);

    expect(rows, hasLength(2));
    expect(rows.map((row) => row.length), [3, 3]);
  });

  testWidgets('every row stays centered on the dialog', (tester) async {
    final rows = await _pump(tester, options: _desktop, width: 460);
    final buttons = rows.single;

    final block = Rect.fromLTRB(buttons.first.left, 0, buttons.last.right, 0);
    expect(block.center.dx, closeTo(tester.view.physicalSize.width / 2, 0.5));
  });

  testWidgets('a narrow sheet takes fewer columns instead of overflowing', (tester) async {
    final rows = await _pump(tester, options: _android, width: 260);

    expect(rows, hasLength(3));
    expect(rows.map((row) => row.length), [2, 2, 2]);
  });
}

/// Pumps [AddFileDialog] at a dialog-like [width] and returns the buttons grouped by row.
Future<List<List<Rect>>> _pump(WidgetTester tester, {required List<FilePickerOption> options, required double width}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: AddFileDialog(options: options),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final rects = [for (final element in find.byType(BigButton).evaluate()) tester.getRect(find.byWidget(element.widget))];
  final rows = <double, List<Rect>>{};
  for (final rect in rects) {
    rows.putIfAbsent(rect.top, () => []).add(rect);
  }

  return [for (final row in rows.values) row..sort((a, b) => a.left.compareTo(b.left))];
}
