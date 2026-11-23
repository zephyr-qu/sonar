import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/persistence/transfer_history_session.dart';
import 'package:sonar/pages/transfer_detail_page.dart';
import 'package:sonar_isolates/model/file_type.dart';
import 'package:system_date_time_format/system_date_time_format.dart';

/// One file with a name long enough to need the caption's full two lines.
TransferHistoryFile _file(int index) {
  return TransferHistoryFile(
    id: 'file-$index',
    fileName: 'very_long_file_name_number_${index}_final_version_2026.png',
    fileType: FileType.image,
    fileSize: 1024 * (index + 1),
    path: '/tmp/very_long_file_name_number_${index}_final_version_2026.png',
    savedToGallery: false,
    isMessage: false,
    modified: DateTime.utc(2026, 1, 2, 3, 4),
  );
}

TransferHistorySession _session() {
  return TransferHistorySession(
    id: 'session-1',
    peerAlias: 'Pixel 8',
    direction: TransferHistoryDirection.receive,
    timestamp: DateTime.utc(2026, 1, 2, 3, 5),
    files: List.generate(9, _file),
  );
}

/// 420px is the narrowest width whose footer still fits under the test font, which is wider than
/// the real one; the grid caption band is a fixed pixel strip, so the narrow case is what matters.
Future<void> _pumpDetailPage(WidgetTester tester, {required Size size}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    SDTFScope(
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: TransferDetailPage(session: _session()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Names in the order the list shows them, in either view mode.
List<String> _visibleFileNames(WidgetTester tester) {
  return tester.widgetList<Text>(find.textContaining('very_long_file_name_number_')).map((text) => text.data ?? '').toList();
}

void main() {
  // Regression: the grid used `childAspectRatio: 1 / 1.24`, which left the two-line 9px caption
  // less vertical room than it needs on phone columns, so a long file name painted past its cell.
  for (final size in const [Size(420, 780), Size(600, 900), Size(1280, 900)]) {
    testWidgets('grid captions stay inside their cells at ${size.width.toInt()}px', (tester) async {
      await _pumpDetailPage(tester, size: size);

      await tester.tap(find.byIcon(LucideIcons.layoutGrid));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Every caption's painted box must stay within the vertical band of its own cell.
      final cells = find.byType(GridView);
      expect(cells, findsOneWidget);
      final grid = tester.getRect(cells);
      for (final caption in find.textContaining('very_long_file_name_number_').evaluate()) {
        final rect = tester.getRect(find.byWidget(caption.widget));
        expect(rect.bottom, lessThanOrEqualTo(grid.bottom));
        expect(rect.top, greaterThanOrEqualTo(grid.top));
      }
    });
  }

  testWidgets('grid captions keep their two lines and ellipsize', (tester) async {
    await _pumpDetailPage(tester, size: const Size(420, 780));
    await tester.tap(find.byIcon(LucideIcons.layoutGrid));
    await tester.pumpAndSettle();

    final caption = tester.widget<Text>(find.textContaining('very_long_file_name_number_').first);
    expect(caption.maxLines, 2);
    expect(caption.overflow, TextOverflow.ellipsis);
  });

  // The direction used to live inside the labels (`Name ↑`), so `Name ↓` was only
  // reachable by picking another order first. It now has its own toggle.
  testWidgets('the direction button flips the order in place', (tester) async {
    await _pumpDetailPage(tester, size: const Size(1280, 900));

    // The view mode is remembered between pages, so an earlier test may have left
    // the page in grid mode, which has no per-row list of names.
    if (find.byIcon(LucideIcons.moreHorizontal).evaluate().isEmpty) {
      await tester.tap(find.byIcon(LucideIcons.list));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text(t.transferTab.sortDate));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.transferTab.sortName));
    await tester.pumpAndSettle();

    // Names start out A→Z and the glyph reports that state.
    expect(find.byIcon(LucideIcons.arrowUpNarrowWide), findsOneWidget);
    expect(_visibleFileNames(tester).first, contains('number_0'));

    await tester.tap(find.byIcon(LucideIcons.arrowUpNarrowWide));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.arrowDownWideNarrow), findsOneWidget);
    expect(_visibleFileNames(tester).first, contains('number_8'));
  });
  // The footer sort control used to cycle `_sort = _sort.next` on every tap, so its label
  // changed with each press and the other two orders were unreachable directly.
  testWidgets('the footer sort chip lists its orders instead of cycling', (tester) async {
    await _pumpDetailPage(tester, size: const Size(1280, 900));

    expect(find.text(t.transferTab.sortDate), findsOneWidget);
    await tester.tap(find.text(t.transferTab.sortDate));
    await tester.pumpAndSettle();

    // One tap opens the list; it must not advance the order by itself.
    expect(find.text(t.transferTab.sortName), findsOneWidget);
    expect(find.text(t.transferTab.sortSize), findsOneWidget);
    // The direction now has its own toggle instead of being baked into the labels.
    expect(find.textContaining('↓'), findsNothing);
    expect(find.textContaining('↑'), findsNothing);

    await tester.tap(find.text(t.transferTab.sortSize));
    await tester.pumpAndSettle();

    expect(find.text(t.transferTab.sortSize), findsOneWidget);
    expect(find.text(t.transferTab.sortDate), findsNothing);
  });

  // The row's ⋯ sits ~10px inside the window edge, and MenuAnchor clamps an
  // overflowing panel flush against that edge, which is why the panel is now
  // placed by its right edge on the trigger's.
  testWidgets('the row action menu keeps a gap to the window edge', (tester) async {
    await _pumpDetailPage(tester, size: const Size(420, 780));

    // The view mode is remembered between pages, so an earlier test may have left
    // the page in grid mode, which has no per-row menu.
    if (find.byIcon(LucideIcons.moreHorizontal).evaluate().isEmpty) {
      await tester.tap(find.byIcon(LucideIcons.list));
      await tester.pumpAndSettle();
    }

    final trigger = find.byIcon(LucideIcons.moreHorizontal).first;
    final triggerRect = tester.getRect(trigger);
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    final panel = tester.getRect(find.byType(MenuItemButton).first);
    expect(panel.width, 150);
    expect(panel.right, greaterThan(triggerRect.left));
    expect(panel.right, lessThanOrEqualTo(420 - 8));
  });
}
