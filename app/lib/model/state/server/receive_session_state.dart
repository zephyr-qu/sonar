import 'package:dart_mappable/dart_mappable.dart';
import 'package:sonar/model/state/server/receiving_file.dart';
import 'package:sonar_isolates/model/device.dart';
import 'package:sonar_isolates/model/file_type.dart';
import 'package:sonar_isolates/model/session_status.dart';

part 'receive_session_state.mapper.dart';

abstract class SessionState {
  SessionStatus get status;
  int? get startTime;
  int? get endTime;
}

@MappableClass()
class ReceiveSessionState with ReceiveSessionStateMappable implements SessionState {
  final String sessionId;

  @override
  final SessionStatus status;

  final Device sender;

  // Might not be the same as sender.alias since it can be overridden as a favorite
  final String senderAlias;

  final Map<String, ReceivingFile> files; // file id as key

  @override
  final int? startTime;

  @override
  final int? endTime;

  final String destinationDirectory;
  final String cacheDirectory;
  final bool saveToGallery;

  /// Whether the request was accepted without asking (quick save or receive via link).
  ///
  /// Such a request opens no page of its own, so the Transfers tab marks it instead.
  final bool autoAccepted;

  /// On Android, we need to manually create missing directories.
  /// To improve performance, we cache the created directories so we don't need to check them again.
  /// WARNING: This list is modified in-place!
  final Set<String> createdDirectories;

  /// Files whose sender-provided SHA-256 was verified and matched.
  ///
  /// Filled in by the server when the session ends, so it stays 0 while the
  /// transfer is still running.
  final int checksumVerified;

  /// Files that arrived without a usable checksum, i.e. the sender did not
  /// compute one or checksum verification is disabled.
  final int checksumUnchecked;

  /// Whether at least one file was verified, i.e. the checksum row is worth
  /// showing.
  bool get hasChecksumReport => checksumVerified > 0;

  const ReceiveSessionState({
    required this.sessionId,
    required this.status,
    required this.sender,
    required this.senderAlias,
    required this.files,
    required this.startTime,
    required this.endTime,
    required this.destinationDirectory,
    required this.cacheDirectory,
    required this.saveToGallery,
    this.autoAccepted = false,
    required this.createdDirectories,
    this.checksumVerified = 0,
    this.checksumUnchecked = 0,
  });

  /// Returns the message of this request if this is a "message request".
  /// Message requests must contain a single text file with preview included.
  String? get message {
    final firstFile = files.values.first.file;
    return files.length == 1 && firstFile.fileType == FileType.text ? firstFile.preview : null;
  }

  /// Returns true if this request contains files having a directory path.
  /// "Save to gallery" is disabled for such requests.
  bool get containsDirectories {
    return files.values.any((f) => f.file.fileName.contains('/'));
  }
}
