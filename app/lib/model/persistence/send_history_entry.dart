import 'package:dart_mappable/dart_mappable.dart';
import 'package:localsend_isolates/model/file_type.dart';

part 'send_history_entry.mapper.dart';

/// One file that was delivered to another device.
///
/// The receive counterpart is [ReceiveHistoryEntry]: together they form the
/// "Transfers" history, which is why both carry the file metadata and the
/// alias of the other side.
@MappableClass()
class SendHistoryEntry with SendHistoryEntryMappable {
  final String id;
  final String fileName;
  final FileType fileType;
  final int fileSize;
  final String receiverAlias;

  /// UTC timestamp, formatted for display via `SystemDateTimeFormatter`.
  final DateTime timestamp;

  const SendHistoryEntry({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.receiverAlias,
    required this.timestamp,
  });

  static const fromJson = SendHistoryEntryMapper.fromJson;
}
