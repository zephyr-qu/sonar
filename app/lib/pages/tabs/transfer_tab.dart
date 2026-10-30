import 'dart:io';

import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/model/persistence/receive_history_entry.dart';
import 'package:localsend_app/model/persistence/send_history_entry.dart';
import 'package:localsend_app/model/state/send/send_session_state.dart';
import 'package:localsend_app/model/state/server/receive_session_state.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/receive_page.dart';
import 'package:localsend_app/pages/settings_page.dart';
import 'package:localsend_app/pages/tabs/nearby_tab_vm.dart';
import 'package:localsend_app/provider/file_transfer_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/receive_history_provider.dart';
import 'package:localsend_app/provider/send_history_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/file_type_ext.dart';
import 'package:localsend_app/util/native/open_file.dart';
import 'package:localsend_app/util/native/open_folder.dart';
import 'package:localsend_app/util/notification_strings.dart';
import 'package:localsend_app/util/system_date_time_formatter.dart';
import 'package:localsend_app/widget/desktop_scaffold.dart';
import 'package:localsend_app/widget/dialogs/file_info_dialog.dart';
import 'package:localsend_app/widget/dialogs/history_clear_dialog.dart';
import 'package:localsend_app/widget/dialogs/quick_save_notice.dart';
import 'package:localsend_app/widget/ls/ls_buttons.dart';
import 'package:localsend_app/widget/ls/ls_card.dart';
import 'package:localsend_app/widget/ls/ls_chip.dart';
import 'package:localsend_app/widget/ls/ls_header.dart';
import 'package:localsend_app/widget/ls/ls_hover.dart';
import 'package:localsend_app/widget/ls/ls_progress_bar.dart';
import 'package:localsend_app/widget/ls/ls_section_label.dart';
import 'package:localsend_app/widget/ls/ls_switch.dart';
import 'package:localsend_app/widget/ls/ls_tile.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/dto/file_dto.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:localsend_isolates/util/file_size_helper.dart';
import 'package:localsend_isolates/util/file_speed_helper.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path/path.dart' as path;
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

/// The "Transfers" tab: active send/receive sessions on top, the history of
/// finished transfers below.
///
/// The history is entirely inline: a row per transfer group expands in place
/// into its files, so there is no separate history page anymore.
class TransferTab extends StatefulWidget {
  /// Whether the desktop shell layout is used (header is then rendered by the shell).
  final bool desktop;

  const TransferTab({this.desktop = false});

  @override
  State<TransferTab> createState() => _TransferTabState();
}

class _TransferTabState extends State<TransferTab> {
  /// Keys of the history groups whose file list is expanded in place.
  final Set<String> _expandedGroups = {};

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final allSends = context.watch(sendProvider).values.toList();
    final sendSessions = allSends.where((session) => _isActive(session.status)).toList();
    final finishedSends = allSends.where(_isDone).toList();
    final receiveSession = context.watch(serverProvider)?.session;
    final activeReceive = receiveSession != null && _isActive(receiveSession.status) ? receiveSession : null;
    final receiveEntries = context.watch(receiveHistoryProvider);
    final sendEntries = context.watch(sendHistoryProvider);
    final groups = _groupHistory(receiveEntries, sendEntries);
    final historyCount = receiveEntries.length + sendEntries.length;
    final activeCount = sendSessions.length + (activeReceive != null ? 1 : 0);

    final subtitle = Text(
      activeCount > 0 ? t.transferTab.inProgress(n: activeCount) : t.transferTab.historyCount(n: historyCount),
      style: tokens.mono,
    );
    final actions = [
      if (historyCount > 0)
        LsIconButton(
          icon: LucideIcons.trash2,
          tooltip: t.receiveHistoryPage.deleteHistory,
          onPressed: () async {
            await _clearHistory();
          },
        ),
      LsIconButton(
        icon: LucideIcons.slidersHorizontal,
        tooltip: t.settingsTab.title,
        onPressed: () async => context.push(() => const SettingsPage()),
      ),
    ];

