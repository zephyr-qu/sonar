import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:refena_flutter/addons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/persistence/transfer_history_session.dart';
import 'package:sonar/model/state/server/receive_session_state.dart';
import 'package:sonar/model/state/server/receiving_file.dart';
import 'package:sonar/pages/home_page.dart';
import 'package:sonar/pages/home_page_controller.dart';
import 'package:sonar/pages/receive_page.dart';
import 'package:sonar/provider/app_lifecycle_provider.dart';
import 'package:sonar/provider/device_info_provider.dart';
import 'package:sonar/provider/favorites_provider.dart';
import 'package:sonar/provider/file_transfer_provider.dart';
import 'package:sonar/provider/http_provider.dart';
import 'package:sonar/provider/logging/discovery_logs_provider.dart';
import 'package:sonar/provider/network/send_provider.dart';
import 'package:sonar/provider/network/server/server_provider.dart';
import 'package:sonar/provider/network/server/server_utils.dart';
import 'package:sonar/provider/security_provider.dart';
import 'package:sonar/provider/selection/selected_receiving_files_provider.dart';
import 'package:sonar/provider/selection/selected_sending_files_provider.dart';
import 'package:sonar/provider/settings_provider.dart';
import 'package:sonar/provider/transfer_history_provider.dart';
import 'package:sonar/util/native/directories.dart';
import 'package:sonar/util/native/platform_check.dart';
import 'package:sonar/util/native/request_notification.dart';
import 'package:sonar/util/native/tray_helper.dart';
import 'package:sonar/util/transfer_failure.dart';
import 'package:sonar/widget/dialogs/open_file_dialog.dart';
import 'package:sonar_isolates/isolate.dart';
import 'package:sonar_isolates/model/device.dart';
import 'package:sonar_isolates/model/file_status.dart';
import 'package:sonar_isolates/model/file_type.dart';
import 'package:sonar_isolates/model/session_status.dart';
import 'package:sonar_isolates/rust/api/server.dart' show SessionEndReasonV2;
import 'package:sonar_isolates/util/rust.dart';
import 'package:sonar_isolates/util/transfer_notification.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';

final _logger = Logger('ReceiveController');

/// Handles all server events for receiving files.
/// The HTTP requests themselves are served by the Rust server which emits
/// the events handled here.
class ReceiveController {
  final ServerUtils server;

  ReceiveController(this.server);

  /// A device registered itself on this server.
  Future<void> onRegister(HttpServerRegisterEvent event) async {
    if (event.info.fingerprint == server.ref.read(securityProvider).certificateHash) {
      // "I talked to myself lol"
      return;
    }

    // Feed the device into the discovery store; it comes back (and is
    // registered) via the [StartDiscoveryListener] stream.
    server.ref.redux(parentIsolateProvider).dispatch(IsolateDiscoveryAddDeviceAction(device: event.info.toDevice(event.ip, withChannel: true)));
    server.ref.notifier(discoveryLoggerProvider).addLog('[DISCOVER/TCP] Received "/register" HTTP request: ${event.info.alias} (${event.ip})');
  }

