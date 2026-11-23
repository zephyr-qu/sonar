import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/addons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/state/send/send_session_state.dart';
import 'package:sonar/pages/verify_page.dart';
import 'package:sonar/provider/favorites_provider.dart';
import 'package:sonar/provider/file_transfer_provider.dart';
import 'package:sonar/provider/network/send_provider.dart';
import 'package:sonar/util/device_type_ext.dart';
import 'package:sonar/util/favorites.dart';
import 'package:sonar/util/fingerprint.dart';
import 'package:sonar/util/native/taskbar_helper.dart';
import 'package:sonar/util/session_status_ext.dart';
import 'package:sonar/widget/dialogs/error_dialog.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_card.dart';
import 'package:sonar/widget/ls/ls_chip.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';
import 'package:sonar/widget/ls/ls_progress_bar.dart';
import 'package:sonar_isolates/model/device.dart';
import 'package:sonar_isolates/model/session_status.dart';
import 'package:sonar_isolates/util/file_size_helper.dart';

/// Shows the outgoing handshake of one session as a modal dialog over the shell.
///
/// Waiting for the receiver's answer is an interruption that asks for one
/// decision — accept the wait or cancel — not a screen to navigate to, so it
/// takes the same shape as the incoming request dialog and leaves the shell
/// visible behind it. Once the receiver accepts, the dialog steps aside: the
/// transfer continues in the background (Transfers tab, tray, and on mobile the
/// strip above the tab bar), and tapping that entry opens the progress page.
Future<void> showSendRequestDialog(String sessionId) async {
  final navigator = Routerino.navigatorKey.currentState!;
  assert(navigator.mounted);
  unawaited(
    navigator.push<void>(
      DialogRoute<void>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (_) => SendRequestDialog(sessionId: sessionId),
      ),
    ),
  );
}

/// Sending status of one session: the target device, the handshake state and the
/// cancel/close action.
class SendRequestDialog extends StatefulWidget {
  final String sessionId;

  const SendRequestDialog({required this.sessionId});

  @override
  State<SendRequestDialog> createState() => _SendRequestDialogState();
}

double _hashProgress(SendSessionState sendState, FileTransferNotifier transferNotifier) {
  final files = sendState.files.values;
  final totalBytes = files.fold<int>(0, (prev, curr) => prev + curr.file.size);
  if (totalBytes == 0) {
    return sendState.files.isEmpty ? 0 : sendState.hashedFileCount / sendState.files.length;
  }
  final hashedBytes = files.fold<double>(
    0,
    (prev, curr) => prev + transferNotifier.getProgress(sessionId: sendState.sessionId, fileId: curr.file.id) * curr.file.size,
  );
  return (hashedBytes / totalBytes).clamp(0, 1);
}

/// Progress of the checksum calculation in the waiting card.
///
/// Progress events arrive up to 50 times per second, so this widget subscribes to the session
/// tick of the [fileTransferProvider] itself instead of letting the whole dialog watch it.
class _HashProgressBar extends StatelessWidget {
  final SendSessionState sendState;

  const _HashProgressBar({required this.sendState});

  @override
  Widget build(BuildContext context) {
    final transferNotifier = context.ref.read(fileTransferProvider);
    return ValueListenableBuilder<int>(
      valueListenable: transferNotifier.sessionTick(sendState.sessionId),
      builder: (context, _, _) => LsProgressBar(value: _hashProgress(sendState, transferNotifier)),
    );
  }
}

class _SendRequestDialogState extends State<SendRequestDialog> with Refena {
  @override
  void dispose() {
    super.dispose();
    unawaited(TaskbarHelper.clearProgressBar());
  }

  void _cancel() {
    final sendState = ref.read(sendProvider)[widget.sessionId];
    if (sendState == null) {
      return;
    }

    // The bytes are already moving: leaving this dialog must not abort the
    // transfer, which lives on in the Transfers tab (and in the strip above the
    // tab bar on mobile). Stopping it is an explicit action on the progress
    // page.
    //
    // This check has to sit outside any setState callback: a `return` inside
    // the callback only ends the callback, so the cancelSession below would
    // still run and abort a transfer that is already in flight.
    // A session that already ended badly keeps its completion card in the
    // Transfers tab, which is where it is dismissed: this dialog only waited for
    // the answer, so stepping aside must not throw that answer away.
    if (sendState.status == SessionStatus.sending || sendState.status.isTerminalFailure) {
      return;
    }

    ref.notifier(sendProvider).cancelSession(widget.sessionId);
  }

  /// Closes the dialog and applies the decision matching what is on screen.
  void _dismiss(BuildContext context) {
    _cancel();
    context.global.dispatch(NavigateAction.popUntilRoot());
  }