    return Column(
      children: [
        if (widget.desktop)
          const LsDesktopDeviceHeader()
        else
          LsScreenHeader(mark: const Icon(LucideIcons.history), title: t.transferTab.title, subtitle: subtitle, actions: actions),
        Expanded(
          child: LsDesktopLayout(
            aside: widget.desktop ? _desktopAside(context) : null,
            content: ListView(
              padding: EdgeInsets.fromLTRB(tokens.pad, 0, tokens.pad, 18),
              children: [
                if (widget.desktop) ...[
                  Row(
                    children: [
                      Expanded(child: Text(t.transferTab.title, style: tokens.pageTitle)),
                      if (historyCount > 0)
                        LsIconButton(
                          icon: LucideIcons.trash2,
                          tooltip: t.receiveHistoryPage.deleteHistory,
                          onPressed: () async {
                            await _clearHistory();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (activeCount == 0)
                  LsCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
                    child: Column(
                      children: [
                        Text(
                          t.transferTab.noActive,
                          textAlign: TextAlign.center,
                          style: tokens.eyebrow.copyWith(color: tokens.colors.muted),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.transferTab.noActiveHint,
                          textAlign: TextAlign.center,
                          style: tokens.bodySm,
                        ),
                      ],
                    ),
                  ),
                for (final session in sendSessions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SendSessionCard(session: session),
                  ),
                if (activeReceive != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReceiveSessionCard(session: activeReceive),
                  ),
                for (final session in finishedSends)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SendSessionCard(session: session, done: true),
                  ),
                LsSectionLabel(label: t.transferTab.recent, count: groups.isEmpty ? null : '${groups.length}'),
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(t.transferTab.noHistory, style: tokens.bodySm),
                  )
                else
                  for (final group in groups)
                    _HistoryRow(
                      group: group,
                      expanded: _expandedGroups.contains(group.key),
                      onToggle: () => _toggleGroup(group.key),
                      onOpenEntry: _openReceiveEntry,
                      onEntryAction: _onReceiveEntryAction,
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _desktopAside(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final settings = context.watch(settingsProvider);
    final nearbyVm = context.watch(nearbyTabVmProvider);
    final trayFiles = nearbyVm.selectedFiles;
    final traySize = trayFiles.fold<int>(0, (sum, file) => sum + file.size);
    final sendSessions = context.watch(sendProvider).values.where((session) => _isActive(session.status)).toList();
    final receiveSession = context.watch(serverProvider)?.session;
    final activeReceive = receiveSession != null && _isActive(receiveSession.status) ? receiveSession : null;
    final activeCount = sendSessions.length + (activeReceive != null ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LsSectionLabel(
          label: t.nearbyTab.tray,
          count: traySize.asReadableFileSize,
          padding: const EdgeInsets.only(bottom: 8),
        ),
        if (trayFiles.isEmpty) ...[
          LsLinkRow(
            label: t.nearbyTab.dropHere,
            leading: const Icon(LucideIcons.plus),
            showTopBorder: false,
            onTap: () async => nearbyVm.onAddFiles(context),
          ),
          Text(t.nearbyTab.dropHint, style: tokens.bodySm),
        ] else ...[
          for (final file in trayFiles.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      file.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.bodySm.copyWith(color: colors.fg),
                    ),
                  ),
                  Text(file.size.asReadableFileSize, style: tokens.monoSm),
                ],
              ),
            ),
          LsLinkRow(label: t.nearbyTab.addFile, leading: const Icon(LucideIcons.plus), onTap: () async => nearbyVm.onAddFiles(context)),
        ],
        const SizedBox(height: 10),
        LsSectionLabel(
          label: t.nearbyTab.inProgress,
          padding: const EdgeInsets.only(bottom: 8),
        ),
        if (activeCount == 0)
          Text(t.transferTab.noActive, style: tokens.eyebrow)
        else ...[
          for (final session in sendSessions) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.target.alias,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.bodySm.copyWith(color: colors.fg),
                  ),
                ),
                _SessionProgressBuilder(
                  sessionId: session.sessionId,
                  builder: (context, transfer) => Text('${(_sendProgress(session, transfer) * 100).round()}%', style: tokens.monoSm),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _SessionProgressBuilder(
              sessionId: session.sessionId,
              builder: (context, transfer) => LsProgressBar(value: _sendProgress(session, transfer)),
            ),
            const SizedBox(height: 8),
            LsButton(
              label: t.transferTab.cancel,
              variant: LsButtonVariant.ghost,
              onPressed: () => context.notifier(sendProvider).cancelSession(session.sessionId),
            ),
            const SizedBox(height: 12),
          ],
          if (activeReceive != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.transferTab.receiving(device: activeReceive.senderAlias),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.bodySm.copyWith(color: colors.fg),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LsButton(
              label: t.transferTab.cancel,
              variant: LsButtonVariant.ghost,
              onPressed: () => context.notifier(serverProvider).cancelSession(),
            ),
            const SizedBox(height: 12),
          ],
        ],
        LsSectionLabel(label: t.nearbyTab.receivePolicy),
        Row(
          children: [
            Expanded(
              child: Text(
                [
                  '${t.general.quickSave}: ${settings.quickSave ? t.general.on : t.general.off}',
                  settings.destination ?? t.settingsTab.receive.downloads,
                ].join(' · '),
                style: tokens.bodySm,
              ),
            ),
            LsSwitch(
              value: settings.quickSave,
              label: t.general.quickSave,
              onChanged: (value) async {
                final wasQuickSave = settings.quickSave;
                final settingsNotifier = context.notifier(settingsProvider);
                await settingsNotifier.setQuickSave(value);
                await settingsNotifier.setQuickSaveFromFavorites(false);
                if (value && !wasQuickSave && context.mounted) {
                  await QuickSaveNotice.open(context);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        LsLinkRow(
          label: t.nearbyTab.securitySettings,
          leading: const Icon(LucideIcons.shield),
          showTopBorder: false,
          onTap: () => context.redux(homePageControllerProvider).dispatch(ChangeTabAction(HomeTab.settings)),
        ),
      ],
    );
  }

  double _sendProgress(SendSessionState session, FileTransferNotifier transfer) {
    final accepted = session.files.values.where((file) => file.token != null);
    final total = accepted.fold<int>(0, (sum, file) => sum + file.file.size);
    if (total == 0) {
      return 0;
    }
    final transferred = accepted.fold<int>(
      0,
      (sum, file) => sum + (transfer.getProgress(sessionId: session.sessionId, fileId: file.file.id) * file.file.size).round(),
    );
    return (transferred / total).clamp(0.0, 1.0);
  }

  void _toggleGroup(String key) {
    setState(() {
      if (!_expandedGroups.remove(key)) {
        _expandedGroups.add(key);
      }
    });
  }

  /// Opens one history entry in place: received messages show the message page,
  /// received files are opened with the system handler.
  Future<void> _openReceiveEntry(ReceiveHistoryEntry entry) async {
    if (entry.isMessage) {
      await _showMessage(entry);
      return;
    }
    final filePath = entry.path;
    if (filePath == null) {
      return;
    }
    await openFile(
      context,
      entry.fileType,
      filePath,
      onDeleteTap: () => context.redux(receiveHistoryProvider).dispatchAsync(RemoveHistoryEntryAction(entry.id)),
    );
  }

  Future<void> _onReceiveEntryAction(ReceiveHistoryEntry entry, _HistoryEntryOption option) {
    return switch (option) {
      _HistoryEntryOption.open => _openReceiveEntry(entry),
      _HistoryEntryOption.showInFolder => _showInFolder(entry),
      _HistoryEntryOption.info => _showInfo(entry),
      _HistoryEntryOption.delete => _deleteEntry(entry),
    };
  }

  /// Shows a received text message in the (read-only) receive page, like the
  /// removed history page did.
  Future<void> _showMessage(ReceiveHistoryEntry entry) async {
    final vm = ViewProvider((ref) {
      return ReceivePageVm(
        status: SessionStatus.waiting,
        sender: Device(
          signalingId: null,
          ip: '0.0.0.0',
          version: '1.0.0',
          port: 8080,
          https: false,
          fingerprint: 'fingerprint',
          alias: entry.senderAlias,
          deviceModel: 'deviceModel',
          deviceType: DeviceType.web,
          download: true,
          channels: const [],
        ),
        showSenderInfo: false,
        files: [],
        message: entry.fileName,
        onAccept: () {},
        onDecline: () {},
        onClose: () {},
      );
    });
    await context.push(() => ReceivePage(vm));
  }

  Future<void> _showInFolder(ReceiveHistoryEntry entry) async {
    final filePath = entry.path;
    if (filePath == null) {
      return;
    }
    await openFolder(folderPath: File(filePath).parent.path, fileName: path.basename(filePath));
  }

  Future<void> _showInfo(ReceiveHistoryEntry entry) async {
    await showDialog(
      context: context,
      builder: (_) => FileInfoDialog(entry: entry),
    );
  }

  Future<void> _deleteEntry(ReceiveHistoryEntry entry) async {
    await context.redux(receiveHistoryProvider).dispatchAsync(RemoveHistoryEntryAction(entry.id));
  }

  /// Clears received and sent history at once, as the history page used to do.
  Future<void> _clearHistory() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const HistoryClearDialog(),
    );
    if (result != true || !mounted) {
      return;
    }
    await context.redux(receiveHistoryProvider).dispatchAsync(RemoveAllHistoryEntriesAction());
    if (!mounted) {
      return;
    }
    await context.redux(sendHistoryProvider).dispatchAsync(RemoveAllSendHistoryEntriesAction());
    if (!mounted) {
      return;
    }
    setState(_expandedGroups.clear);
  }
}

bool _isActive(SessionStatus status) => status == SessionStatus.waiting || status == SessionStatus.sending;

/// Terminal states that keep their session around as a completion card.
bool _isDone(SendSessionState session) => session.status == SessionStatus.finished || session.status == SessionStatus.finishedWithErrors;

String? _statusText(SessionStatus status) {
  return switch (status) {
    SessionStatus.waiting => t.sendPage.waiting,
    SessionStatus.recipientBusy => t.sendPage.busy,
    SessionStatus.declined => t.sendPage.rejected,
    SessionStatus.tooManyAttempts => t.sendPage.tooManyAttempts,
    SessionStatus.sending => null,
    SessionStatus.finished => t.general.finished,
    SessionStatus.finishedWithErrors => t.progressPage.total.title.finishedError,
    SessionStatus.canceledBySender => t.progressPage.total.title.canceledSender,
    SessionStatus.canceledByReceiver => t.progressPage.total.title.canceledReceiver,
  };
}

class _SendSessionCard extends StatelessWidget {
  final SendSessionState session;

  /// A finished session stays in the tab as a completion card until dismissed.
  final bool done;

  const _SendSessionCard({required this.session, this.done = false});

  @override
  @override
  Widget build(BuildContext context) {
    // Only this card follows the progress of its own session.
    return _SessionProgressBuilder(
      sessionId: session.sessionId,
      builder: (context, transfer) => _buildCard(context, transfer),
    );
  }

  Widget _buildCard(BuildContext context, FileTransferNotifier transfer) {
    final tokens = context.ls;
    final files = session.files.values.toList();
    final accepted = files.where((file) => file.token != null).toList();
    final total = files.fold<int>(0, (sum, file) => sum + file.file.size);
    final transferred = accepted.fold<int>(
      0,
      (sum, file) => sum + (transfer.getProgress(sessionId: session.sessionId, fileId: file.file.id) * file.file.size).round(),
    );
    final progress = total == 0 ? 0.0 : (transferred / total).clamp(0.0, 1.0);

    final int speedInBytes;
    if (session.startTime != null && transferred > 0 && session.status == SessionStatus.sending) {
      speedInBytes = getFileSpeed(start: session.startTime!, end: DateTime.now().millisecondsSinceEpoch, bytes: transferred);
    } else {
      speedInBytes = 0;
    }

    return LsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _glyph(context, device: session.target),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      done ? t.transferTab.sentTo(device: session.target.alias) : t.transferTab.sending(device: session.target.alias),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.subtitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        t.transferTab.items(n: files.length),
                        total.asReadableFileSize,
                        if (done) t.transferTab.done else if (speedInBytes > 0) t.transferTab.speed(speed: speedInBytes.asReadableFileSize),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.mono,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // No checksum chip here: the sender never learns whether the
              // receiver verified the files, the protocol has no such ack.
              if (_statusText(session.status) != null)
                LsChip.text(_statusText(session.status)!)
              else if (speedInBytes > 0)
                Text(
                  t.transferTab.remaining(
                    time: getRemainingTime(
                      bytesPerSeconds: speedInBytes,
                      remainingBytes: (total - transferred).clamp(0, total),
                      strings: notificationStrings,
                    ),
                  ),
                  style: tokens.mono,
                ),
            ],
          ),
          const SizedBox(height: 12),
          LsProgressBar(value: progress),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(progress * 100).round()}%', style: tokens.monoSm),
              Text(
                '${transferred.asReadableFileSize} / ${total.asReadableFileSize}',
                style: tokens.monoSm,
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final file in files)
            LsFileRow(
              kind: _kindOfFile(file.file),
              name: file.file.fileName,
              meta: file.file.size.asReadableFileSize,
              progress: file.token == null ? null : transfer.getProgress(sessionId: session.sessionId, fileId: file.file.id).clamp(0.0, 1.0),
            ),
          const SizedBox(height: 10),
          LsButton(
            label: done ? t.transferTab.done : t.transferTab.cancel,
            variant: done ? LsButtonVariant.plain : LsButtonVariant.ghost,
            expand: true,
            onPressed: () => done
                ? context.notifier(sendProvider).closeSession(session.sessionId)
                : context.notifier(sendProvider).cancelSession(session.sessionId),
          ),
        ],
      ),
    );
  }
}