  /// A sender requests to upload files.
  /// The Rust server already checked the PIN and enforces that only one
  /// session can be active at a time.
  Future<void> onPrepareUpload(HttpServerPrepareUploadEvent event) async {
    if (server.getStateOrNull()?.session != null) {
      // The Rust server is the authority on the single-session invariant:
      // a new request means the old session is over (e.g. finished but still
      // displayed, or aborted while waiting).
      closeSession();
    }

    final settings = server.ref.read(settingsProvider);
    final destinationDir = settings.destination ?? await getDefaultDestinationDirectory();
    final cacheDir = await getCacheDirectory();
    final sessionId = event.sessionId;
    final files = {
      for (final entry in event.files.entries) entry.key: entry.value.toDart(),
    };

    // The fingerprint of the sender's mTLS certificate cannot be spoofed, unlike the
    // self-reported fingerprint in the JSON payload which is only used as fallback
    // when encryption is disabled.
    final senderFingerprint = event.certFingerprint ?? event.info.fingerprint;

    _logger.info('Session Id: $sessionId');
    _logger.info('Destination Directory: $destinationDir');

    server.setState(
      (oldState) => oldState?.copyWith(
        session: ReceiveSessionState(
          sessionId: sessionId,
          status: SessionStatus.waiting,
          sender: event.info.toDevice(event.ip, withChannel: false).copyWith(fingerprint: senderFingerprint),
          senderAlias: server.ref.read(favoritesProvider).firstWhereOrNull((e) => e.fingerprint == senderFingerprint)?.alias ?? event.info.alias,
          files: {
            for (final file in files.values)
              file.id: ReceivingFile(
                file: file,
                token: null,
                desiredName: null,
                path: null,
                savedToGallery: false,
                errorMessage: null,
              ),
          },
          startTime: null,
          endTime: null,
          destinationDirectory: destinationDir,
          cacheDirectory: cacheDir,
          saveToGallery: checkPlatformWithGallery() && settings.saveToGallery && files.values.every((f) => !f.fileName.contains('/')),
          createdDirectories: {},
        ),
      ),
    );

    server.ref
        .notifier(fileTransferProvider)
        .setStatuses(
          sessionId: sessionId,
          statuses: {for (final file in files.values) file.id: FileStatus.queue},
        );

    bool quickSave = settings.quickSave && server.getState().session?.message == null;
    // A favorite may only be trusted when the fingerprint came from the TLS client
    // certificate: the payload fingerprint is self-reported, so with encryption off
    // (or a web share making client certificates optional) any peer could claim to
    // be a favorite and have its files written without a prompt.
    final quickSaveFromFavorites = settings.quickSaveFromFavorites && event.certFingerprint != null && server.getState().session?.message == null;
    if (quickSaveFromFavorites) {
      final bool isFavorite = server.ref.read(favoritesProvider).any((e) => e.fingerprint == senderFingerprint);
      if (isFavorite) {
        quickSave = true;
      }
    }
    if (server.getState().webUpload && settings.receiveViaLinkAutoAccept && server.getState().session?.message == null) {
      // The upload page (receive via link) is being served and requests should be accepted automatically.
      quickSave = true;
    }

    if (quickSave) {
      // Recorded so that the Transfers tab can mark the session: no page of its own opens for it.
      server.setState((oldState) => oldState?.copyWith(session: oldState.session?.copyWith(autoAccepted: true)));
      // Nothing is pushed on purpose: an auto-accepted request must not take the window away from
      // whatever the user is doing. The Transfers tab shows the session and its progress instead.
      await acceptFileRequest({
        for (final f in files.values) f.id: f.fileName,
      });
      return;
    }

    if (checkPlatformHasTray() && (await windowManager.isMinimized() || !(await windowManager.isVisible()) || !(await windowManager.isFocused()))) {
      await showFromTray();
    }

    final message = server.getState().session?.message;
    if (message != null && server.ref.read(settingsProvider).saveToHistory) {
      // Message already received
      await server.ref
          .redux(transferHistoryProvider)
          .dispatchAsync(
            AddTransferHistorySessionAction(
              TransferHistorySession(
                id: server.getState().session!.sessionId,
                peerAlias: server.getState().session!.senderAlias,
                direction: TransferHistoryDirection.receive,
                timestamp: DateTime.now().toUtc(),
                files: [
                  TransferHistoryFile(
                    id: const Uuid().v4(),
                    fileName: message,
                    fileType: FileType.text,
                    fileSize: utf8.encode(message).length,
                    path: null,
                    savedToGallery: false,
                    isMessage: true,
                    modified: null,
                  ),
                ],
              ),
            ),
          );
    }

    if (message == null) {
      _notifyIfInBackground();
    }

    final receiveProvider = ViewProvider((ref) {
      // No select: comparing the selected session runs the dart_mappable deep equality
      // over the whole files map on every state change.
      final session = ref.watch(serverProvider)?.session;
      return ReceivePageVm(
        status: session?.status,
        sender: session?.sender ?? Device.empty,
        showSenderInfo: true,
        files: session?.files.values.map((f) => f.file).toList() ?? [],
        message: message,
        onAccept: () async {
          if (message != null) {
            // accept nothing
            await ref.notifier(serverProvider).acceptFileRequest({});
            return;
          }

          final sessionId = ref.read(serverProvider)?.session?.sessionId;
          if (sessionId == null) {
            return;
          }

          final selectedFiles = ref.read(selectedReceivingFilesProvider);

          // The request is answered, so the dialog has done its job. The transfer
          // runs in the background from here (Transfers tab, and on mobile the
          // strip above the tab bar): nothing replaces the shell.
          // The notifier is captured before popping: the pop disposes the
          // dialog's view model, whose `ref` must not be used afterwards.
          final serverNotifier = ref.notifier(serverProvider);
          Routerino.context.global.dispatch(NavigateAction.popUntilRoot());

          await serverNotifier.acceptFileRequest(selectedFiles);
        },
        onDecline: () {
          ref.notifier(serverProvider).declineFileRequest();
        },
        onClose: () {
          ref.notifier(serverProvider).closeSession();
        },
      );
    });

    server.ref.notifier(selectedReceivingFilesProvider).setFiles(files.values.toList());

    // ignore: use_build_context_synchronously, unawaited_futures
    unawaited(showReceiveRequestDialog(receiveProvider));
  }