  @override
  Widget build(BuildContext context) {
    final sendState = ref.watch(
      sendProvider.select((state) => state[widget.sessionId]),
      listener: (prev, next) {
        final prevStatus = prev[widget.sessionId]?.status;
        final nextStatus = next[widget.sessionId]?.status;
        if (prevStatus != nextStatus) {
          // ignore: discarded_futures
          TaskbarHelper.visualizeStatus(nextStatus);

          // The receiver answered: the transfer runs in the background from
          // here on (Transfers tab, tray, and on mobile the strip above the tab
          // bar), and this dialog only waited for the answer, so it steps aside
          // instead of blocking. The session itself stays alive — cancelling it
          // is an explicit action on the progress page.
          if (nextStatus == SessionStatus.sending) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
              }
            });
          }
        }
      },
    );

    if (sendState == null) {
      // The session ended while the dialog was open (canceled or closed
      // elsewhere): an empty dialog would just hang over the shell.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        }
      });
      return const SizedBox.shrink();
    }

    return PopScope(
      // Back must go through [_dismiss]: popping the dialog silently would leave
      // the session waiting with no route back to it.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _dismiss(context);
        }
      },
      child: _dialog(context, sendState),
    );
  }

  Widget _dialog(BuildContext context, SendSessionState sendState) {
    final targetDevice = sendState.target;
    final targetFavoriteEntry = ref.watch(favoritesProvider.select((state) => state.findDevice(targetDevice)));
    final targetAlias = targetFavoriteEntry?.alias ?? targetDevice.alias;
    final waiting = sendState.status == SessionStatus.waiting;
    final totalSize = sendState.files.values.fold<int>(0, (sum, file) => sum + file.file.size);

    return LsDialog(
      title: Text(t.transferTab.sending(device: targetAlias)),
      maxWidth: 460,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _targetBlock(context, targetDevice, targetAlias),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              LsChip.text(t.transferTab.items(n: sendState.files.length)),
              LsChip.text(totalSize.asReadableFileSize),
              LsChip.text(targetDevice.https ? t.receiveRequestPage.secure : t.receiveRequestPage.plain, accent: targetDevice.https),
            ],
          ),
          if (_statusCard(context, sendState) case final card?) ...[
            const SizedBox(height: 12),
            card,
          ],
        ],
      ),
      actions: [
        LsButton(
          label: waiting ? t.general.cancel : t.general.close,
          icon: waiting ? LucideIcons.x : LucideIcons.checkCircle,
          variant: LsButtonVariant.ghost,
          onPressed: () => _dismiss(context),
        ),
      ],
    );
  }

  /// The receiver: alias, device model + address and the certificate fingerprint
  /// in one block, with the verify action next to the identity it checks.
  Widget _targetBlock(BuildContext context, Device device, String alias) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final meta = [
      if (device.deviceModel != null) device.deviceModel!,
      if (device.ip != null) device.ip!,
    ].join('  ');
    final fingerprint = device.fingerprint;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: colors.bg3, borderRadius: BorderRadius.circular(tokens.radiusSm)),
          child: Icon(device.deviceType.icon, size: 20, color: colors.fg),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(alias, maxLines: 1, overflow: TextOverflow.ellipsis, style: tokens.subtitle),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: tokens.monoSm),
              ],
              if (fingerprint.isNotEmpty) ...[
                const SizedBox(height: 2),
                Tooltip(
                  message: '${t.receiveRequestPage.fingerprint}: ${t.receiveRequestPage.fingerprintDesc}',
                  child: Text(
                    shortFingerprint(fingerprint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.monoSm.copyWith(color: colors.faint),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        LsButton(
          label: t.verifyPage.title,
          icon: LucideIcons.badgeCheck,
          variant: LsButtonVariant.ghost,
          compact: true,
          // Without https there is no peer certificate to compare.
          onPressed: !device.https
              ? null
              : () async => context.push(
                  () => VerifyPage(
                    fingerprint: CombinedFingerprint.load(context, device.fingerprint),
                  ),
                ),
        ),
      ],
    );
  }

  /// Handshake state of the session; `null` when the session is still silent.
  Widget? _statusCard(BuildContext context, SendSessionState sendState) {
    final tokens = context.ls;
    final colors = tokens.colors;

    switch (sendState.status) {
      case SessionStatus.waiting:
        final hashing = sendState.hashedFileCount < sendState.files.length;
        return LsCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                hashing ? t.sendPage.calculatingChecksum(curr: sendState.hashedFileCount, n: sendState.files.length) : t.sendPage.waiting,
                style: tokens.bodySm,
              ),
              if (hashing)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _HashProgressBar(sendState: sendState),
                ),
            ],
          ),
        );
      case SessionStatus.declined || SessionStatus.tooManyAttempts || SessionStatus.recipientBusy:
        final message = switch (sendState.status) {
          SessionStatus.declined => t.sendPage.rejected,
          SessionStatus.tooManyAttempts => t.sendPage.tooManyAttempts,
          _ => t.sendPage.busy,
        };
        return LsCard(
          padding: const EdgeInsets.all(14),
          borderColor: colors.danger.withValues(alpha: 0.4),
          child: Text(message, style: tokens.bodySm.copyWith(color: colors.danger)),
        );
      case SessionStatus.finishedWithErrors:
        return LsCard(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          borderColor: colors.danger.withValues(alpha: 0.4),
          child: Row(
            children: [
              Expanded(
                child: Text(t.general.error, style: tokens.bodySm.copyWith(color: colors.danger)),
              ),
              if (sendState.errorMessage != null)
                LsIconButton(
                  icon: LucideIcons.info,
                  tooltip: t.general.error,
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ErrorDialog(error: sendState.errorMessage!),
                  ),
                ),
            ],
          ),
        );
      default:
        return null;
    }
  }
}
