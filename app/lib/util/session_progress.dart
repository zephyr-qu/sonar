import 'package:sonar/provider/file_transfer_provider.dart';

/// The progress of one transfer session, weighted by file size.
///
/// Progress events arrive per file, so the session's transferred bytes are the
/// sum of each file's fraction scaled by its own size: a 1 GB file at 50 % counts
/// far more than a 1 KB file at 100 %. The bar and the byte caption have to agree
/// on that, so every card, the mini bar and the progress page measure it here
/// instead of folding the files again.
class SessionProgress {
  /// Bytes the counted files have transferred so far.
  final int transferred;

  /// Bytes the session covers.
  ///
  /// Normally the size sum of the files passed to [SessionProgress.measure], but
  /// a send session also counts the files the receiver has not accepted yet: they
  /// appear in the "x / y" caption without having moved a byte.
  final int total;

  const SessionProgress(this.transferred, this.total);

  /// Measures [files] against [total], or against their own size when [total] is
  /// omitted. Every entry is a `(fileId, sizeInBytes)` pair.
  factory SessionProgress.measure({
    required String sessionId,
    required Iterable<(String, int)> files,
    required FileTransferNotifier transfer,
    int? total,
  }) {
    var transferred = 0;
    var size = 0;
    for (final (fileId, fileSize) in files) {
      size += fileSize;
      transferred += (transfer.getProgress(sessionId: sessionId, fileId: fileId) * fileSize).round();
    }
    return SessionProgress(transferred, total ?? size);
  }

  /// The transferred share, 0..1. A session without files has nothing to show.
  double get fraction => total <= 0 ? 0.0 : (transferred / total).clamp(0.0, 1.0);
}