  /// Tells the user about a pending request while the app is not on screen.
  ///
  /// Best effort by design: Android freezes a backgrounded app and may have dropped its sockets
  /// without any error, so a request can fail to arrive here at all. Quick save remains the
  /// reliable way to not miss one.
  void _notifyIfInBackground() {
    final session = server.getStateOrNull()?.session;
    if (session == null || session.status != SessionStatus.waiting) {
      return;
    }

    if (server.ref.read(appLifecycleProvider) == AppLifecycleState.resumed) {
      // The dialog is on screen (or about to be), so a notification would only duplicate it.
      return;
    }

    RequestNotification.show(
      title: session.senderAlias,
      // The wording of the request dialog, so the notification and the dialog it opens agree.
      text: t.receivePage.subTitle(n: session.files.length),
      channelName: t.receiveRequestPage.title,
    );
  }

  /// An accepted file started being uploaded.
  /// The server isolate receives and saves the file on its own
  /// ([HttpServerReceiveConfig] was sent with the accept decision);
  /// only the session state is updated here.
  void onFileUpload(HttpServerFileUploadEvent event) {
    final receiveState = server.getStateOrNull()?.session;
    const allowedStates = {SessionStatus.sending, SessionStatus.finishedWithErrors};
    if (receiveState == null || receiveState.sessionId != event.sessionId || !allowedStates.contains(receiveState.status)) {
      _logger.warning('Failing upload of file ${event.fileId}: no matching active session');
      // Fail the upload (and any further ones) by cancelling the session on the Rust side.
      server.ref.redux(parentIsolateProvider).dispatch(IsolateHttpServerCancelSessionAction(sessionId: event.sessionId));
      return;
    }

    final fileId = event.fileId;
    final receivingFile = receiveState.files[fileId];
    if (receivingFile == null || receivingFile.desiredName == null) {
      _logger.warning('Unexpected fileId: $fileId');
      server.ref.redux(parentIsolateProvider).dispatch(IsolateHttpServerCancelSessionAction(sessionId: event.sessionId));
      return;
    }

    // begin of actual file transfer
    server.ref.notifier(fileTransferProvider).setStatus(sessionId: event.sessionId, fileId: fileId, status: FileStatus.sending);
    if (receiveState.startTime == null || receiveState.status != SessionStatus.sending) {
      server.setState(
        (oldState) => oldState?.copyWith(
          session: receiveState.copyWith(
            startTime: receiveState.startTime ?? DateTime.now().millisecondsSinceEpoch,
            status: SessionStatus.sending, // in case it was finishedWithErrors and user retries a failed file
          ),
        ),
      );
    }
  }

  /// The receive progress of a file reported by the server isolate.
  void onFileUploadProgress(HttpServerFileUploadProgressEvent event) {
    final receiveState = server.getStateOrNull()?.session;
    if (receiveState == null || receiveState.sessionId != event.sessionId) {
      return;
    }

    server.ref
        .notifier(fileTransferProvider)
        .setProgress(
          sessionId: event.sessionId,
          fileId: event.fileId,
          progress: event.progress,
        );

    _updateForegroundServiceProgress(receiveState);
  }

