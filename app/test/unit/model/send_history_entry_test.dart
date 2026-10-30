import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/model/persistence/send_history_entry.dart';
import 'package:localsend_isolates/model/file_type.dart';

void main() {
  test('SendHistoryEntry survives a JSON round trip', () {
    final entry = SendHistoryEntry(
      id: 'session-1-file-1',
      fileName: 'photo.heic',
      fileType: FileType.image,
      fileSize: 2048,
      receiverAlias: 'Kai 的 iPhone',
      timestamp: DateTime.utc(2026, 10, 29, 12, 30),
    );

    final decoded = SendHistoryEntry.fromJson(entry.toJson());

    expect(decoded.id, entry.id);
    expect(decoded.fileName, entry.fileName);
    expect(decoded.fileType, entry.fileType);
    expect(decoded.fileSize, entry.fileSize);
    expect(decoded.receiverAlias, entry.receiverAlias);
    expect(decoded.timestamp, entry.timestamp);
  });
}
