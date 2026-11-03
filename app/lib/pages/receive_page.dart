import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/addons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/pages/receive_options_page.dart';
import 'package:sonar/pages/verify_page.dart';
import 'package:sonar/pages/web_share_page.dart';
import 'package:sonar/provider/favorites_provider.dart';
import 'package:sonar/provider/selection/selected_receiving_files_provider.dart';
import 'package:sonar/provider/settings_provider.dart';
import 'package:sonar/util/device_type_ext.dart';
import 'package:sonar/util/favorites.dart';
import 'package:sonar/util/native/platform_check.dart';
import 'package:sonar/util/native/taskbar_helper.dart';
import 'package:sonar/util/ui/snackbar.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_card.dart';
import 'package:sonar/widget/ls/ls_chip.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';
import 'package:sonar/widget/ls/ls_tile.dart';
import 'package:sonar_isolates/model/device.dart';
import 'package:sonar_isolates/model/dto/file_dto.dart';
import 'package:sonar_isolates/model/session_status.dart';
import 'package:sonar_isolates/util/file_size_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class ReceivePageVm {
  final SessionStatus? status;
  final Device sender;

  /// Show verify button and device model.
  final bool showSenderInfo;
  final List<FileDto> files;
  final String? message;
  final bool isLink;
  final void Function() onAccept;
  final void Function() onDecline;
  final void Function() onClose;

  ReceivePageVm({
    required this.status,
    required this.sender,
    required this.showSenderInfo,
    required this.files,
    required this.message,
    required this.onAccept,
    required this.onDecline,
    required this.onClose,
  }) : isLink = message != null && !message.trim().contains(RegExp(r'\s')) && (Uri.tryParse(message.trim())?.isAbsolute ?? false);
}

/// Shows an incoming request (or message) as a modal dialog over the shell.
///
/// A request is an interruption that asks for one decision, not a screen to
/// navigate to. Pushing a full-window page covered the rail, the window header
/// and the visibility switch, so the user could no longer see that this device
/// is still reachable — and the accept/reject row sat at the bottom of a
/// scrollable 600px column, far below the summary it belongs to.
Future<void> showReceiveRequestDialog(ViewProvider<ReceivePageVm> vm) {
  final navigator = Routerino.navigatorKey.currentState;
  if (navigator == null) {
    return Future<void>.value();
  }
  return navigator.push<void>(
    DialogRoute<void>(
      context: navigator.context,
      // A request is answered by accept or reject, never by clicking beside the
      // dialog: an accidental outside click must not decline a transfer.
      barrierDismissible: false,
      builder: (_) => ReceiveRequestDialog(vm),
    ),
  );
}

class ReceiveRequestDialog extends StatefulWidget {
  final ViewProvider<ReceivePageVm> vm;

  const ReceiveRequestDialog(this.vm);

  @override
  State<ReceiveRequestDialog> createState() => _ReceiveRequestDialogState();
}

class _ReceiveRequestDialogState extends State<ReceiveRequestDialog> with Refena {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch(
      widget.vm,
      listener: (prev, next) {
        if (prev.status != next.status) {
          // ignore: discarded_futures
          TaskbarHelper.visualizeStatus(next.status);
        }
      },
    );

    if (vm.status == null && vm.message == null) {
      // The session ended while the dialog was open (it was closed elsewhere, or
      // the state was cleared): an empty dialog would just hang over the shell.
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

    return ViewModelBuilder(
      provider: (ref) => widget.vm,
      dispose: (ref) {
        ref.dispose(widget.vm);
        unawaited(TaskbarHelper.clearProgressBar());
      },
      builder: (context, _) => _dialog(context, vm),
    );
  }