  /// Reports the total session progress to the foreground service notification,
  /// so that it stays up to date while the app is minimized.
  void _updateForegroundServiceProgress(ReceiveSessionState session) {
    if (!TransferNotification.shouldUpdate) {
      // Checked before the sum below because progress events arrive several times per second per file.
      return;
    }

    final transferNotifier = server.ref.read(fileTransferProvider);
    int currentBytes = 0;
    int totalBytes = 0;
    for (final receivingFile in session.files.values) {
      if (receivingFile.desiredName == null) {
        // not accepted by the user
        continue;
      }
      final size = receivingFile.file.size;
      totalBytes += size;
      currentBytes += (transferNotifier.getProgress(sessionId: session.sessionId, fileId: receivingFile.file.id) * size).round();
    }

    TransferNotification.update(
      sessionId: session.sessionId,
      currentBytes: currentBytes,
      totalBytes: totalBytes,
      startTime: session.startTime,
      endTime: session.endTime,
    );
  }

  /// A file has been received completely (or failed) by the server isolate.
  Future<void> onFileUploadResult(HttpServerFileUploadResultEvent event) async {
    final receiveState = server.getStateOrNull()?.session;
    const allowedStates = {SessionStatus.sending, SessionStatus.finishedWithErrors};
    if (receiveState == null || receiveState.sessionId != event.sessionId || !allowedStates.contains(receiveState.status)) {
      return;
    }

    final fileId = event.fileId;
    final receivingFile = receiveState.files[fileId];
    if (receivingFile == null || receivingFile.desiredName == null) {
      _logger.warning('Unexpected fileId: $fileId');
      return;
    }

    final fileType = receivingFile.file.fileType;
    final filePath = event.path;
    final error = event.error;

    if (error == null) {
      server.ref.notifier(fileTransferProvider).setStatus(sessionId: event.sessionId, fileId: fileId, status: FileStatus.finished);
      server.setState(
        (oldState) => oldState?.copyWith(
          session: oldState.session?.fileFinished(
            fileId: fileId,
            path: filePath,
            savedToGallery: event.savedToGallery,
            errorMessage: null,
          ),
        ),
      );
    } else {
      server.ref.notifier(fileTransferProvider).setStatus(sessionId: event.sessionId, fileId: fileId, status: FileStatus.failed);
      server.setState(
        (oldState) => oldState?.copyWith(
          session: oldState.session?.fileFinished(
            fileId: fileId,
            path: null,
            savedToGallery: false,
            errorMessage: error,
          ),
        ),
      );
    }

    server.ref
        .notifier(fileTransferProvider)
        .setProgress(
          sessionId: receiveState.sessionId,
          fileId: fileId,
          progress: 1,
        );

    final session = server.getStateOrNull()?.session;
    if (session == null) {
      return;
    }

    _updateForegroundServiceProgress(session);

    final statuses = server.ref.read(fileTransferProvider).getStatuses(session.sessionId);
    if (allowedStates.contains(session.status) && statuses.isFinishedOrError) {
      // The transfer is over, the process no longer needs to be kept alive for it.
      TransferNotification.stop(session.sessionId);

      final hasError = statuses.any((status) => status == FileStatus.failed);
      server.setState(
        (oldState) => oldState?.copyWith(
          session: oldState.session!.copyWith(
            status: hasError ? SessionStatus.finishedWithErrors : SessionStatus.finished,
            endTime: DateTime.now().millisecondsSinceEpoch,
          ),
        ),
      );

      // Recorded even when it failed: a receive that lost files has to be
      // visible in the Transfers tab, not vanish because nothing arrived.
      await _recordHistory(server.getState().session!, failed: hasError);

      final settings = server.ref.read(settingsProvider);
      // Only auto-close fully successful sessions: a failed file may still be
      // retried by the sender (e.g. after a checksum mismatch), which requires
      // the session to stay open.
      bool quickSave = settings.quickSave && !hasError && server.getState().session?.message == null;
      final quickSaveFromFavorites = settings.quickSaveFromFavorites && !hasError && server.getState().session?.message == null;
      if (quickSaveFromFavorites) {
        final bool isFavorite = server.ref.read(favoritesProvider).any((e) => e.fingerprint == session.sender.fingerprint);
        if (isFavorite) {
          quickSave = true;
        }
      }
      if (quickSave) {
        // close the session **after** the response has been sent
        Future.delayed(Duration.zero, () {
          closeSession();
          _logger.info('Closing session');

          // Stay where the user is: the completion arrives without a page change.
          // open the dialog to open file instantly
          if (filePath != null && filePath.isNotEmpty) {
            // ignore: discarded_futures
            OpenFileDialog.open(
              Routerino.context, // ignore: use_build_context_synchronously
              filePath: filePath,
              fileType: fileType,
              openGallery: event.savedToGallery,
            );
          }
        });
      }
      _logger.info('Received all files.');
    }
  }

