import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
}