  Widget _dialog(BuildContext context, ReceivePageVm vm) {
    final senderFavoriteEntry = ref.watch(favoritesProvider.select((state) => state.findDevice(vm.sender)));
    final alias = senderFavoriteEntry?.alias ?? vm.sender.alias;
    final isMessage = vm.message != null;
    final canceled = vm.status == SessionStatus.canceledBySender;

    final title = isMessage ? (vm.isLink ? t.receivePage.subTitleLink : t.receivePage.subTitleMessage) : t.receiveRequestPage.title;

    final List<Widget> actions;
    if (isMessage || canceled) {
      actions = [
        LsButton(
          label: t.general.close,
          icon: LucideIcons.x,
          variant: LsButtonVariant.ghost,
          onPressed: () => _dismiss(context, vm),
        ),
      ];
    } else {
      final selectedFiles = context.watch(selectedReceivingFilesProvider);
      actions = [
        LsButton(
          label: t.receiveRequestPage.reject,
          variant: LsButtonVariant.ghost,
          onPressed: () => _dismiss(context, vm),
        ),
        LsButton(
          label: t.receiveRequestPage.accept,
          icon: LucideIcons.download,
          onPressed: selectedFiles.isEmpty ? null : () => vm.onAccept(),
        ),
      ];
    }

    return PopScope(
      // Back must go through [_dismiss]: popping the dialog silently would leave
      // the session pending with no route back to it.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _dismiss(context, vm);
        }
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) => _onKeyEvent(context, node, event, vm),
        child: LsDialog(
          title: Text(title),
          maxWidth: 460,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: isMessage
                ? _messageContent(context, vm: vm, alias: alias)
                : _requestContent(context, vm: vm, alias: alias, isFavorite: senderFavoriteEntry != null),
          ),
          actions: actions,
        ),
      ),
    );
  }

  List<Widget> _requestContent(BuildContext context, {required ReceivePageVm vm, required String alias, required bool isFavorite}) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final settings = context.watch(settingsProvider);
    final totalSize = vm.files.fold<int>(0, (sum, file) => sum + file.size);
    final destination = context.watch(settingsProvider.select((state) => state.destination)) ?? t.settingsTab.receive.downloads;

    return [
      _senderBlock(context, vm, alias),
      const SizedBox(height: 12),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          LsChip.text(t.receiveRequestPage.filesCount(n: vm.files.length)),
          LsChip.text(totalSize.asReadableFileSize),
          LsChip.text(
            vm.sender.https ? t.receiveRequestPage.secure : t.receiveRequestPage.plain,
            accent: vm.sender.https,
          ),
        ],
      ),
      const SizedBox(height: 12),
      _fileList(context, vm),
      const SizedBox(height: 12),
      _destinationRow(context, vm, destination),
      const SizedBox(height: 10),
      Text(
        _policyText(quickSave: settings.quickSave, quickSaveFromFavorites: settings.quickSaveFromFavorites, isFavorite: isFavorite),
        style: tokens.monoSm.copyWith(color: colors.faint),
      ),
    ];
  }

  List<Widget> _messageContent(BuildContext context, {required ReceivePageVm vm, required String alias}) {
    return [
      _senderBlock(context, vm, alias),
      const SizedBox(height: 12),
      LsCard(
        padding: const EdgeInsets.all(12),
        // Long messages scroll inside the card instead of stretching the dialog.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: SingleChildScrollView(child: SelectableText(vm.message!)),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          LsButton(
            label: t.general.copy,
            icon: LucideIcons.copy,
            variant: LsButtonVariant.ghost,
            compact: true,
            onPressed: () {
              unawaited(Clipboard.setData(ClipboardData(text: vm.message!)));
              if (checkPlatformIsDesktop()) {
                context.showSnackBar(t.general.copiedToClipboard);
              }
              vm.onAccept();
              context.global.dispatch(NavigateAction.popUntil<WebSharePage>());
            },
          ),
          if (vm.isLink)
            LsButton(
              label: t.general.open,
              icon: LucideIcons.externalLink,
              compact: true,
              onPressed: () {
                // ignore: discarded_futures
                launchUrl(Uri.parse(vm.message!), mode: LaunchMode.externalApplication);
                vm.onAccept();
                context.global.dispatch(NavigateAction.popUntil<WebSharePage>());
              },
            ),
        ],
      ),
    ];
  }

  /// Sender identity: alias, device model + address and the certificate
  /// fingerprint in one block.
  ///
  /// The fingerprint used to live in a separate "connection" card together with
  /// the channel, while the header repeated the same channel as a chip; that is
  /// three rows of a dialog saying one thing.
  Widget _senderBlock(BuildContext context, ReceivePageVm vm, String alias) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final meta = [
      if (vm.sender.deviceModel != null) vm.sender.deviceModel!,
      if (vm.sender.ip != null) vm.sender.ip!,
    ].join('  ');
    final fingerprint = vm.sender.fingerprint;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: colors.bg3, borderRadius: BorderRadius.circular(tokens.radiusSm)),
          child: Icon(vm.sender.deviceType.icon, size: 20, color: colors.fg),
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
                    _shortFingerprint(fingerprint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.monoSm.copyWith(color: colors.faint),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Verification belongs to the identity it checks: on the sender row,
        // next to the fingerprint it compares, not below the destination where
        // it read as a step of the accept/reject decision.
        if (vm.showSenderInfo) ...[
          const SizedBox(width: 8),
          LsButton(
            label: t.verifyPage.title,
            icon: LucideIcons.badgeCheck,
            variant: LsButtonVariant.ghost,
            compact: true,
            // Without https there is no peer certificate to compare.
            onPressed: !vm.sender.https
                ? null
                : () async => context.push(
                    () => VerifyPage(
                      fingerprint: CombinedFingerprint.load(context, vm.sender.fingerprint),
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  /// The file list keeps its own scroll area so a request with hundreds of files
  /// cannot grow the dialog past the window; the action row stays in the footer.
  ///
  /// The rows are built lazily: a single request may carry thousands of files
  /// (`MAX_FILES_PER_SESSION` in the server is 10_000), and a `Column` would
  /// mount every one of them up front. `shrinkWrap` still only lays out until
  /// the 240px viewport is full, so the card keeps its natural height for the
  /// usual handful of files.
  Widget _fileList(BuildContext context, ReceivePageVm vm) {
    final files = vm.files;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: LsCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ListView.builder(
          primary: false,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            return LsFileRow(kind: _kindOf(file), name: file.fileName, meta: file.size.asReadableFileSize);
          },
        ),
      ),
    );
  }

  Widget _destinationRow(BuildContext context, ReceivePageVm vm, String destination) {
    final tokens = context.ls;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.receiveRequestPage.saveTo, style: tokens.label),
              const SizedBox(height: 2),
              Text(destination, maxLines: 1, overflow: TextOverflow.ellipsis, style: tokens.body),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // The single entry to the receive options: the page used to offer
        // "change" next to the destination and a second button further down.
        LsButton(
          label: t.receiveRequestPage.change,
          variant: LsButtonVariant.ghost,
          compact: true,
          onPressed: () async => context.push(() => ReceiveOptionsPage(vm)),
        ),
      ],
    );
  }

  /// Closes the dialog and applies the decision matching what is on screen.
  void _dismiss(BuildContext context, ReceivePageVm vm) {
    if (vm.message != null) {
      vm.onAccept();
    } else if (vm.status == SessionStatus.canceledBySender) {
      vm.onClose();
    } else {
      vm.onDecline();
    }
    context.global.dispatch(NavigateAction.popUntil<WebSharePage>());
  }

  KeyEventResult _onKeyEvent(BuildContext context, FocusNode node, KeyEvent event, ReceivePageVm vm) {
    final keyboard = HardwareKeyboard.instance;
    if (event is! KeyDownEvent || keyboard.isControlPressed || keyboard.isShiftPressed || keyboard.isAltPressed || keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        _dismiss(context, vm);
        return KeyEventResult.handled;
      // Only while no button is focused, so that Enter still activates the focused button.
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter when node.hasPrimaryFocus:
        if (vm.message != null || vm.status == SessionStatus.canceledBySender) {
          return KeyEventResult.ignored;
        }
        if (context.read(selectedReceivingFilesProvider).isNotEmpty) {
          vm.onAccept();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  String _shortFingerprint(String fingerprint) {
    return fingerprint.length > 12 ? '${fingerprint.substring(0, 6)}…${fingerprint.substring(fingerprint.length - 4)}' : fingerprint;
  }

  /// Mirrors the receive policy line of the redesign header.
  String _policyText({required bool quickSave, required bool quickSaveFromFavorites, required bool isFavorite}) {
    if (quickSave) {
      return t.receiveRequestPage.policyQuickSave;
    }
    if (quickSaveFromFavorites && isFavorite) {
      return t.receiveRequestPage.policyQuickSaveFavorites;
    }
    return t.receiveRequestPage.policyAsk;
  }

  String _kindOf(FileDto file) {
    final dot = file.fileName.lastIndexOf('.');
    if (dot == -1 || dot == file.fileName.length - 1) {
      return 'FILE';
    }
    final kind = file.fileName.substring(dot + 1).toUpperCase();
    return kind.length > 4 ? kind.substring(0, 4) : kind;
  }
}
