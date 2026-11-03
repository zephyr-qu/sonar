import 'package:mockito/mockito.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/model/persistence/transfer_history_session.dart';
import 'package:sonar/provider/transfer_history_provider.dart';
import 'package:sonar_isolates/model/file_type.dart';
import 'package:test/test.dart';

import '../../mocks.mocks.dart';

void main() {
  late MockPersistenceService persistenceService;

  setUp(() {
    persistenceService = MockPersistenceService();
    when(persistenceService.isSaveToHistory()).thenReturn(true);
  });

  test('Should add a session', () async {
    final service = ReduxNotifier.test(
      redux: TransferHistoryService(persistenceService),
    );

    expect(service.state, []);

    final session = _createSession('1');
    await service.dispatchAsync(AddTransferHistorySessionAction(session));

    expect(service.state, [session]);
    verify(persistenceService.setTransferHistory([session]));
  });

  test('Should not add a session when saving the history is disabled', () async {
    when(persistenceService.isSaveToHistory()).thenReturn(false);

    final service = ReduxNotifier.test(
      redux: TransferHistoryService(persistenceService),
    );

    await service.dispatchAsync(AddTransferHistorySessionAction(_createSession('1')));

    expect(service.state, []);
    verifyNever(persistenceService.setTransferHistory(any));
  });

  test('Should read a session stored before the outcome was recorded', () {
    final stored = _createSession('1').toJson()
      ..remove('failed')
      ..remove('errorMessage');

    final restored = TransferHistorySession.fromJson(stored);

    expect(restored.failed, isFalse);
    expect(restored.errorMessage, isNull);
  });

  test('Should keep one record per session when it finishes twice', () async {
    final failed = _createSession('1', failed: true, errorMessage: 'No response');
    final service = ReduxNotifier.test(
      redux: TransferHistoryService(persistenceService),
      initialState: [failed],
    );

    // A failed send can be retried: the newer outcome replaces the older one
    // instead of leaving a failed row next to a delivered one.
    final delivered = _createSession('1');
    await service.dispatchAsync(AddTransferHistorySessionAction(delivered));

    expect(service.state, [delivered]);
    verify(persistenceService.setTransferHistory([delivered]));
  });

  test('Should keep the newest session first', () async {
    final older = _createSession('1', timestamp: DateTime.utc(2024, 1, 1));
    final newer = _createSession('2', timestamp: DateTime.utc(2024, 6, 1));
    final service = ReduxNotifier.test(
      redux: TransferHistoryService(persistenceService),
      initialState: [older],
    );

    await service.dispatchAsync(AddTransferHistorySessionAction(newer));

    expect(service.state, [newer, older]);
  });

  test('Should cap the history at 100 sessions', () async {
    final initial = [for (var i = 0; i < 100; i++) _createSession('$i', timestamp: DateTime.utc(2024, 1, 1).add(Duration(minutes: i)))];
    final service = ReduxNotifier.test(
      redux: TransferHistoryService(persistenceService),
      initialState: initial,
    );

    final newest = _createSession('new', timestamp: DateTime.utc(2025, 1, 1));
    await service.dispatchAsync(AddTransferHistorySessionAction(newest));

    expect(service.state, hasLength(100));
    expect(service.state.first, newest);
    expect(service.state.last.id, '1');
  });

  test('Should remove a session', () async {
    final session = _createSession('1');
    final service = ReduxNotifier.test(
      redux: TransferHistoryService(persistenceService),
      initialState: [session],
    );

    await service.dispatchAsync(RemoveTransferHistorySessionAction('1'));

    expect(service.state, []);
    verify(persistenceService.setTransferHistory([]));
  });

  test('Should not persist when removing an unknown session', () async {
    final service = ReduxNotifier.test(
      redux: TransferHistoryService(persistenceService),
      initialState: [_createSession('1')],
    );

    await service.dispatchAsync(RemoveTransferHistorySessionAction('2'));

    expect(service.state, hasLength(1));
    verifyNever(persistenceService.setTransferHistory(any));
  });

  test('Should remove one file of a session', () async {
    final session = _createSession('1', fileCount: 2);
    final service = ReduxNotifier.test(
      redux: TransferHistoryService(persistenceService),
      initialState: [session],
    );

    await service.dispatchAsync(RemoveTransferHistoryFileAction(sessionId: '1', fileId: '1-0'));

    expect(service.state, hasLength(1));
    expect(service.state.first.files.map((file) => file.id), ['1-1']);
    verify(persistenceService.setTransferHistory([service.state.first]));
  });

  test('Should remove the session when its last file is removed', () async {
    final service = ReduxNotifier.test(
      redux: TransferHistoryService(persistenceService),
      initialState: [_createSession('1')],
    );

    await service.dispatchAsync(RemoveTransferHistoryFileAction(sessionId: '1', fileId: '1-0'));

    expect(service.state, []);
    verify(persistenceService.setTransferHistory([]));
  });

  test('Should remove the whole history', () async {
    final service = ReduxNotifier.test(
      redux: TransferHistoryService(persistenceService),
      initialState: [_createSession('1'), _createSession('2')],
    );

    await service.dispatchAsync(RemoveAllTransferHistorySessionsAction());

    expect(service.state, []);
    verify(persistenceService.setTransferHistory([]));
  });
}

TransferHistorySession _createSession(
  String id, {
  DateTime? timestamp,
  int fileCount = 1,
  bool failed = false,
  String? errorMessage,
}) {
  return TransferHistorySession(
    id: id,
    peerAlias: 'peer',
    direction: TransferHistoryDirection.receive,
    timestamp: timestamp ?? DateTime.utc(2024, 1, 1),
    files: [
      for (var i = 0; i < fileCount; i++)
        TransferHistoryFile(
          id: '$id-$i',
          fileName: 'file$i.jpg',
          fileType: FileType.image,
          fileSize: 1024,
          path: '/tmp/file$i.jpg',
          savedToGallery: true,
          isMessage: false,
          modified: null,
        ),
    ],
    failed: failed,
    errorMessage: errorMessage,
  );
}
