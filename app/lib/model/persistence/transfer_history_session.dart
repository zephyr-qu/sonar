import 'package:dart_mappable/dart_mappable.dart';
import 'package:localsend_isolates/model/dto/file_dto.dart';
import 'package:localsend_isolates/model/file_type.dart';

part 'transfer_history_session.mapper.dart';

/// Whether this session sent files to a device or received them from one.
@MappableEnum(defaultValue: TransferHistoryDirection.receive)
enum TransferHistoryDirection { send, receive }

/// One file of a finished transfer session, kept for the transfer history.
@MappableClass()
class TransferHistoryFile with TransferHistoryFileMappable {
  final String id;
  final String fileName;
  final FileType fileType;
  final int fileSize;

  /// Local path of the file. Null for sent files (the sender does not own the
  /// copy on the receiving device) and for text messages.
  final String? path;

  final bool savedToGallery;
  final bool isMessage;

  /// The `metadata.modified` timestamp the sender announced in the protocol.
  /// Null when the sender did not provide one.
  final DateTime? modified;

  const TransferHistoryFile({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.path,
    required this.savedToGallery,
    required this.isMessage,
    required this.modified,
  });

  /// `metadata.modified` is an RFC 3339 string (with nanosecond precision,
  /// which [DateTime.parse] truncates to microseconds).
  static DateTime? parseModified(FileMetadata? metadata) {
    final raw = metadata?.lastModified;
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  static const fromJson = TransferHistoryFileMapper.fromJson;
}

/// One finished transfer: the unit the transfer tab lists.
@MappableClass()
class TransferHistorySession with TransferHistorySessionMappable {
  final String id;

  /// Alias of the remote device, already resolved against the favorites.
  final String peerAlias;
  final TransferHistoryDirection direction;

  /// When the session started (UTC).
  final DateTime timestamp;

  final List<TransferHistoryFile> files;

  const TransferHistorySession({
    required this.id,
    required this.peerAlias,
    required this.direction,
    required this.timestamp,
    required this.files,
  });

  bool get isSend => direction == TransferHistoryDirection.send;

  int get totalSize => files.fold(0, (sum, file) => sum + file.fileSize);

  bool get hasMessage => files.any((file) => file.isMessage);

  String? get message => files.where((file) => file.isMessage).map((file) => file.fileName).firstOrNull;

  /// Whether every file of this session went to the gallery.
  bool get savedToGallery => files.isNotEmpty && files.every((file) => file.savedToGallery);

  bool get hasLocalPath => files.any((file) => file.path != null && file.path!.isNotEmpty);

  TransferHistorySession withFiles(List<TransferHistoryFile> files) {
    return copyWith(files: files);
  }

  static const fromJson = TransferHistorySessionMapper.fromJson;
}
