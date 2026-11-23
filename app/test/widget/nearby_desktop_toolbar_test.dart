import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sonar/config/theme.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/persistence/color_mode.dart';
import 'package:sonar/pages/tabs/nearby/nearby_desktop_toolbar.dart';
import 'package:sonar/pages/tabs/nearby/nearby_ui.dart';

/// The desktop shell renders the toolbar that the stacked layouts fold into the mini radar
/// bar; without it the tab's filter and query stayed at their initial values on this layout.
void main() {
  late TextEditingController query;
  late FocusNode focus;
  late List<NearbyFilter> filterCalls;
  late int queryChanges;
  late int scans;

  setUp(() {
    query = TextEditingController();
    focus = FocusNode();
    filterCalls = [];
    queryChanges = 0;
    scans = 0;
  });

  tearDown(() {
    query.dispose();
    focus.dispose();
  });

  /// Rebuilt through `StatefulBuilder` the way the page rebuilds itself from
  /// `onQueryChanged`: the clear button only exists once the field has text.
  Widget wrap({bool scanning = false, NearbyFilter filter = NearbyFilter.all}) {
    return MaterialApp(
      theme: getTheme(ColorMode.localsend, Colors.teal, Brightness.dark),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            final actions = NearbyActions(
              query: query,
              searchFocus: focus,
              onQueryChanged: () => setState(() => queryChanges++),
              onFilterChanged: filterCalls.add,
              onFilesOpenChanged: (_) {},
              onOpenLink: (_) async {},
              onToggleMulti: ({String? preselect}) {},
              onDeviceTap: (_) async {},
              onDeviceLongPress: (_) async {},
              onToggleFavorite: (_) async {},
              onPickedCleared: () {},
            );
            return SizedBox(
              width: 900,
              child: NearbyDesktopToolbar(
                scanning: scanning,
                onScan: () => setState(() => scans++),
                ui: NearbyUi.initial().copyWith(filter: filter),
                actions: actions,
              ),
            );
          },
        ),
      ),
    );
  }

  testWidgets('the toolbar offers the search field, the three filters and a rescan', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(t.nearbyTab.search), findsOneWidget);
    expect(find.text(t.nearbyTab.filterAll), findsOneWidget);
    expect(find.text(t.nearbyTab.filterOnline), findsOneWidget);
    expect(find.text(t.nearbyTab.filterFavorites), findsOneWidget);
    expect(find.byIcon(LucideIcons.refreshCw), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the search field is wired to the page focus node', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(focus.hasFocus, isFalse);
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('a filter tap reports the picked filter', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text(t.nearbyTab.filterFavorites));
    await tester.pump();

    expect(filterCalls, [NearbyFilter.favorites]);
  });

  testWidgets('typing reports the query and the clear button empties the field', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.byIcon(LucideIcons.x), findsNothing);

    await tester.enterText(find.byType(TextField), 'nas');
    await tester.pumpAndSettle();

    expect(query.text, 'nas');
    expect(queryChanges, greaterThan(0));
    expect(find.byIcon(LucideIcons.x), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();

    expect(query.text, isEmpty);
    expect(find.byIcon(LucideIcons.x), findsNothing);
  });

  testWidgets('a running scan swaps the rescan button for a spinner', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.refreshCw));
    await tester.pump();
    expect(scans, 1);

    await tester.pumpWidget(wrap(scanning: true));
    await tester.pump();

    expect(find.byIcon(LucideIcons.refreshCw), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel(t.nearbyTab.scan), findsOneWidget);
  });
}