class _ReceiveSessionCard extends StatelessWidget {
  final ReceiveSessionState session;

  const _ReceiveSessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    // Only this card follows the progress of its own session.
    return _SessionProgressBuilder(
      sessionId: session.sessionId,
      builder: (context, transfer) => _buildCard(context, transfer),
    );
  }

  Widget _buildCard(BuildContext context, FileTransferNotifier transfer) {
    final tokens = context.ls;
    final files = session.files.values.toList();
    final total = files.fold<int>(0, (sum, file) => sum + file.file.size);
    final transferred = files.fold<int>(
      0,
      (sum, file) => sum + (transfer.getProgress(sessionId: session.sessionId, fileId: file.file.id) * file.file.size).round(),
    );
    final progress = total == 0 ? 0.0 : (transferred / total).clamp(0.0, 1.0);

    return LsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _glyph(context, device: session.sender),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.transferTab.receiving(device: session.senderAlias),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.subtitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [t.transferTab.items(n: files.length), total.asReadableFileSize].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.mono,
                    ),
                  ],
                ),
              ),
              if (_statusText(session.status) != null) ...[
                const SizedBox(width: 8),
                LsChip.text(_statusText(session.status)!),
              ],
            ],
          ),
          const SizedBox(height: 12),
          LsProgressBar(value: progress),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(progress * 100).round()}%', style: tokens.monoSm),
              Text(
                '${transferred.asReadableFileSize} / ${total.asReadableFileSize}',
                style: tokens.monoSm,
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final file in files.take(4))
            LsFileRow(
              kind: _kindOfFile(file.file),
              name: file.desiredName ?? file.file.fileName,
              meta: file.file.size.asReadableFileSize,
              progress: transfer.getProgress(sessionId: session.sessionId, fileId: file.file.id).clamp(0.0, 1.0),
            ),
          const SizedBox(height: 10),
          LsButton(
            label: t.transferTab.cancel,
            variant: LsButtonVariant.ghost,
            expand: true,
            onPressed: () => context.notifier(serverProvider).cancelSession(),
          ),
        ],
      ),
    );
  }
}

