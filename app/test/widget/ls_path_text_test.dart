import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonar/widget/ls/ls_path_text.dart';

Widget _host(Widget child, {double width = 320}) {
  return MaterialApp(
    theme: ThemeData(brightness: Brightness.dark),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, height: 40, child: child),
      ),
    ),
  );
}

/// The text [LsPathText] actually renders, after its own truncation.
String _rendered(WidgetTester tester) {
  final text = tester.widget<Text>(find.descendant(of: find.byType(LsPathText), matching: find.byType(Text)));
  return text.data!;
}

void main() {
  testWidgets('a path that fits is shown unchanged', (tester) async {
    const path = '/home/me/Downloads';

    await tester.pumpWidget(_host(const LsPathText(path)));

    expect(_rendered(tester), path);
    expect(find.byTooltip(path), findsOneWidget);
  });

  testWidgets('a long path keeps its tail and elides the head', (tester) async {
    const path = r'C:\Users\somebody\Documents\LocalSend\Received Files\Project Assets 2026';

    await tester.pumpWidget(_host(const LsPathText(path)));

    final shown = _rendered(tester);
    expect(shown, startsWith('…'));
    expect(shown, endsWith(r'\Project Assets 2026'));
    // Whatever is shown is a real suffix of the path, not a rewritten one.
    expect(path.endsWith(shown.substring(1)), isTrue);
    expect(tester.getSize(find.text(shown)).width, lessThanOrEqualTo(320));
  });

  testWidgets('a single segment wider than the row is cut at a character', (tester) async {
    const path = '/home/me/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.txt';

    await tester.pumpWidget(_host(const LsPathText(path), width: 120));

    final shown = _rendered(tester);
    expect(shown, startsWith('…'));
    expect(shown, endsWith('.txt'));
    expect(path.endsWith(shown.substring(1)), isTrue);
    expect(tester.getSize(find.text(shown)).width, lessThanOrEqualTo(120));
  });
}
