import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/cross_file.dart';
import 'package:sonar/model/state/send/send_session_state.dart';
import 'package:sonar/pages/home_page.dart';
import 'package:sonar/pages/home_page_controller.dart';
import 'package:sonar/pages/progress_page.dart';
import 'package:sonar/pages/selected_files_page.dart';
import 'package:sonar/pages/tabs/nearby_tab_vm.dart';
import 'package:sonar/provider/file_transfer_provider.dart';
import 'package:sonar/provider/network/send_provider.dart';
import 'package:sonar/provider/network/server/server_provider.dart';
import 'package:sonar/provider/settings_provider.dart';
import 'package:sonar/util/file_type_ext.dart';
import 'package:sonar/util/native/macos_channel.dart';
import 'package:sonar/util/native/pick_directory_path.dart';
import 'package:sonar/util/native/platform_check.dart';
import 'package:sonar/util/session_progress.dart';
import 'package:sonar/util/session_status_ext.dart';
import 'package:sonar/util/ui/snackbar.dart';
import 'package:sonar/widget/dialogs/encryption_disabled_notice.dart';
import 'package:sonar/widget/dialogs/pin_dialog.dart';
import 'package:sonar/widget/dialogs/quick_save_notice.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_progress_bar.dart';
import 'package:sonar/widget/ls/ls_section_label.dart';
import 'package:sonar/widget/ls/ls_switch.dart';
import 'package:sonar/widget/ls/ls_tile.dart';
import 'package:sonar/widget/session_progress_builder.dart';
import 'package:sonar_isolates/model/device.dart';
import 'package:sonar_isolates/model/session_status.dart';
import 'package:sonar_isolates/util/file_size_helper.dart';

/// How many files the tray lists before it hands the rest over to
/// [SelectedFilesPage].
///
/// A real tray holds hundreds of files; listing them all pushes "in progress"
/// and the receive policy far down the sidebar, so the list stops here and an
/// "all files" link takes over.
///
/// The rows are the *newest* picks, not the first ones: the file that just
/// landed is the one the user is looking for, and a pick that never shows up
/// looks like the drop failed. Their order stays the selection order — the tray
/// shows the tail of the list [SelectedFilesPage] renders.
const int maxTrayRows = 3;

/// The sidebar of the desktop shell: pending files, running transfers, receive
/// policy.
///
/// Both desktop tabs render it — the transfer tab only reports, so it passes
/// `showSend: false`; the nearby tab adds the send footer, which needs the
/// device selection that lives in its own state.
class LsDesktopTray extends StatelessWidget {
  /// Whether the send footer (button) is rendered.
  final bool showSend;

  /// Devices picked in the nearby grid; the send button is a no-op without them.
  final List<Device> picked;

  /// Starts one session per picked device, `true` when anything was sent.
  final Future<bool> Function(List<Device> targets)? onSend;

  /// Called after a successful send so the caller can clear its selection.
  final VoidCallback? onSent;