  /// An upload session ended on the Rust server.
  void onSessionEnd(HttpServerSessionEndEvent event) {
    final receiveSession = server.getStateOrNull()?.session;
    if (receiveSession == null || receiveSession.sessionId != event.sessionId) {
      return;
    }

    switch (event.reason) {
      case SessionEndReasonV2.finished:
        // The transfer itself was already finalized when the last file
        // finished; the checksum summary is only known now, so attach it to
        // the still displayed session.
        if (event.checksumVerified > 0) {
          server.setState(
            (oldState) => oldState?.copyWith(
              session: oldState.session?.copyWith(
                checksumVerified: event.checksumVerified,
                checksumUnchecked: event.checksumUnchecked,
              ),
            ),
          );
        }
        break;
      case SessionEndReasonV2.cancelled:
        _cancelBySender();
    }
  }

  /// Records the finished session as one history entry, so the transfer tab can
  /// list it as a single row.
  ///
  /// A failed session is recorded too, with the files the receiver accepted:
  /// without it a transfer that lost files leaves no trace behind.
  Future<void> _recordHistory(ReceiveSessionState session, {required bool failed}) async {
    if (!server.ref.read(settingsProvider).saveToHistory) {
      return;
    }
    final files = buildHistoryFiles(session.files.values, failed: failed);
    if (files.isEmpty) {
      return;
    }

    // A receive has no request-level error: the reason a file failed is the
    // only one there is, and the first one is reported with its file name.
    final errorMessage = failed
        ? transferFailureReason(
            files: session.files.values.map((file) => (file.file.fileName, file.errorMessage)),
          )
        : null;

    await server.ref
        .redux(transferHistoryProvider)
        .dispatchAsync(
          AddTransferHistorySessionAction(
            TransferHistorySession(
              id: session.sessionId,
              peerAlias: session.senderAlias,
              direction: TransferHistoryDirection.receive,
              timestamp: DateTime.fromMillisecondsSinceEpoch(session.startTime ?? DateTime.now().millisecondsSinceEpoch, isUtc: true),
              files: files,
              failed: failed,
              errorMessage: errorMessage,
            ),
          ),
        );
  }

  /// The sender aborted the request while the user was still deciding.
  void onPrepareUploadAborted(HttpServerPrepareUploadAbortedEvent event) {
    final receiveSession = server.getStateOrNull()?.session;
    if (receiveSession == null || receiveSession.sessionId != event.sessionId || receiveSession.status != SessionStatus.waiting) {
      return;
    }

    _cancelBySender();
  }

  /// A remote device cancels a transfer this application is currently
  /// *sending* to it.
  void onCancelReceived(HttpServerCancelReceivedEvent event) {
    final sendSessions = server.ref.read(sendProvider);
    final selectedSession = sendSessions.values.firstWhereOrNull((s) => s.remoteSessionId == event.sessionId);
    if (selectedSession == null) {
      return;
    }

    if (selectedSession.target.ip != event.ip) {
      return;
    }

    if (selectedSession.status != SessionStatus.sending) {
      return;
    }

    server.ref
        .notifier(sendProvider)
        .cancelSessionByReceiver(
          selectedSession.sessionId,
        );
  }

