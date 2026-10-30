import 'dart:async';

import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/state/send/send_session_state.dart';
import 'package:localsend_app/pages/verify_page.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/file_transfer_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/native/taskbar_helper.dart';
import 'package:localsend_app/widget/animations/initial_fade_transition.dart';
import 'package:localsend_app/widget/animations/initial_slide_transition.dart';
import 'package:localsend_app/widget/dialogs/error_dialog.dart';
import 'package:localsend_app/widget/ls/ls_buttons.dart';
import 'package:localsend_app/widget/ls/ls_card.dart';
import 'package:localsend_app/widget/ls/ls_header.dart';
import 'package:localsend_app/widget/ls/ls_progress_bar.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/addons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

/// Sending status of one session: the two devices, the handshake state and the
/// cancel/close action.
class SendPage extends StatefulWidget {
  final bool closeSessionOnClose;
  final String sessionId;

  const SendPage({
    required this.closeSessionOnClose,
    required this.sessionId,
  });

  @override
  State<SendPage> createState() => _SendPageState();
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
/// tick of the [fileTransferProvider] itself instead of letting the whole page watch it.
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

class _SendPageState extends State<SendPage> with Refena {
  Device? _myDevice;
  Device? _targetDevice;

  @override
  void dispose() {
    super.dispose();
    unawaited(TaskbarHelper.clearProgressBar());
  }

  void _cancel() {
    // the state will be lost so we store them temporarily (only for UI)
    final myDevice = ref.read(deviceFullInfoProvider);
    final sendState = ref.read(sendProvider)[widget.sessionId];
    if (sendState == null) {
      return;
    }

    setState(() {
      _myDevice = myDevice;
      _targetDevice = sendState.target;
    });
    ref.notifier(sendProvider).cancelSession(widget.sessionId);
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
        }
      },
    );
    if (sendState == null && _myDevice == null && _targetDevice == null) {
      return Scaffold(
        body: Container(),
      );
    }

    final tokens = context.ls;
    final colors = tokens.colors;
    final myDevice = ref.watch(deviceFullInfoProvider);
    final targetDevice = sendState?.target ?? _targetDevice!;
    final targetFavoriteEntry = ref.watch(favoritesProvider.select((state) => state.findDevice(targetDevice)));
    final targetAlias = targetFavoriteEntry?.alias ?? targetDevice.alias;
    final waiting = sendState?.status == SessionStatus.waiting;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && widget.closeSessionOnClose) {
          _cancel();
        }
      },
      canPop: true,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LsSubHeader(
                    title: t.transferTab.sending(device: targetAlias),
                    subtitle: Text(
                      '${targetDevice.ip}:${targetDevice.port} · ${targetDevice.deviceModel ?? targetDevice.deviceType.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.mono,
                    ),
                    onBack: () => Navigator.maybePop(context),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      children: [
                        InitialSlideTransition(
                          origin: const Offset(0, -1),
                          duration: const Duration(milliseconds: 400),
                          child: _SendDeviceCard(
                            device: myDevice,
                            label: t.transferTab.items(n: sendState?.files.length ?? 0),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: InitialFadeTransition(
                            duration: const Duration(milliseconds: 300),
                            delay: const Duration(milliseconds: 400),
                            child: Row(
                              children: [
                                const SizedBox(width: 18),
                                Icon(LucideIcons.arrowDown, size: 14, color: colors.accent),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                        Hero(
                          tag: 'device-${targetDevice.ip}',
                          child: _SendDeviceCard(
                            device: targetDevice,
                            aliasOverride: targetAlias,
                            highlighted: true,
                          ),
                        ),
                        if (targetDevice.https)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: InitialFadeTransition(
                                duration: const Duration(milliseconds: 300),
                                delay: const Duration(milliseconds: 400),
                                child: LsButton(
                                  label: t.verifyPage.title,
                                  icon: LucideIcons.badgeCheck,
                                  variant: LsButtonVariant.ghost,
                                  onPressed: () async => await context.push(
                                    () => VerifyPage(
                                      fingerprint: CombinedFingerprint.load(context, targetDevice.fingerprint),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (sendState != null)
                    InitialFadeTransition(
                      duration: const Duration(milliseconds: 300),
                      delay: const Duration(milliseconds: 400),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_statusCard(context, sendState) case final card?) ...[
                              card,
                              const SizedBox(height: 10),
                            ],
                            LsButton(
                              label: waiting ? t.general.cancel : t.general.close,
                              icon: waiting ? LucideIcons.x : LucideIcons.checkCircle,
                              expand: true,
                              onPressed: () {
                                _cancel();
                                context.global.dispatch(NavigateAction.popUntilRoot());
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
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

/// One end of the transfer: device glyph, alias and mono meta line.
class _SendDeviceCard extends StatelessWidget {
  final Device device;
  final String? aliasOverride;
  final String? label;
  final bool highlighted;

  const _SendDeviceCard({
    required this.device,
    this.aliasOverride,
    this.label,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final alias = aliasOverride ?? device.alias;

    return LsCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: highlighted ? colors.accent : colors.bg3,
              borderRadius: BorderRadius.circular(tokens.radiusSm),
            ),
            child: Icon(
              device.deviceType.icon,
              size: 18,
              color: highlighted ? colors.accentFg : colors.fg,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  alias,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.bodyStrong,
                ),
                const SizedBox(height: 2),
                Text(
                  label ?? '${device.deviceModel ?? device.deviceType.name} · ${device.ip}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.mono,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