  const LsDesktopTray({this.showSend = false, this.picked = const [], this.onSend, this.onSent, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final vm = context.watch(nearbyTabVmProvider);
    final settings = context.watch(settingsProvider);
    final files = vm.selectedFiles;
    final totalSize = files.fold<int>(0, (sum, file) => sum + file.size);
    final sessions = context.watch(sendProvider).values.toList();
    // Running sessions are all listed. A failed one stays in the state until it
    // is closed — a request that never got an answer would otherwise just
    // disappear — but the sidebar cannot hold one row per attempt: each retry
    // pushed the receive policy further down. The newest failure stands for the
    // rest; the Transfers tab likewise keeps a completion card for the newest
    // one only, and closes the older ones automatically.
    final runningSessions = sessions.where((session) => session.status == SessionStatus.waiting || session.status == SessionStatus.sending).toList();
    final failedSessions = sessions.where((session) => session.status.isTerminalFailure).toList()
      ..sort((a, b) => _finishedAt(b).compareTo(_finishedAt(a)));
    final latestFailure = failedSessions.isEmpty ? null : failedSessions.first;
    final hiddenFailures = failedSessions.length - (latestFailure == null ? 0 : 1);
    final runningTargets = runningSessions.map((session) => session.target.fingerprint).toSet();
    // A session only reports back once the receiver answered, so the button keeps
    // its spinner while anything of the selection is still in flight.
    final sending = picked.any((device) => runningTargets.contains(device.fingerprint));
    final serverState = context.watch(serverProvider);
    final receiveSession = serverState?.session;
    final activeReceive = receiveSession != null && (receiveSession.status == SessionStatus.waiting || receiveSession.status == SessionStatus.sending)
        ? receiveSession
        : null;
    final activeCount = runningSessions.length + (latestFailure == null ? 0 : 1) + (activeReceive != null ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LsSectionLabel(
          label: t.nearbyTab.tray,
          count: files.isEmpty ? null : totalSize.asReadableFileSize,
          padding: const EdgeInsets.only(bottom: 8),
        ),
        if (files.isEmpty)
          _DropZone(onTap: () async => vm.onAddFiles(context))
        else ...[
          for (final index in _trayIndexes(files.length))
            LsFileRow(
              kind: fileKind(files[index].name),
              name: files[index].displayName,
              meta: files[index].size.asReadableFileSize,
              trailing: LsIconButton(
                icon: LucideIcons.x,
                tooltip: t.general.delete,
                onPressed: () => vm.onRemoveFile(index),
              ),
            ),
          if (files.length > maxTrayRows)
            LsLinkRow(
              label: t.selectedFilesPage.title,
              value: '${files.length}',
              leading: const Icon(LucideIcons.list),
              onTap: () async => context.push(() => const SelectedFilesPage()),
            ),
          LsLinkRow(
            label: t.nearbyTab.addFile,
            leading: const Icon(LucideIcons.plus),
            onTap: () async => vm.onAddFiles(context),
          ),
          if (showSend) ...[
            const SizedBox(height: 12),
            LsButton(
              label: t.nearbyTab.send,
              icon: LucideIcons.send,
              expand: true,
              loading: sending,
              // Enabled without a target on purpose: the tap is how the hint
              // "pick a target device" reaches the user, instead of a caption
              // that sits under the button forever.
              onPressed: () async {
                if (picked.isEmpty) {
                  context.showSnackBar(t.nearbyTab.selectTarget);
                  return;
                }
                // Nothing moves until the receiver answered, so the click itself
                // acknowledges what is happening. The checksums are calculated
                // before the request goes out: the send page shows that, but a
                // background session has no page, so it says so here instead.
                final hashing = settings.createChecksums && files.isNotEmpty;
                context.showSnackBar(
                  hashing
                      ? t.sendPage.calculatingChecksum(curr: 0, n: files.length)
                      : picked.length == 1
                      ? t.nearbyTab.requesting(device: picked.first.alias)
                      : t.nearbyTab.requestingMany(n: picked.length),
                );
                final started = await onSend!(picked);
                if (started) {
                  onSent?.call();
                }
              },
            ),
          ],
        ],
        LsSectionLabel(label: t.nearbyTab.inProgress),
        if (activeCount == 0)
          Text(t.transferTab.noActive, style: tokens.monoSm.copyWith(color: colors.faint))
        else ...[
          for (final session in runningSessions) _SendSessionRow(session: session),
          if (latestFailure != null) _SendSessionRow(session: latestFailure),
          if (hiddenFailures > 0)
            LsLinkRow(
              label: t.nearbyTab.moreFailures(n: hiddenFailures),
              leading: const Icon(LucideIcons.alertTriangle),
              // Every one of them keeps its own close button on the Transfers
              // tab; the sidebar only carries the newest.
              onTap: () => context.redux(homePageControllerProvider).dispatch(ChangeTabAction(HomeTab.transfer)),
            ),
          if (activeReceive != null) ...[
            // The row names the transfer; the full view is one click away, in the
            // same place a sending session offers it.
            InkWell(
              borderRadius: tokens.tileRadius,
              onTap: () => context.push(() => ProgressPage(sessionId: activeReceive.sessionId)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.transferTab.receiving(device: activeReceive.senderAlias),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.bodySm.copyWith(color: colors.fg),
                    ),
                  ),
                  Icon(LucideIcons.chevronRight, size: 14, color: colors.faint),
                ],
              ),
            ),
            const SizedBox(height: 8),
            LsButton(
              label: t.transferTab.cancel,
              variant: LsButtonVariant.ghost,
              onPressed: () => context.notifier(serverProvider).cancelSession(),
            ),
            const SizedBox(height: 10),
          ],
        ],
        LsSectionLabel(label: t.nearbyTab.receivePolicy),
        Row(
          children: [
            // The glyph slot matches the two rows below (folder, shield), so the
            // whole receive-policy block reads as one list.
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Icon(LucideIcons.zap, size: 15, color: colors.muted),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                // The switch alone says whether this is on, so the row only
                // names the setting; the folder it saves to is the row below.
                t.general.quickSave,
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
        if (checkPlatformWithFileSystem())
          LsLinkRow(
            label: t.settingsTab.receive.destination,
            value: settings.destination == null ? t.settingsTab.receive.downloads : _folderName(settings.destination!),
            leading: const Icon(LucideIcons.folderOpen),
            showTopBorder: false,
            onTap: () async {
              final directory = await pickDirectoryPath();
              if (directory == null) {
                return;
              }
              if (defaultTargetPlatform == TargetPlatform.macOS) {
                await persistDestinationFolderAccess(directory);
              }
              if (!context.mounted) {
                return;
              }
              await context.notifier(settingsProvider).setDestination(directory);
            },
          ),
        const SizedBox(height: 6),
        // Encryption and PIN belong next to the receive policy: they decide what
        // a sender has to do before the server accepts anything, which is the
        // same question quick save and the destination folder answer.
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Icon(LucideIcons.shield, size: 15, color: colors.muted),
            ),
            const SizedBox(width: 8),
            // The switch alone says whether this is on, like the quick save row.
            Expanded(child: Text(t.settingsTab.network.encryption, style: tokens.bodySm)),
            LsSwitch(
              value: settings.https,
              label: t.settingsTab.network.encryption,
              onChanged: (value) async {
                final wasEncrypted = settings.https;
                await context.notifier(settingsProvider).setHttps(value);
                if (wasEncrypted && !value && context.mounted) {
                  await EncryptionDisabledNotice.open(context);
                }
              },
            ),
          ],
        ),
        // https is only read when the server starts, so the changed setting
        // applies on the next restart; the tray offers that restart instead of
        // tearing down a running transfer behind the user's back.
        if (serverState != null && serverState.https != settings.https)
          LsLinkRow(
            label: t.settingsTab.network.needRestart,
            leading: const Icon(LucideIcons.refreshCw),
            showTopBorder: false,
            onTap: () async => context.notifier(serverProvider).restartServerFromSettings(),
          ),
        // A PIN is fixed at server start too, so this row always restarts: the
        // switch-like value would otherwise claim a PIN the server never reads.
        //
        // The switch is the value, like the two rows above, but flipping it on
        // needs the PIN itself: that is what the dialog is for. A cancelled or
        // empty dialog reads as "never mind" — the setting keeps no PIN, so the
        // thumb falls back to off by itself.
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Icon(LucideIcons.key, size: 15, color: colors.muted),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(t.settingsTab.receive.requirePin, style: tokens.bodySm)),
            LsSwitch(
              value: settings.receivePin != null,
              label: t.settingsTab.receive.requirePin,
              onChanged: (value) async {
                final settingsNotifier = context.notifier(settingsProvider);
                final serverNotifier = context.notifier(serverProvider);
                // Turning off clears the PIN; turning on asks for one first.
                String? newPin;
                if (value) {
                  newPin = await showDialog<String>(
                    context: context,
                    builder: (_) => const PinDialog(obscureText: false, generateRandom: false),
                  );
                  if (newPin == null || newPin.isEmpty) {
                    return;
                  }
                }
                await settingsNotifier.setReceivePin(newPin);
                if (serverState != null) {
                  await serverNotifier.restartServerFromSettings();
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Empty tray: the whole block is a click target for picking files.
class _DropZone extends StatelessWidget {
  final VoidCallback onTap;

  const _DropZone({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: tokens.tileRadius,
        side: BorderSide(color: colors.lineStrong, width: tokens.hairlineOf(context)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: tokens.tileRadius,
        hoverColor: colors.accentSoft,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.plus, size: 16, color: colors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t.nearbyTab.dropHere, style: tokens.body.copyWith(color: colors.muted)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(t.nearbyTab.dropHint, style: tokens.bodySm),
            ],
          ),
        ),
      ),
    );
  }
}

