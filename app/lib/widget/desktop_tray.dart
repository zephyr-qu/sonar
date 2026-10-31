import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/model/state/send/send_session_state.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/selected_files_page.dart';
import 'package:localsend_app/pages/tabs/nearby_tab_vm.dart';
import 'package:localsend_app/provider/file_transfer_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/native/macos_channel.dart';
import 'package:localsend_app/util/native/pick_directory_path.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/ui/snackbar.dart';
import 'package:localsend_app/widget/dialogs/quick_save_notice.dart';
import 'package:localsend_app/widget/ls/ls_buttons.dart';
import 'package:localsend_app/widget/ls/ls_progress_bar.dart';
import 'package:localsend_app/widget/ls/ls_section_label.dart';
import 'package:localsend_app/widget/ls/ls_switch.dart';
import 'package:localsend_app/widget/ls/ls_tile.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:localsend_isolates/util/file_size_helper.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

/// How many files the tray lists before it hands the rest over to
/// [SelectedFilesPage].
///
/// A real tray holds hundreds of files; listing them all pushes "in progress"
/// and the receive policy far down the sidebar, so the list stops here and an
/// "all files" link takes over.
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
    final sendSessions = context
        .watch(sendProvider)
        .values
        .where((session) => session.status == SessionStatus.waiting || session.status == SessionStatus.sending)
        .toList();
    final receiveSession = context.watch(serverProvider)?.session;
    final activeReceive = receiveSession != null && (receiveSession.status == SessionStatus.waiting || receiveSession.status == SessionStatus.sending)
        ? receiveSession
        : null;
    final activeCount = sendSessions.length + (activeReceive != null ? 1 : 0);

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
          for (final (index, file) in files.take(maxTrayRows).indexed)
            LsFileRow(
              kind: _kindOf(file),
              name: file.displayName,
              meta: file.size.asReadableFileSize,
              trailing: LsIconButton(
                icon: LucideIcons.x,
                tooltip: file.name,
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
              // Enabled without a target on purpose: the tap is how the hint
              // "pick a target device" reaches the user, instead of a caption
              // that sits under the button forever.
              onPressed: () async {
                if (picked.isEmpty) {
                  context.showSnackBar(t.nearbyTab.selectTarget);
                  return;
                }
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
                  builder: (context, transfer) => Text(
                    '${(_sendProgress(session, transfer) * 100).round()}%',
                    style: tokens.monoSm,
                  ),
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
            const SizedBox(height: 10),
          ],
          if (activeReceive != null) ...[
            Text(
              t.transferTab.receiving(device: activeReceive.senderAlias),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.bodySm.copyWith(color: colors.fg),
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
            trailingIcon: LucideIcons.pencil,
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
        LsLinkRow(
          label: t.nearbyTab.securitySettings,
          leading: const Icon(LucideIcons.shield),
          showTopBorder: false,
          onTap: () => context.redux(homePageControllerProvider).dispatch(ChangeTabAction(HomeTab.settings)),
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

String _kindOf(CrossFile file) {
  final name = file.name;
  final dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) {
    return 'FILE';
  }
  final kind = name.substring(dot + 1).toUpperCase();
  return kind.length > 4 ? kind.substring(0, 4) : kind;
}

/// Rebuilds only [builder] when the progress of [sessionId] changes.
///
/// Progress events arrive up to 50 times per second, so watching
/// [fileTransferProvider] would rebuild the whole sidebar for every tick.
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

/// The last segment of a picked directory, which is what the tray shows.
///
/// The stored value is an absolute path (a Windows one uses backslashes), and
/// the sidebar is 300px wide — the settings page shows the full path instead.
String _folderName(String path) {
  final parts = path.replaceAll('\\', '/').split('/').where((part) => part.isNotEmpty);
  return parts.isEmpty ? path : parts.last;
}
