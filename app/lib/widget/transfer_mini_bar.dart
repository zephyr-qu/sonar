import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/pages/progress_page.dart';
import 'package:sonar/provider/file_transfer_provider.dart';
import 'package:sonar/provider/network/send_provider.dart';
import 'package:sonar/provider/network/server/server_provider.dart';
import 'package:sonar/util/device_type_ext.dart';
import 'package:sonar/util/session_status_ext.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_progress_bar.dart';
import 'package:sonar_isolates/model/device.dart';
import 'package:sonar_isolates/model/session_status.dart';

/// One entry per file of a session that a row has to sum up.
typedef _FileEntry = ({String id, int size});

typedef _TransferEntry = ({String sessionId, Device device, String title, List<_FileEntry> files, SessionStatus status});

/// A strip of rows for transfers that keep running while the user is elsewhere.
///
/// A transfer no longer takes the window, so the shell has to say that bytes are
/// moving. The desktop shell has a side rail for that; on a phone the tab bar is
/// the only persistent chrome, so the strip sits right above it. The Transfers
/// tab already shows every transfer as a card with the same numbers, so the strip
/// is only mounted on the other tabs.
///
/// A receive stays in the strip after it finished, the same way the desktop rail
/// keeps it: the completion (status, open folder, done) must not vanish the
/// moment the "open file" dialog closes. Only a request that is still being
/// asked (`waiting`) stays out, since its dialog is on screen anyway.
///
/// A row is a summary, not the transfer: tapping one opens [ProgressPage].
class TransferMiniBar extends StatelessWidget {
  const TransferMiniBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;

    final receive = context.watch(serverProvider)?.session;
    final sends = context.watch(sendProvider).values.where((session) => session.status == SessionStatus.sending);

    final entries = <_TransferEntry>[
      if (receive != null && receive.status != SessionStatus.waiting)
        (
          sessionId: receive.sessionId,
          device: receive.sender,
          title: receive.status == SessionStatus.sending
              ? t.transferTab.receiving(device: receive.senderAlias)
              : t.transferTab.receivedFrom(device: receive.senderAlias),
          files: [for (final file in receive.files.values) (id: file.file.id, size: file.file.size)],
          status: receive.status,
        ),
      for (final send in sends)
        (
          sessionId: send.sessionId,
          device: send.target,
          title: t.transferTab.sending(device: send.target.alias),
          // Only files the receiver accepted are actually transferred.
          files: [
            for (final file in send.files.values)
              if (file.token != null) (id: file.file.id, size: file.file.size),
          ],
          status: send.status,
        ),
    ];
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(
          top: BorderSide(color: colors.line, width: tokens.hairlineOf(context)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Two rows fit; anything beyond that stays reachable via the Transfers tab.
          for (final entry in entries.take(2)) _MiniBarRow(entry: entry),
        ],
      ),
    );
  }
}

class _MiniBarRow extends StatelessWidget {
  final _TransferEntry entry;

  const _MiniBarRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final transfer = context.ref.read(fileTransferProvider);

    return ValueListenableBuilder<int>(
      valueListenable: transfer.sessionTick(entry.sessionId),
      builder: (context, _, _) {
        final totalBytes = entry.files.fold<int>(0, (sum, file) => sum + file.size);
        final transferredBytes = entry.files.fold<int>(
          0,
          (sum, file) => sum + (transfer.getProgress(sessionId: entry.sessionId, fileId: file.id) * file.size).round(),
        );
        final progress = totalBytes <= 0 ? 0.0 : (transferredBytes / totalBytes).clamp(0.0, 1.0).toDouble();
        // A finished transfer reports its outcome, not a number that can no
        // longer move.
        final trailing = entry.status == SessionStatus.sending ? '${(progress * 100).round()}%' : sessionStatusText(entry.status) ?? '';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push(() => ProgressPage(sessionId: entry.sessionId)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(tokens.pad, 8, tokens.pad, 10),
              child: Row(
                children: [
                  Icon(entry.device.deviceType.icon, size: 18, color: colors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tokens.bodySm.copyWith(color: colors.fg),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(trailing, style: tokens.monoSm),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LsProgressBar(value: progress, height: 2),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (entry.status == SessionStatus.sending)
                    Icon(LucideIcons.chevronRight, size: 14, color: colors.faint)
                  else
                    // The row's own area still opens the transfer, so the only
                    // thing the button does is retire the finished session.
                    LsButton(
                      label: t.transferTab.done,
                      variant: LsButtonVariant.ghost,
                      compact: true,
                      onPressed: () => context.notifier(serverProvider).closeSession(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