Widget _glyph(BuildContext context, {required Device device}) {
  final tokens = context.ls;
  return Container(
    width: 34,
    height: 34,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: tokens.colors.bg3, borderRadius: BorderRadius.circular(tokens.radiusSm)),
    child: Icon(device.deviceType.icon, size: 18, color: tokens.colors.fg),
  );
}

String _kindOfFile(FileDto file) => _kindOfName(file.fileName);

/// The 3-4 letter kind badge shown when a file has no type icon.
String _kindOfName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) {
    return 'FILE';
  }
  final kind = name.substring(dot + 1).toUpperCase();
  return kind.length > 4 ? kind.substring(0, 4) : kind;
}

enum _Direction { send, receive }

/// The per-file actions of a received history entry.
enum _HistoryEntryOption {
  open,
  showInFolder,
  info,
  delete;

  String get label {
    return switch (this) {
      _HistoryEntryOption.open => t.receiveHistoryPage.entryActions.open,
      _HistoryEntryOption.showInFolder => t.receiveHistoryPage.entryActions.showInFolder,
      _HistoryEntryOption.info => t.receiveHistoryPage.entryActions.info,
      _HistoryEntryOption.delete => t.receiveHistoryPage.entryActions.deleteFromHistory,
    };
  }
}

/// Entries of one transfer (same direction, peer and minute) that the history
/// row shows as a single line and expands into its files.
class _HistoryGroup {
  /// Stable identity of the group, used as the key of the expanded state.
  final String key;

