import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier, immutable;
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar_isolates/model/file_status.dart';

/// A provider holding the live per-file transfer state (status and progress).
/// It is implemented as [ChangeNotifier] for performance reasons:
/// a status or progress update does not need to copy the whole session state.
///
/// Progress is the hottest signal in the app (Rust throttles it to one event per
/// file and 20ms, so up to 50 events per second per file), therefore it does
/// *not* call [ChangeNotifier.notifyListeners]. Widgets that display a single
/// file subscribe to [fileListenable], widgets that aggregate a session
/// (progress bar, totals, speed) subscribe to [sessionTick]. Only status changes
/// and session removal notify the notifier itself.
final fileTransferProvider = ChangeNotifierProvider((ref) => FileTransferNotifier());

@immutable
class FileTransfer {
  final FileStatus status;
  final double progress; // 0..1

  const FileTransfer(this.status, {this.progress = 0});

  FileTransfer copyWith({FileStatus? status, double? progress}) {
    return FileTransfer(status ?? this.status, progress: progress ?? this.progress);
  }

  @override
  bool operator ==(Object other) {
    return other is FileTransfer && other.status == status && other.progress == progress;
  }

  @override
  int get hashCode => Object.hash(status, progress);

  @override
  String toString() => '($status, $progress)';
}

class FileTransferNotifier extends ChangeNotifier {
  final _sessionMap = <String, Map<String, FileTransfer>>{}; // session id -> (file id -> live transfer state)

  /// session id -> (file id -> listenable of that single file).
  final _fileListenables = <String, Map<String, ValueNotifier<FileTransfer>>>{};

  /// session id -> counter that is incremented on every update of any file of that session.
  final _sessionTicks = <String, ValueNotifier<int>>{};

  /// Returns the live state of a single file.
  ///
  /// The returned listenable only notifies when the value of *this* file changes,
  /// so a file row can rebuild without touching any other row.
  ValueListenable<FileTransfer> fileListenable({required String sessionId, required String fileId}) {
    final files = _fileListenables.putIfAbsent(sessionId, () => {});
    return files.putIfAbsent(fileId, () => ValueNotifier(_sessionMap[sessionId]?[fileId] ?? const FileTransfer(FileStatus.queue)));
  }

  /// Returns a counter that is incremented on every status or progress update of
  /// any file in the session.
  ///
  /// Use it for aggregate widgets (progress bar, totals, session card headers)
  /// that need to re-read several files per update. It is much cheaper than
  /// watching [fileTransferProvider], which would rebuild the whole page.
  ValueListenable<int> sessionTick(String sessionId) => _sessionTicks.putIfAbsent(sessionId, () => ValueNotifier(0));

  /// Writes [next] for one file and notifies the per-file listenable.
  /// Returns whether anything changed.
  bool _write({required String sessionId, required String fileId, required FileTransfer next}) {
    final files = _sessionMap.putIfAbsent(sessionId, () => {});
    if (files[fileId] == next) {
      return false;
    }
    files[fileId] = next;
    _fileListenables[sessionId]?[fileId]?.value = next;
    return true;
  }

  void _tick(String sessionId) {
    final tick = _sessionTicks[sessionId];
    if (tick != null) {
      tick.value++;
    }
  }

  void setStatus({required String sessionId, required String fileId, required FileStatus status}) {
    final changed = _write(
      sessionId: sessionId,
      fileId: fileId,
      next: (_sessionMap[sessionId]?[fileId] ?? const FileTransfer(FileStatus.queue)).copyWith(status: status),
    );
    if (!changed) {
      return;
    }
    _tick(sessionId);
    notifyListeners();
  }

  /// Sets the status of multiple files at once, notifying listeners only once.
  void setStatuses({required String sessionId, required Map<String, FileStatus> statuses}) {
    var changed = false;
    for (final entry in statuses.entries) {
      changed |= _write(
        sessionId: sessionId,
        fileId: entry.key,
        next: (_sessionMap[sessionId]?[entry.key] ?? const FileTransfer(FileStatus.queue)).copyWith(status: entry.value),
      );
    }
    if (!changed) {
      return;
    }
    _tick(sessionId);
    notifyListeners();
  }

  /// Updates the progress of a single file.
  ///
  /// Deliberately does *not* call [notifyListeners]: only the listenables of that
  /// file and of its session are notified.
  void setProgress({required String sessionId, required String fileId, required double progress}) {
    final changed = _write(
      sessionId: sessionId,
      fileId: fileId,
      next: (_sessionMap[sessionId]?[fileId] ?? const FileTransfer(FileStatus.queue)).copyWith(progress: progress),
    );
    if (!changed) {
      return;
    }
    _tick(sessionId);
  }

  FileStatus getStatus({required String sessionId, required String fileId}) {
    return _sessionMap[sessionId]?[fileId]?.status ?? FileStatus.queue;
  }

  Iterable<FileStatus> getStatuses(String sessionId) {
    return _sessionMap[sessionId]?.values.map((file) => file.status) ?? const [];
  }

  double getProgress({required String sessionId, required String fileId}) {
    return _sessionMap[sessionId]?[fileId]?.progress ?? 0.0;
  }

  void removeSession(String sessionId) {
    _sessionMap.remove(sessionId);
    // The listenables are not disposed: widgets that are still on screen hold them
    // directly and keep working until they are removed from the tree.
    _fileListenables.remove(sessionId);
    _sessionTicks.remove(sessionId);
    notifyListeners();
  }

  void removeAllSessions() {
    _sessionMap.clear();
    _fileListenables.clear();
    _sessionTicks.clear();
    notifyListeners();
  }

  /// Only for debug purposes
  Map<String, Map<String, FileTransfer>> getData() {
    return _sessionMap;
  }

  @override
  void dispose() {
    for (final files in _fileListenables.values) {
      for (final listenable in files.values) {
        listenable.dispose();
      }
    }
    for (final tick in _sessionTicks.values) {
      tick.dispose();
    }
    super.dispose();
  }
}
