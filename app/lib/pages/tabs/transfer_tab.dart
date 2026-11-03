import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/persistence/transfer_history_session.dart';
import 'package:sonar/model/state/send/send_session_state.dart';
import 'package:sonar/model/state/server/receive_session_state.dart';
import 'package:sonar/pages/settings_page.dart';
import 'package:sonar/pages/transfer_detail_page.dart';
import 'package:sonar/provider/file_transfer_provider.dart';
import 'package:sonar/provider/network/send_provider.dart';
import 'package:sonar/provider/network/server/server_provider.dart';
import 'package:sonar/provider/transfer_history_provider.dart';
import 'package:sonar/util/device_type_ext.dart';
import 'package:sonar/util/native/open_folder.dart';
import 'package:sonar/util/native/platform_check.dart';
import 'package:sonar/util/notification_strings.dart';
import 'package:sonar/util/system_date_time_formatter.dart';
import 'package:sonar/widget/desktop_scaffold.dart';
import 'package:sonar/widget/desktop_tray.dart';
import 'package:sonar/widget/dialogs/history_clear_dialog.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_card.dart';
import 'package:sonar/widget/ls/ls_chip.dart';
import 'package:sonar/widget/ls/ls_header.dart';
import 'package:sonar/widget/ls/ls_hover.dart';
import 'package:sonar/widget/ls/ls_progress_bar.dart';
import 'package:sonar/widget/ls/ls_section_label.dart';
import 'package:sonar/widget/ls/ls_tile.dart';
import 'package:sonar_isolates/model/device.dart';
import 'package:sonar_isolates/model/dto/file_dto.dart';
import 'package:sonar_isolates/model/session_status.dart';
import 'package:sonar_isolates/util/file_size_helper.dart';
import 'package:sonar_isolates/util/file_speed_helper.dart';

/// The "Transfers" tab: active send/receive sessions on top, the history of
/// finished transfers below.
///
/// The history is one row per finished transfer session, grouped by day. A row
/// opens the detail page of that session, which lists its files (searchable,
/// list or grid) — the group no longer expands in place.
class TransferTab extends StatefulWidget {
  /// Whether the desktop shell layout is used (header is then rendered by the shell).
  final bool desktop;

  const TransferTab({this.desktop = false});

  @override
  State<TransferTab> createState() => _TransferTabState();
}

