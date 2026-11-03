import 'dart:async';

import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar_isolates/src/isolate/child/sync_provider.dart';
import 'package:sonar_isolates/src/isolate/dto/send_to_isolate_data.dart';
import 'package:sonar_isolates/util/logger.dart';
import 'package:sonar_isolates/util/rust.dart';
import 'package:sonar_isolates/util/rust_init.dart';

final _logger = Logger('ChildIsolateMain');

/// The container for the child isolate.
final _isolateContainer = RefenaContainer();

class InitialData {
  final SyncState syncState;
  final Level logLevel;

  InitialData({
    required this.syncState,
    required this.logLevel,
  });
}

/// A helper to setup the child isolate,
/// constructing an endless running task that listens to [receiveFromMain]
/// and calls [handler] for each message (usually calling [sendToMain] in the [handler]).
///
/// The provided [Ref]s in the [handler] and [init] functions are instance of the child isolate [RefenaContainer],
/// therefore, they can be safely used to call providers in the task directory.
///
/// A [handler] that throws would otherwise leave its caller waiting forever,
/// because the main isolate only ends a task's stream on a result the child
/// sends. Supply [taskIdOf] and [errorResultOf] so that a failed [handler] is
/// answered with a terminal error result instead of only being logged.
///
/// An optional [init] function can be provided to run before the endless loop.
Future<void> setupChildIsolateHelper<S, R>({
  required String debugLabel,
  required Stream<SendToIsolateData<S>> receiveFromMain,
  required void Function(R) sendToMain,
  required InitialData initialData,
  Future<void> Function(Ref ref)? init,
  required Future<void> Function(Ref ref, S data) handler,
  int Function(S data)? taskIdOf,
  R Function(int taskId, String error)? errorResultOf,
}) async {
  initLogger(initialData.logLevel);

  // Uncaught async errors are fatal to the isolate by default, which would
  // silently kill the server/upload loop; log them instead.
  await runZonedGuarded(
    () async {
      await _isolateContainer.set(
        syncProvider.overrideWithNotifier(
          (ref) => SyncService(
            initial: initialData.syncState,
          ),
        ),
      );

      await initRustLib();

      if (init != null) {
        await init(_isolateContainer);
      }

      _logger.info('Child isolate is ready: $debugLabel (logLevel: ${initialData.logLevel})');

      await for (final message in receiveFromMain) {
        _handleMessage(
          debugLabel,
          message,
          handler,
          sendToMain: sendToMain,
          taskIdOf: taskIdOf,
          errorResultOf: errorResultOf,
        );
      }
    },
    (e, st) {
      _logger.severe('Uncaught error in $debugLabel', e, st);
    },
  );
}

// separate function to avoid blocking the for loop
void _handleMessage<S, R>(
  String debugLabel,
  SendToIsolateData<S> message,
  Future<void> Function(Ref ref, S data) handler, {
  required void Function(R) sendToMain,
  int Function(S data)? taskIdOf,
  R Function(int taskId, String error)? errorResultOf,
}) async {
  final syncState = message.syncState;
  if (syncState != null) {
    _isolateContainer.redux(syncProvider).dispatch(UpdateSyncStateAction(syncState));
  }

  final data = message.data;
  if (data != null) {
    try {
      await handler(_isolateContainer, data);
    } catch (e, st) {
      _logger.severe('Error in $debugLabel: $e', e, st);
      if (taskIdOf != null && errorResultOf != null) {
        // The caller ends its stream on a terminal result only, so answering
        // with nothing here would make it wait forever.
        sendToMain(errorResultOf(taskIdOf(data), e.humanErrorMessage));
      }
    }
  }
}
