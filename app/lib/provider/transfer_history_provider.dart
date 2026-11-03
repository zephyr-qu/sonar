import 'package:collection/collection.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/model/persistence/transfer_history_session.dart';
import 'package:sonar/provider/persistence_provider.dart';

/// How many finished sessions are kept. One session holds all files of one
/// transfer, so this keeps far more files than the old per-file limit.
const _maxHistorySessions = 100;

/// Stores the transfer history, one entry per finished session.
/// It automatically saves the history to the device's storage.
///
/// Only fully successful sessions are recorded; canceled sessions and sessions
/// that ended with errors are not listed.
final transferHistoryProvider = ReduxProvider<TransferHistoryService, List<TransferHistorySession>>((ref) {
  return TransferHistoryService(ref.read(persistenceProvider));
});

class TransferHistoryService extends ReduxNotifier<List<TransferHistorySession>> {
  final PersistenceService _persistence;

  TransferHistoryService(this._persistence);

  @override
  List<TransferHistorySession> init() => _persistence.getTransferHistory();
}

/// Adds one finished session (newest first).
class AddTransferHistorySessionAction extends AsyncReduxAction<TransferHistoryService, List<TransferHistorySession>> {
  final TransferHistorySession session;

  AddTransferHistorySessionAction(this.session);

  @override
  Future<List<TransferHistorySession>> reduce() async {
    if (!notifier._persistence.isSaveToHistory()) {
      return state;
    }

    // The same session can be finalized by more than one event, and a failed
    // send can be retried afterwards: the newest record of a session wins.
    final others = state.where((s) => s.id != session.id).toList();
    final updated = [session, ...others]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final trimmed = updated.take(_maxHistorySessions).toList();
    await notifier._persistence.setTransferHistory(trimmed);
    return trimmed;
  }
}

/// Removes one session.
class RemoveTransferHistorySessionAction extends AsyncReduxAction<TransferHistoryService, List<TransferHistorySession>> {
  final String sessionId;

  RemoveTransferHistorySessionAction(this.sessionId);

  @override
  Future<List<TransferHistorySession>> reduce() async {
    final updated = state.where((s) => s.id != sessionId).toList();
    if (updated.length == state.length) {
      return state;
    }
    await notifier._persistence.setTransferHistory(updated);
    return updated;
  }
}

/// Removes one file from a session. The session itself is removed when its last
/// file is removed.
class RemoveTransferHistoryFileAction extends AsyncReduxAction<TransferHistoryService, List<TransferHistorySession>> {
  final String sessionId;
  final String fileId;

  RemoveTransferHistoryFileAction({required this.sessionId, required this.fileId});

  @override
  Future<List<TransferHistorySession>> reduce() async {
    final session = state.firstWhereOrNull((s) => s.id == sessionId);
    if (session == null) {
      return state;
    }

    final files = session.files.where((f) => f.id != fileId).toList();
    final updated = files.isEmpty
        ? state.where((s) => s.id != sessionId).toList()
        : [for (final s in state) s.id == sessionId ? s.withFiles(files) : s];
    await notifier._persistence.setTransferHistory(updated);
    return updated;
  }
}

/// Removes the whole history.
class RemoveAllTransferHistorySessionsAction extends AsyncReduxAction<TransferHistoryService, List<TransferHistorySession>> {
  @override
  Future<List<TransferHistorySession>> reduce() async {
    await notifier._persistence.setTransferHistory([]);
    return [];
  }
}