class _TransferTabState extends State<TransferTab> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final allSends = context.watch(sendProvider).values.toList();
    final sendSessions = allSends.where((session) => _isActive(session.status)).toList();
    final finishedSends = allSends.where(_isDone).toList();
    final receiveSession = context.watch(serverProvider)?.session;
    final activeReceive = receiveSession != null && _isActive(receiveSession.status) ? receiveSession : null;
    final historySessions = context.watch(transferHistoryProvider);
    final days = _groupSessionsByDay(historySessions);
    final activeCount = sendSessions.length + (activeReceive != null ? 1 : 0);

    final subtitle = activeCount > 0 ? Text(t.transferTab.inProgress(n: activeCount), style: tokens.mono) : null;
    final actions = [
      if (historySessions.isNotEmpty)
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
            aside: widget.desktop ? const LsDesktopTray() : null,
            content: ListView(
              padding: EdgeInsets.fromLTRB(tokens.pad, 0, tokens.pad, 18),
              children: [
                if (widget.desktop) ...[
                  Row(
                    children: [
                      Expanded(child: Text(t.transferTab.title, style: tokens.pageTitle)),
                      if (historySessions.isNotEmpty)
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
                if (receiveSession != null && !_isActive(receiveSession.status))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReceiveSessionCard(session: receiveSession, done: true),
                  ),
                for (final session in finishedSends)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SendSessionCard(session: session, done: true),
                  ),
                LsSectionLabel(label: t.transferTab.recent, count: historySessions.isEmpty ? null : '${historySessions.length}'),
                if (days.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(t.transferTab.noHistory, style: tokens.bodySm),
                  )
                else
                  for (final day in days) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 2),
                      child: Text(_dayLabel(context, day.day), style: tokens.eyebrow),
                    ),
                    for (final session in day.sessions) _HistorySessionRow(session: session),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Clears the whole transfer history, as the history page used to do.
  Future<void> _clearHistory() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const HistoryClearDialog(),
    );
    if (result != true || !mounted) {
      return;
    }
    await context.redux(transferHistoryProvider).dispatchAsync(RemoveAllTransferHistorySessionsAction());
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

/// Status chip of a sending session. A session that is still calculating its
/// checksums has not sent the request yet, so it must not claim to wait for an
/// answer.
String? _sendStatusText(SendSessionState session) {
  if (session.isCalculatingChecksums) {
    return t.sendPage.calculatingChecksum(curr: session.hashedFileCount, n: session.files.length);
  }
  return _statusText(session.status);
}

class _SendSessionCard extends StatelessWidget {
  final SendSessionState session;

  /// A finished session stays in the tab as a completion card until dismissed.
  final bool done;

  const _SendSessionCard({required this.session, this.done = false});

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
                      ].join('  '),
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
              if (_sendStatusText(session) != null)
                LsChip.text(_sendStatusText(session)!)
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
          // The bar and the caption only count files the receiver accepted, so
          // both would sit at 0 while the checksums are calculated. That phase
          // has no byte progress to show here, so the bar runs indeterminate and
          // the caption stays away instead of claiming 0%.
          LsProgressBar(value: session.isCalculatingChecksums ? null : progress),
          if (!session.isCalculatingChecksums) ...[
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
          ],
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
  final bool done;

  const _ReceiveSessionCard({required this.session, this.done = false});
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
                      [t.transferTab.items(n: files.length), total.asReadableFileSize].join('  '),
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
              if (session.autoAccepted) ...[
                const SizedBox(width: 6),
                LsChip.text(t.transferTab.autoReceive, accent: true, icon: LucideIcons.zap),
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
          if (done) ...[
            if (checkPlatformWithFileSystem() && session.destinationDirectory.isNotEmpty) ...[
              LsButton(
                label: t.transferTab.openFolder,
                icon: LucideIcons.folder,
                variant: LsButtonVariant.ghost,
                expand: true,
                onPressed: () => openFolder(folderPath: session.destinationDirectory),
              ),
              const SizedBox(height: 8),
            ],
            LsButton(
              label: t.transferTab.done,
              variant: LsButtonVariant.plain,
              expand: true,
              onPressed: () => context.notifier(serverProvider).closeSession(),
            ),
          ] else
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

/// One day of the history, with its finished transfer sessions.
class _HistoryDay {
  final DateTime day;

  final List<TransferHistorySession> sessions = [];

  _HistoryDay(this.day);
}

/// Groups the history into days, newest day and newest transfer first.
List<_HistoryDay> _groupSessionsByDay(List<TransferHistorySession> sessions) {
  final days = <String, _HistoryDay>{};
  for (final session in sessions) {
    final time = session.timestamp.toLocal();
    final day = DateTime(time.year, time.month, time.day);
    (days['${day.year}-${day.month}-${day.day}'] ??= _HistoryDay(day)).sessions.add(session);
  }
  final sorted = days.values.toList()..sort((a, b) => b.day.compareTo(a.day));
  for (final day in sorted) {
    day.sessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
  return sorted;
}

/// `Today`, `Yesterday` or the date of a history day.
String _dayLabel(BuildContext context, DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) {
    return t.transferTab.today;
  }
  if (difference == 1) {
    return t.transferTab.yesterday;
  }
  return SystemDateTimeFormatter.date(context, day);
}

/// One finished transfer session: direction, peer, files and the time of day.
///
/// The row only summarizes; tapping it opens the detail page with the files.
class _HistorySessionRow extends StatelessWidget {
  final TransferHistorySession session;

  const _HistorySessionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final isReceive = !session.isSend;
    // A failed session can still list files (the ones it tried), so the arrow
    // would claim a transfer that never happened.
    final icon = session.failed
        ? LucideIcons.alertTriangle
        : isReceive
        ? LucideIcons.arrowDown
        : LucideIcons.arrowUp;
    final iconColor = session.failed
        ? colors.danger
        : isReceive
        ? colors.accent
        : colors.muted;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.line, width: tokens.hairlineOf(context)),
        ),
      ),
      child: LsHover(
        color: Colors.transparent,
        hoverColor: colors.bg3,
        borderRadius: BorderRadius.zero,
        onTap: () async {
          await context.push(() => TransferDetailPage(session: session));
        },
        builder: (context, hovered) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: colors.bg3, borderRadius: BorderRadius.circular(tokens.radiusSm)),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isReceive ? t.transferTab.receivedFrom(device: session.peerAlias) : t.transferTab.sentTo(device: session.peerAlias),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.bodyStrong,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      [
                        if (session.failed) ...[
                          t.transferTab.failed,
                          // A request that never got an answer left no file
                          // behind, so the reason is all this row has to say.
                          if (session.errorMessage != null) session.errorMessage!,
                          t.transferTab.items(n: session.files.length),
                        ] else ...[
                          t.transferTab.items(n: session.files.length),
                          session.totalSize.asReadableFileSize,
                          if (session.savedToGallery) t.progressPage.savedToGallery,
                        ],
                        SystemDateTimeFormatter.time(context, session.timestamp.toLocal()),
                      ].join('  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: session.failed ? tokens.monoSm.copyWith(color: colors.danger) : tokens.monoSm,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(LucideIcons.chevronRight, size: 14, color: hovered ? colors.muted : colors.faint),
            ],
          ),
        ),
      ),
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