  /// Another application instance requested the running application to show itself.
  /// The show token has already been checked by the Rust server.
  void onShow(HttpServerShowEvent event) {
    if (!checkPlatformIsDesktop()) {
      return;
    }

    // ignore: discarded_futures
    showFromTray().catchError((e) {
      // don't wait for it
      _logger.severe('Failed to show from tray', e);
    });

    final args = event.args;
    if (args.isEmpty) {
      return;
    }

    // ignore: unawaited_futures, discarded_futures
    server.ref.redux(selectedSendingFilesProvider).dispatchAsyncTakeResult(LoadSelectionFromArgsAction(args)).then((filesAdded) {
      if (filesAdded) {
        server.ref.redux(homePageControllerProvider).dispatch(ChangeTabAction(HomeTab.nearby));
      }
    });
  }

  /// Accepts the file request with the given [fileNameMap] (file id -> desired file name).
  Future<void> acceptFileRequest(Map<String, String> fileNameMap) async {
    final session = server.getStateOrNull()?.session;
    if (session == null || session.status != SessionStatus.waiting) {
      return;
    }
    // The request is answered, so the notification (if any) has done its job.
    RequestNotification.cancel();

    if (fileNameMap.isEmpty) {
      // nothing selected, the Rust server responds with 204 and creates no session
      // This usually happens for message transfers
      server.ref.redux(parentIsolateProvider).dispatch(IsolateHttpServerPrepareUploadDecisionAction(config: _buildReceiveConfig(session, {})));
      closeSession();
      return;
    }

    server.setState(
      (oldState) {
        final receiveState = oldState!.session!;
        return oldState.copyWith(
          session: receiveState.copyWith(
            status: SessionStatus.sending,
            files: Map.fromEntries(
              receiveState.files.values.map((entry) {
                final desiredName = fileNameMap[entry.file.id];
                return MapEntry(
                  entry.file.id,
                  ReceivingFile(
                    file: entry.file,
                    token: null,
                    desiredName: desiredName,
                    path: null,
                    savedToGallery: false,
                    errorMessage: null,
                  ),
                );
              }),
            ),
          ),
        );
      },
    );

    server.ref
        .notifier(fileTransferProvider)
        .setStatuses(
          sessionId: session.sessionId,
          statuses: {
            for (final file in session.files.values) file.file.id: fileNameMap.containsKey(file.file.id) ? FileStatus.queue : FileStatus.skipped,
          },
        );

    // The storage permission only exists below Android 13 (scoped storage): newer versions
    // auto-deny the request, but the round trip through the system permission activity
    // still blocks the UI noticeably.
    final androidSdkInt = server.ref.read(deviceInfoProvider).androidSdkInt;
    if (checkPlatform([TargetPlatform.android]) && androidSdkInt != null && androidSdkInt < 33) {
      try {
        final result = await Permission.storage.request();
        _logger.info('storage permission: $result');
      } catch (e) {
        _logger.warning('Could not request storage permission', e);
      }
    }

    // Keep the process alive for the whole transfer. Started here because:
    // - the app is still in the foreground, and Android 12+ rejects starting a foreground service
    //   from the background,
    // - the service may ask for the notification permission, which Android cancels when it overlaps
    //   with the storage permission requests above.
    TransferNotification.start(sessionId: session.sessionId, receiving: true);

    // From here on, the server isolate receives all accepted files on its own
    // and reports back via upload progress/result events.
    final updatedSession = server.getStateOrNull()?.session;
    if (updatedSession == null) {
      return;
    }
    server.ref
        .redux(parentIsolateProvider)
        .dispatch(IsolateHttpServerPrepareUploadDecisionAction(config: _buildReceiveConfig(updatedSession, fileNameMap)));
  }

  HttpServerReceiveConfig _buildReceiveConfig(ReceiveSessionState session, Map<String, String> fileNameMap) {
    return HttpServerReceiveConfig(
      sessionId: session.sessionId,
      fileNameMap: fileNameMap,
      destinationDirectory: session.destinationDirectory,
      cacheDirectory: session.cacheDirectory,
      saveToGallery: session.saveToGallery,
      androidSdkInt: server.ref.read(deviceInfoProvider).androidSdkInt,
    );
  }

  void declineFileRequest() {
    final session = server.getStateOrNull()?.session;
    if (session == null || session.status != SessionStatus.waiting) {
      return;
    }

    server.ref.redux(parentIsolateProvider).dispatch(IsolateHttpServerPrepareUploadDecisionAction(config: null));
    closeSession();
  }