double _sendProgress(SendSessionState session, FileTransferNotifier transfer) {
  return SessionProgress.measure(
    sessionId: session.sessionId,
    files: session.files.values.where((file) => file.token != null).map((file) => (file.file.id, file.file.size)),
    transfer: transfer,
  ).fraction;
}

/// One send session in the sidebar: the peer, where it stands, and the action
/// that ends it.
class _SendSessionRow extends StatelessWidget {
  final SendSessionState session;

  const _SendSessionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: tokens.tileRadius,
          // Only a running transfer has more to show than this row already does.
          onTap: session.status == SessionStatus.sending ? () => context.push(() => ProgressPage(sessionId: session.sessionId)) : null,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  session.target.alias,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.bodySm.copyWith(color: colors.fg),
                ),
              ),
              if (session.status == SessionStatus.sending)
                SessionProgressBuilder(
                  sessionId: session.sessionId,
                  builder: (context, transfer) => Text(
                    '${(_sendProgress(session, transfer) * 100).round()}%',
                    style: tokens.monoSm,
                  ),
                )
              else if (session.status.isTerminalFailure)
                Text(t.general.error, style: tokens.monoSm.copyWith(color: colors.danger)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (session.status == SessionStatus.waiting) ...[
          // Nothing to progress on before the request is sent: the sender
          // is still calculating the checksums that go into it.
          Text(
            session.isCalculatingChecksums
                ? t.sendPage.calculatingChecksum(curr: session.hashedFileCount, n: session.files.length)
                : t.sendPage.waiting,
            style: tokens.monoSm.copyWith(color: colors.muted),
          ),
          const SizedBox(height: 6),
          const LsProgressBar(value: null),
        ] else if (session.status.isTerminalFailure)
          Text(
            session.errorMessage ?? sessionStatusText(session.status) ?? t.general.error,
            style: tokens.bodySm.copyWith(color: colors.danger),
          )
        else
          SessionProgressBuilder(
            sessionId: session.sessionId,
            builder: (context, transfer) => LsProgressBar(value: _sendProgress(session, transfer)),
          ),
        const SizedBox(height: 8),
        LsButton(
          label: session.status.isTerminalFailure ? t.general.close : t.transferTab.cancel,
          variant: LsButtonVariant.ghost,
          onPressed: () => session.status.isTerminalFailure
              ? context.notifier(sendProvider).closeSession(session.sessionId)
              : context.notifier(sendProvider).cancelSession(session.sessionId),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

/// Orders failed sessions newest first. A request that ran out waiting has no
/// end time, so its start time stands in.
int _finishedAt(SendSessionState session) => session.endTime ?? session.startTime ?? 0;

/// Indexes the tray lists, in selection order: the last [maxTrayRows] entries,
/// because new picks are appended to the selection.
Iterable<int> _trayIndexes(int length) sync* {
  for (var index = length > maxTrayRows ? length - maxTrayRows : 0; index < length; index++) {
    yield index;
  }
}

/// The last segment of a picked directory, which is what the tray shows.
///
/// The stored value is an absolute path (a Windows one uses backslashes), and
/// the sidebar is 300px wide — the settings page shows the full path instead.
String _folderName(String path) {
  final parts = path.replaceAll('\\', '/').split('/').where((part) => part.isNotEmpty);
  return parts.isEmpty ? path : parts.last;
}