  final _Direction direction;
  final String alias;
  final DateTime time;

  /// Received entries of this group; empty for sent groups.
  final List<ReceiveHistoryEntry> receiveEntries = [];

  /// Sent entries of this group; empty for received groups.
  final List<SendHistoryEntry> sendEntries = [];

  _HistoryGroup({
    required this.key,
    required this.direction,
    required this.alias,
    required this.time,
  });

  int get count => receiveEntries.length + sendEntries.length;

  int get size => receiveEntries.fold<int>(0, (sum, entry) => sum + entry.fileSize) + sendEntries.fold<int>(0, (sum, entry) => sum + entry.fileSize);

  /// Number of entries that were saved to the gallery; the row only notes it
  /// when the whole group went to the gallery.
  int get galleryCount => receiveEntries.where((entry) => entry.savedToGallery).length;
}

/// Groups received and sent entries into one history, one row per transfer.
List<_HistoryGroup> _groupHistory(List<ReceiveHistoryEntry> received, List<SendHistoryEntry> sent) {
  final map = <String, _HistoryGroup>{};

  String keyOf(_Direction direction, String alias, DateTime time) {
    return '${direction.name}|$alias|${time.year}-${time.month}-${time.day}-${time.hour}-${time.minute}';
  }

  for (final entry in received) {
    final time = entry.timestamp.toLocal();
    final key = keyOf(_Direction.receive, entry.senderAlias, time);
    (map[key] ??= _HistoryGroup(key: key, direction: _Direction.receive, alias: entry.senderAlias, time: time)).receiveEntries.add(entry);
  }
  for (final entry in sent) {
    final time = entry.timestamp.toLocal();
    final key = keyOf(_Direction.send, entry.receiverAlias, time);
    (map[key] ??= _HistoryGroup(key: key, direction: _Direction.send, alias: entry.receiverAlias, time: time)).sendEntries.add(entry);
  }

  return map.values.toList()..sort((a, b) => b.time.compareTo(a.time));
}