  /// Updates the destination directory for the current session.
  void setSessionDestinationDir(String destinationDirectory) {
    server.setState(
      (oldState) => oldState?.copyWith(
        session: oldState.session?.copyWith(
          destinationDirectory: destinationDirectory.replaceAll('\\', '/'),
        ),
      ),
    );
  }

  /// Updates the "saveToGallery" setting for the current session.
  void setSessionSaveToGallery(bool saveToGallery) {
    server.setState(
      (oldState) => oldState?.copyWith(
        session: oldState.session?.copyWith(
          saveToGallery: saveToGallery,
        ),
      ),
    );
  }

  /// In addition to [closeSession], this method also
  /// - cancels the session on the Rust server so that further uploads fail
  /// - notifies the sender that the session has been canceled
  void cancelSession() async {
    final session = server.getStateOrNull()?.session;
    if (session == null) {
      // the server is not running
      return;
    }

    // fail further uploads
    server.ref.redux(parentIsolateProvider).dispatch(IsolateHttpServerCancelSessionAction(sessionId: session.sessionId));

    // notify sender
    final target = session.sender;
    try {
      server.ref
          .read(httpProvider)
          .pinnedTo(target.fingerprint)
          // ignore: unawaited_futures
          .cancel(
            protocol: target.getProtocolType(),
            ip: target.ip!,
            port: target.port,
            sessionId: session.sessionId,
          );
    } catch (e) {
      _logger.warning('Failed to notify sender', e);
    }

    closeSession();
  }

  /// A remote device cancelled a transfer, either before the user answered or
  /// while it was uploading.
  void _cancelBySender() {
    final receiveSession = server.getStateOrNull()?.session;
    if (receiveSession == null) {
      return;
    }

    TransferNotification.stop(receiveSession.sessionId);

    if (receiveSession.status == SessionStatus.waiting) {
      // Cancelled during accept/decline: pop just in case the user is in
      // [ReceiveOptionsPage]. Nothing shows this session afterwards, so it must
      // be dropped — a session left behind here made the next send open as a
      // receive progress page.
      Routerino.context.popUntilRoot();
      closeSession();
      return;
    }

    server.setState(
      (oldState) => oldState?.copyWith(
        session: oldState.session?.copyWith(
          status: SessionStatus.canceledBySender,
          endTime: DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );
  }

  void closeSession() {
    final sessionId = server.getStateOrNull()?.session?.sessionId;
    if (sessionId == null) {
      return;
    }

    TransferNotification.stop(sessionId);
    // The request notification belongs to the session as well: without a session there is no
    // dialog left to open.
    RequestNotification.cancel();

    server.setState(
      (oldState) => oldState?.copyWith(
        session: null,
      ),
    );
    server.ref.notifier(fileTransferProvider).removeSession(sessionId);
  }
}

/// Maps the files of a finished receive session to their history entries.
///
/// A file saved to the gallery has no path (the OS owns it afterwards), but it
/// is still part of the transfer, so it has to appear in the history. A failed
/// session keeps every file the receiver accepted — the delivered ones alone
/// would hide what the failure was about. In a successful session the failed
/// files have neither a path nor a gallery flag and are left out.
@visibleForTesting
List<TransferHistoryFile> buildHistoryFiles(Iterable<ReceivingFile> files, {bool failed = false}) {
  return [
    for (final file in files)
      if (file.path != null || file.savedToGallery || (failed && file.desiredName != null))
        TransferHistoryFile(
          id: file.file.id,
          fileName: file.desiredName ?? file.file.fileName,
          fileType: file.file.fileType,
          fileSize: file.file.size,
          path: file.path,
          savedToGallery: file.savedToGallery,
          isMessage: false,
          modified: TransferHistoryFile.parseModified(file.file.metadata),
        ),
  ];
}

extension on ReceiveSessionState {
  ReceiveSessionState fileFinished({
    required String fileId,
    required String? path,
    required bool savedToGallery,
    required String? errorMessage,
  }) {
    return copyWith(
      files: {...files}
        ..update(
          fileId,
          (file) => file.copyWith(
            path: path,
            savedToGallery: savedToGallery,
            errorMessage: errorMessage,
          ),
        ),
    );
  }
}
