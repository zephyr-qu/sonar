import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/state/server/receive_session_state.dart';
import 'package:localsend_app/pages/web_share_page.dart';
import 'package:localsend_app/provider/file_transfer_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/native/open_folder.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/native/taskbar_helper.dart';
import 'package:localsend_app/util/notification_strings.dart';
import 'package:localsend_app/widget/dialogs/cancel_session_dialog.dart';
import 'package:localsend_app/widget/dialogs/error_dialog.dart';
import 'package:localsend_app/widget/ls/ls_buttons.dart';
import 'package:localsend_app/widget/ls/ls_card.dart';
import 'package:localsend_app/widget/ls/ls_chip.dart';
import 'package:localsend_app/widget/ls/ls_header.dart';
import 'package:localsend_app/widget/ls/ls_progress_bar.dart';
import 'package:localsend_app/widget/ls/ls_section_label.dart';
import 'package:localsend_app/widget/ls/ls_tile.dart';
import 'package:localsend_isolates/model/dto/file_dto.dart';
import 'package:localsend_isolates/model/file_status.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:localsend_isolates/util/file_size_helper.dart';
import 'package:localsend_isolates/util/file_speed_helper.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/addons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ProgressPage extends StatefulWidget {
  final bool showAppBar;
  final bool closeSessionOnClose;
  final String sessionId;

  const ProgressPage({
    required this.showAppBar,
    required this.closeSessionOnClose,
    required this.sessionId,
  });

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> with Refena {
  int _totalBytes = double.maxFinite.toInt();
  List<FileDto> _files = []; // also contains declined files (files without token)
  Set<String> _selectedFiles = {};

  // If [autoFinish] is enabled, we wait a few seconds before automatically closing the session.
  int _finishCounter = 3;
  Timer? _finishTimer;
  Timer? _wakelockPlusTimer;

  /// On Android the foreground service keeps the process and the connection alive,
  /// so there is no reason to also keep the screen on.
  bool get _useWakelock => checkPlatformIsNot([TargetPlatform.android]);

  @override
  void initState() {
    super.initState();

    // init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_useWakelock) {
        try {
          unawaited(WakelockPlus.enable());
        } catch (_) {}

        // Poll for completion and disable the wakelock once.
        // We must NOT call WakelockPlus.enable() repeatedly here: on Linux (FreeDesktop D-Bus ScreenSaver)
        // each enable() acquires a new inhibit cookie while disable() only releases one, so re-calling
        // enable() every 30s leaks inhibit locks that keep the screen awake indefinitely (issue #3209).
        _wakelockPlusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
          // an empty iterable (session already removed) also counts as finished
          final finished = ref.read(fileTransferProvider).getStatuses(widget.sessionId).isFinishedOrSkipped;
          if (finished) {
            timer.cancel();
            try {
              unawaited(WakelockPlus.disable());
            } catch (_) {}
          }
        });
      }

      if (ref.read(settingsProvider).autoFinish) {
        _finishTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          // an empty iterable (session already removed) also counts as finished
          final finished = ref.read(fileTransferProvider).getStatuses(widget.sessionId).isFinishedOrSkipped;
          if (finished) {
            if (_finishCounter == 1) {
              timer.cancel();
              _exit(closeSession: true);
            } else {
              setState(() {
                _finishCounter--;
              });
            }
          }
        });
      }

      setState(() {
        final receiveSession = ref.read(serverProvider)?.session;
        if (receiveSession != null) {
          _files = receiveSession.files.values.map((f) => f.file).toList();
        } else {
          final sendSession = ref.read(sendProvider)[widget.sessionId];
          if (sendSession != null) {
            _files = sendSession.files.values.map((f) => f.file).toList();
          }
        }

        // We previously used f.token != null here, but this may not work on very fast networks.
        final transferNotifier = ref.read(fileTransferProvider);
        _selectedFiles = _files
            .where((f) => transferNotifier.getStatus(sessionId: widget.sessionId, fileId: f.id) != FileStatus.skipped)
            .map((f) => f.id)
            .toSet();

        _totalBytes = _files.where((f) => _selectedFiles.contains(f.id)).fold(0, (prev, curr) => prev + curr.size);
      });
    });
  }

  void _exit({required bool closeSession}) async {
    final receiveSession = ref.read(serverProvider.select((s) => s?.session));
    final sendSession = ref.read(sendProvider)[widget.sessionId];
    final SessionStatus? status = receiveSession?.status ?? sendSession?.status;
    final keepSession = !closeSession && (status == SessionStatus.sending || status == SessionStatus.finishedWithErrors);
    final result = status == null || keepSession || await _askCancelConfirmation(status);

    if (result && mounted) {
      if (ref.read(serverProvider)?.webUpload == true) {
        context.global.dispatch(NavigateAction.popUntil<WebSharePage>());
      } else {
        context.global.dispatch(NavigateAction.popUntilRoot());
      }
    }
  }

  Future<bool> _askCancelConfirmation(SessionStatus status) async {
    final bool result = switch (status == SessionStatus.sending) {
      true => (await context.pushBottomSheet(() => const CancelSessionDialog())) == true,
      false => true,
    };
    if (result) {
      final receiveSession = ref.read(serverProvider)?.session;
      final sendState = ref.read(sendProvider)[widget.sessionId];

      if (receiveSession != null) {
        if (receiveSession.status == SessionStatus.sending) {
          ref.notifier(serverProvider).cancelSession();
        } else {
          ref.notifier(serverProvider).closeSession();
        }
      } else if (sendState != null) {
        if (sendState.status == SessionStatus.sending) {
          ref.notifier(sendProvider).cancelSession(widget.sessionId);
        } else {
          ref.notifier(sendProvider).closeSession(widget.sessionId);
        }
      }
    }
    return result;
  }

  @override
  void dispose() {
    super.dispose();
    _finishTimer?.cancel();
    _wakelockPlusTimer?.cancel();
    TaskbarHelper.clearProgressBar(); // ignore: discarded_futures
    if (_useWakelock) {
      try {
        WakelockPlus.disable(); // ignore: discarded_futures
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final transferNotifier = ref.read(fileTransferProvider);

    // No select: comparing the selected session runs the dart_mappable deep equality
    // over the whole files map on every state change.
    final receiveSession = ref.watch(serverProvider)?.session;
    final sendSession = ref.watch(sendProvider)[widget.sessionId];

    final SessionState? commonSessionState = receiveSession ?? sendSession;

    if (commonSessionState == null) {
      // The session no longer exists, e.g. a multi-send session that finished successfully
      // in background gets removed while this page is still open.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (ref.read(serverProvider)?.webUpload == true) {
          context.global.dispatch(NavigateAction.popUntil<WebSharePage>());
        } else {
          context.global.dispatch(NavigateAction.popUntilRoot());
        }
      });
      return Scaffold(
        body: Container(),
      );
    }

    final status = commonSessionState.status;
    final isSending = status == SessionStatus.sending;

    final title = receiveSession != null ? t.progressPage.titleReceiving : t.progressPage.titleSending;
    final startTime = commonSessionState.startTime;
    final endTime = commonSessionState.endTime;
    final alias = receiveSession?.senderAlias ?? sendSession?.target.alias ?? '';
    final device = receiveSession?.sender ?? sendSession?.target;
    final totalSize = _files.fold<int>(0, (sum, file) => sum + file.size);

    final String deviceTitle;
    if (isSending) {
      deviceTitle = receiveSession != null ? t.transferTab.receiving(device: alias) : t.transferTab.sending(device: alias);
    } else {
      deviceTitle = receiveSession != null ? t.transferTab.receivedFrom(device: alias) : t.transferTab.sentTo(device: alias);
    }

    final meta = [
      t.transferTab.items(n: _files.length),
      totalSize.asReadableFileSize,
    ].join(' · ');

    // Only the receiving side can report verification: the protocol has no ack
    // telling the sender whether the receiver checked the checksums.
    final Widget? checksumChip = switch (receiveSession) {
      final session? when session.hasChecksumReport =>
        session.checksumUnchecked == 0
            ? LsChip.text(t.transferTab.verified, accent: true, icon: LucideIcons.shield)
            : LsChip.text(
                t.transferTab.verifiedCount(
                  verified: session.checksumVerified,
                  total: session.checksumVerified + session.checksumUnchecked,
                ),
                accent: true,
                icon: LucideIcons.shield,
              ),
      _ => null,
    };

    final Widget? statusChip = switch (status) {
      SessionStatus.finished => checksumChip,
      SessionStatus.finishedWithErrors => LsChip.text(t.general.error),
      SessionStatus.canceledBySender || SessionStatus.canceledByReceiver => LsChip.text(t.general.cancel),
      _ => null,
    };

    final doneLabel = _finishTimer != null ? '${t.general.done} ($_finishCounter)' : t.general.done;
    final canOpenFolder = receiveSession != null && checkPlatformWithFileSystem();

    final fileRows = <Widget>[];
    for (var i = 0; i < _files.length; i++) {
      final file = _files[i];
      final fileName = receiveSession?.files[file.id]?.desiredName ?? file.fileName;
      final savedToGallery = receiveSession?.files[file.id]?.savedToGallery ?? false;

      final String? errorMessage;
      if (receiveSession != null) {
        errorMessage = receiveSession.files[file.id]!.errorMessage;
      } else if (sendSession != null) {
        errorMessage = sendSession.files[file.id]!.errorMessage;
      } else {
        errorMessage = null;
      }

      // Only this row rebuilds when the state of this file changes, not the whole page.
      fileRows.add(
        ValueListenableBuilder<FileTransfer>(
          valueListenable: transferNotifier.fileListenable(sessionId: widget.sessionId, fileId: file.id),
          builder: (context, transfer, _) {
            final fileStatus = transfer.status;
            final statusLabel = savedToGallery ? t.progressPage.savedToGallery : fileStatus.label;

            final Widget? trailing;
            if (sendSession != null && fileStatus == FileStatus.failed) {
              trailing = LsIconButton(
                icon: LucideIcons.refreshCw,
                tooltip: t.general.restart,
                onPressed: () => ref
                    .notifier(sendProvider)
                    .sendFile(
                      sessionId: widget.sessionId,
                      file: sendSession.files[file.id]!,
                      isRetry: true,
                    ),
              );
            } else if (errorMessage != null) {
              trailing = LsIconButton(
                icon: LucideIcons.info,
                tooltip: t.general.error,
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => ErrorDialog(error: errorMessage!),
                ),
              );
            } else {
              trailing = null;
            }

            return LsFileRow(
              kind: _kindOfFile(file),
              name: fileName,
              meta: [
                file.size.asReadableFileSize,
                if (fileStatus != FileStatus.sending) statusLabel,
              ].join(' · '),
              progress: switch (fileStatus) {
                FileStatus.sending => transfer.progress.clamp(0.0, 1.0),
                FileStatus.finished => 1.0,
                _ => null,
              },
              showDivider: i != _files.length - 1,
              trailing: trailing,
            );
          },
        ),
      );
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Already popped.
          // Because the user cannot pop this page, we can safely assume that all sessions are closed if they should be.
          return;
        }
        _exit(closeSession: widget.closeSessionOnClose);
      },
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              LsSubHeader(
                title: title,
                subtitle: canOpenFolder
                    ? InkWell(
                        onTap: () => openFolder(folderPath: receiveSession.destinationDirectory),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.folder, size: 11, color: colors.muted),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  receiveSession.destinationDirectory,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tokens.monoSm,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : null,
                onBack: () => _exit(closeSession: widget.closeSessionOnClose),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    _ProgressScope(
                      notifier: transferNotifier,
                      sessionId: widget.sessionId,
                      files: _files,
                      totalBytes: _totalBytes,
                      startTime: startTime,
                      endTime: endTime,
                      status: status,
                      isSending: isSending,
                      builder: (context, snapshot) => LsCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: colors.bg3, borderRadius: BorderRadius.circular(10)),
                                  child: Icon(device?.deviceType.icon ?? LucideIcons.monitor, size: 18, color: colors.fg),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        deviceTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: tokens.bodyStrong,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          meta,
                                          if (isSending && snapshot.speedInBytes != null)
                                            t.transferTab.speed(speed: snapshot.speedInBytes!.asReadableFileSize),
                                        ].join(' · '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: tokens.mono,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (statusChip != null)
                                  statusChip
                                else if (isSending && snapshot.remainingTime != null)
                                  Text(
                                    t.transferTab.remaining(time: snapshot.remainingTime!),
                                    style: tokens.mono,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LsProgressBar(value: snapshot.progress),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${(snapshot.progress * 100).round()}%', style: tokens.monoSm),
                                Text(
                                  '${snapshot.currentBytes.asReadableFileSize} / ${_totalBytes == double.maxFinite.toInt() ? '-' : _totalBytes.asReadableFileSize}',
                                  style: tokens.monoSm,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (sendSession?.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: SelectableText(
                          sendSession!.errorMessage!,
                          style: tokens.bodySm.copyWith(color: colors.danger),
                        ),
                      ),
                    if (fileRows.isNotEmpty) ...[
                      LsSectionLabel(label: t.general.files, count: '${_files.length}'),
                      LsCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        child: Column(children: fileRows),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  color: colors.bg,
                  border: Border(
                    top: BorderSide(color: colors.line, width: tokens.hairlineOf(context)),
                  ),
                ),
                child: Row(
                  children: [
                    if (isSending)
                      Expanded(
                        child: LsButton(
                          label: t.transferTab.cancel,
                          icon: LucideIcons.x,
                          variant: LsButtonVariant.ghost,
                          expand: true,
                          onPressed: () => _exit(closeSession: true),
                        ),
                      )
                    else ...[
                      if (canOpenFolder) ...[
                        Expanded(
                          child: LsButton(
                            label: t.transferTab.openFolder,
                            icon: LucideIcons.folder,
                            variant: LsButtonVariant.ghost,
                            expand: true,
                            onPressed: () => openFolder(folderPath: receiveSession.destinationDirectory),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: LsButton(
                          label: doneLabel,
                          icon: LucideIcons.check,
                          expand: true,
                          onPressed: () => _exit(closeSession: true),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on FileStatus {
  String get label {
    switch (this) {
      case FileStatus.queue:
        return t.general.queue;
      case FileStatus.skipped:
        return t.general.skipped;
      case FileStatus.sending:
        return ''; // progress bar will be showed here
      case FileStatus.failed:
        return t.general.error;
      case FileStatus.finished:
        return t.general.done;
    }
  }
}

String _kindOfFile(FileDto file) {
  final name = file.fileName;
  final dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) {
    return 'FILE';
  }
  final kind = name.substring(dot + 1).toUpperCase();
  return kind.length > 4 ? kind.substring(0, 4) : kind;
}

/// The summary card of the progress page: progress bar, percentage, speed and remaining time.
///
/// Progress events arrive up to 50 times per second per file, so this widget subscribes to
/// [FileTransferNotifier.sessionTick] itself and rebuilds only its own small subtree.
/// The taskbar is updated from that listener as well, instead of from [build].
class _ProgressScope extends StatefulWidget {
  final FileTransferNotifier notifier;
  final String sessionId;
  final List<FileDto> files;
  final int totalBytes;
  final int? startTime;
  final int? endTime;
  final SessionStatus status;
  final bool isSending;
  final Widget Function(BuildContext context, _ProgressSnapshot snapshot) builder;

  const _ProgressScope({
    required this.notifier,
    required this.sessionId,
    required this.files,
    required this.totalBytes,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.isSending,
    required this.builder,
  });

  @override
  State<_ProgressScope> createState() => _ProgressScopeState();
}

class _ProgressScopeState extends State<_ProgressScope> {
  late ValueListenable<int> _tick;
  late _ProgressSnapshot _snapshot;
  String? _remainingTime;
  int _lastRemainingTimeUpdate = 0; // millis since epoch
  int _lastTaskbarUpdate = 0;

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _snapshot);
  }

  @override
  void initState() {
    super.initState();
    _snapshot = _compute(forceRemainingTime: true);
    _tick = widget.notifier.sessionTick(widget.sessionId);
    _tick.addListener(_onTick);
    if (widget.isSending) {
      _updateTaskbarProgress();
    } else {
      TaskbarHelper.visualizeStatus(widget.status); // ignore: discarded_futures
    }
  }

  @override
  void didUpdateWidget(covariant _ProgressScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      _tick.removeListener(_onTick);
      _tick = widget.notifier.sessionTick(widget.sessionId);
      _tick.addListener(_onTick);
    }
    if (oldWidget.status != widget.status && !widget.isSending) {
      _lastTaskbarUpdate = 0;
      TaskbarHelper.visualizeStatus(widget.status); // ignore: discarded_futures
    }
    _snapshot = _compute();
  }

  @override
  void dispose() {
    _tick.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (!mounted) {
      return;
    }
    setState(() => _snapshot = _compute());
    if (widget.isSending) {
      _updateTaskbarProgress();
    }
  }

  /// Updates the taskbar, but at most every 200ms: it is a platform channel call.
  void _updateTaskbarProgress() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTaskbarUpdate < 200) {
      return;
    }
    _lastTaskbarUpdate = now;
    TaskbarHelper.setProgressBar(_snapshot.currentBytes, widget.totalBytes); // ignore: discarded_futures
  }

  _ProgressSnapshot _compute({bool forceRemainingTime = false}) {
    final currentBytes = widget.files.fold<int>(
      0,
      (prev, curr) => prev + (widget.notifier.getProgress(sessionId: widget.sessionId, fileId: curr.id) * curr.size).round(),
    );
    final progress = widget.totalBytes <= 0 ? 0.0 : (currentBytes / widget.totalBytes).clamp(0.0, 1.0);

    int? speedInBytes;
    if (widget.startTime != null && currentBytes >= 500 * 1024) {
      speedInBytes = getFileSpeed(start: widget.startTime!, end: widget.endTime ?? DateTime.now().millisecondsSinceEpoch, bytes: currentBytes);

      // The remaining time is only refreshed once per second, otherwise it flickers.
      final now = DateTime.now().millisecondsSinceEpoch;
      if (forceRemainingTime || now - _lastRemainingTimeUpdate >= 1000) {
        _remainingTime = getRemainingTime(
          bytesPerSeconds: speedInBytes,
          remainingBytes: widget.totalBytes - currentBytes,
          strings: notificationStrings,
        );
        _lastRemainingTimeUpdate = now;
      }
    }

    return _ProgressSnapshot(
      currentBytes: currentBytes,
      progress: progress,
      speedInBytes: speedInBytes,
      remainingTime: _remainingTime,
    );
  }
}

class _ProgressSnapshot {
  final int currentBytes;
  final double progress;
  final int? speedInBytes;
  final String? remainingTime;

  const _ProgressSnapshot({
    required this.currentBytes,
    required this.progress,
    required this.speedInBytes,
    required this.remainingTime,
  });
}