/// One group of the history: the collapsed row and, when expanded, its files
/// rendered in place.
class _HistoryRow extends StatelessWidget {
  final _HistoryGroup group;
  final bool expanded;
  final VoidCallback onToggle;
  final Future<void> Function(ReceiveHistoryEntry entry) onOpenEntry;
  final Future<void> Function(ReceiveHistoryEntry entry, _HistoryEntryOption option) onEntryAction;

  const _HistoryRow({
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.onOpenEntry,
    required this.onEntryAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final isReceive = group.direction == _Direction.receive;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.line, width: tokens.hairlineOf(context)),
        ),
      ),
      child: Column(
        children: [
          // Only the header row toggles: taps inside the expanded file list must
          // not collapse it again.
          LsHover(
            color: Colors.transparent,
            hoverColor: colors.bg3,
            borderRadius: BorderRadius.zero,
            onTap: onToggle,
            builder: (context, hovered) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: colors.bg3, borderRadius: BorderRadius.circular(tokens.radiusSm)),
                    child: Icon(
                      isReceive ? LucideIcons.arrowDown : LucideIcons.arrowUp,
                      size: 14,
                      color: isReceive ? colors.accent : colors.muted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isReceive ? t.transferTab.receivedFrom(device: group.alias) : t.transferTab.sentTo(device: group.alias),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.bodyStrong,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          [
                            t.transferTab.items(n: group.count),
                            group.size.asReadableFileSize,
                            if (group.galleryCount == group.count) t.progressPage.savedToGallery,
                            SystemDateTimeFormatter.dateTime(context, group.time),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.monoSm,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    child: Icon(LucideIcons.chevronRight, size: 14, color: hovered ? colors.muted : colors.faint),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 6),
              child: LsCard(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Column(
                  children: [
                    for (var index = 0; index < group.receiveEntries.length; index++)
                      _ReceiveEntryRow(
                        entry: group.receiveEntries[index],
                        showDivider: index < group.count - 1,
                        onOpen: onOpenEntry,
                        onAction: onEntryAction,
                      ),
                    for (var index = 0; index < group.sendEntries.length; index++)
                      _SendEntryRow(
                        entry: group.sendEntries[index],
                        showDivider: group.receiveEntries.length + index < group.count - 1,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One received file inside an expanded history row.
///
/// Tapping it opens the file (or shows a received message); the trailing menu
/// offers the per-file actions of the old history page.
class _ReceiveEntryRow extends StatelessWidget {
  final ReceiveHistoryEntry entry;
  final bool showDivider;
  final Future<void> Function(ReceiveHistoryEntry entry) onOpen;
  final Future<void> Function(ReceiveHistoryEntry entry, _HistoryEntryOption option) onAction;

  const _ReceiveEntryRow({
    required this.entry,
    required this.showDivider,
    required this.onOpen,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.ls.colors;
    final canOpen = entry.path != null || entry.isMessage;

    return InkWell(
      onTap: canOpen
          ? () async {
              await onOpen(entry);
            }
          : null,
      child: LsFileRow(
        kind: entry.isMessage ? 'MSG' : _kindOfName(entry.fileName),
        leadingIcon: entry.fileType.icon,
        name: entry.fileName,
        meta: [
          if (!entry.isMessage) entry.fileSize.asReadableFileSize,
          entry.timestampString(context),
          entry.senderAlias,
          if (entry.savedToGallery) t.progressPage.savedToGallery,
        ].join(' · '),
        showDivider: showDivider,
        trailing: PopupMenuButton<_HistoryEntryOption>(
          icon: Icon(LucideIcons.moreHorizontal, size: 16, color: colors.muted),
          onSelected: (option) async {
            await onAction(entry, option);
          },
          itemBuilder: (context) {
            final options = entry.path != null ? _HistoryEntryOption.values : const [_HistoryEntryOption.info, _HistoryEntryOption.delete];
            return [
              for (final option in options)
                PopupMenuItem<_HistoryEntryOption>(
                  value: option,
                  child: Text(option.label, style: context.ls.body),
                ),
            ];
          },
        ),
      ),
    );
  }
}

/// One sent file inside an expanded history row. Sent history has no per-entry
/// actions (the provider can only clear the whole list), so it is read-only.
class _SendEntryRow extends StatelessWidget {
  final SendHistoryEntry entry;
  final bool showDivider;

  const _SendEntryRow({required this.entry, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    return LsFileRow(
      kind: _kindOfName(entry.fileName),
      leadingIcon: entry.fileType.icon,
      name: entry.fileName,
      meta: [
        entry.fileSize.asReadableFileSize,
        SystemDateTimeFormatter.dateTime(context, entry.timestamp.toLocal()),
        entry.receiverAlias,
      ].join(' · '),
      showDivider: showDivider,
    );
  }
}

/// Rebuilds only [builder] when the progress of [sessionId] changes.
///
/// Progress events arrive up to 50 times per second, so watching
/// [fileTransferProvider] would rebuild the whole page (on the transfer tab
/// including a full regrouping of the history) for every single tick.
class _SessionProgressBuilder extends StatelessWidget {
  final String sessionId;
  final Widget Function(BuildContext context, FileTransferNotifier transfer) builder;

  const _SessionProgressBuilder({required this.sessionId, required this.builder});

  @override
  Widget build(BuildContext context) {
    final transfer = context.ref.read(fileTransferProvider);
    return ValueListenableBuilder<int>(
      valueListenable: transfer.sessionTick(sessionId),
      builder: (context, _, _) => builder(context, transfer),
    );
  }
}
