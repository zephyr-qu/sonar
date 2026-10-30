import 'package:localsend_app/model/persistence/send_history_entry.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

const _maxHistoryEntries = 30;

/// Stores the files that were successfully sent, mirroring
/// [receiveHistoryProvider]. Entries are written once per finished session;
/// sessions that end with errors or are canceled are not recorded.
final sendHistoryProvider = ReduxProvider<SendHistoryService, List<SendHistoryEntry>>((ref) {
  return SendHistoryService(ref.read(persistenceProvider));
});

class SendHistoryService extends ReduxNotifier<List<SendHistoryEntry>> {
  final PersistenceService _persistence;

  SendHistoryService(this._persistence);

  @override
  List<SendHistoryEntry> init() => _persistence.getSendHistory();
}

/// Adds the entries of one finished send session (newest first).
class AddSendHistoryEntriesAction extends AsyncReduxAction<SendHistoryService, List<SendHistoryEntry>> {
  final List<SendHistoryEntry> entries;

  AddSendHistoryEntriesAction(this.entries);

  @override
  Future<List<SendHistoryEntry>> reduce() async {
    if (!notifier._persistence.isSaveToHistory()) {
      return state;
    }

    final updated = [...entries, ...state].take(_maxHistoryEntries).toList();
    await notifier._persistence.setSendHistory(updated);
    return updated;
  }
}

/// Removes all sent history entries.
class RemoveAllSendHistoryEntriesAction extends AsyncReduxAction<SendHistoryService, List<SendHistoryEntry>> {
  @override
  Future<List<SendHistoryEntry>> reduce() async {
    await notifier._persistence.setSendHistory([]);
    return [];
  }
}
