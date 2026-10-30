import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/receive_options_page.dart';
import 'package:localsend_app/pages/verify_page.dart';
import 'package:localsend_app/pages/web_share_page.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/selection/selected_receiving_files_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/native/taskbar_helper.dart';
import 'package:localsend_app/util/ui/snackbar.dart';
import 'package:localsend_app/widget/ls/ls_buttons.dart';
import 'package:localsend_app/widget/ls/ls_card.dart';
import 'package:localsend_app/widget/ls/ls_chip.dart';
import 'package:localsend_app/widget/ls/ls_header.dart';
import 'package:localsend_app/widget/ls/ls_section_label.dart';
import 'package:localsend_app/widget/ls/ls_tile.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/dto/file_dto.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:localsend_isolates/util/file_size_helper.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/addons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
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

class ReceivePage extends StatefulWidget {
  final ViewProvider<ReceivePageVm> vm;

  const ReceivePage(this.vm);

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> with Refena {
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
      return const Scaffold(body: SizedBox());
    }

    final senderFavoriteEntry = ref.watch(favoritesProvider.select((state) => state.findDevice(vm.sender)));
    final settings = ref.watch(settingsProvider);

    return ViewModelBuilder(
      provider: (ref) => widget.vm,
      dispose: (ref) {
        ref.dispose(widget.vm);
        unawaited(TaskbarHelper.clearProgressBar());
      },
      builder: (context, vm) {
        final tokens = context.ls;
        final alias = senderFavoriteEntry?.alias ?? vm.sender.alias;
        final smallUi = vm.message != null && MediaQuery.sizeOf(context).height < 600;

        return PopScope(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              vm.onDecline();
            }
          },
          canPop: true,
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  LsSubHeader(
                    title: vm.message != null ? (vm.isLink ? t.receivePage.subTitleLink : t.receivePage.subTitleMessage) : t.receiveRequestPage.title,
                    // Sender identity in the header, receive policy in the footer hint
                    // (prototype: "快速保存：…" lives above the action bar).
                    subtitle: Text(
                      [if (vm.showSenderInfo) alias, if (vm.showSenderInfo) _channelLabel(vm)].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.monoSm,
                    ),
                    onBack: () => Navigator.of(context).maybePop(),
                    actions: [
                      LsChip.text(
                        vm.sender.https ? t.receiveRequestPage.secure : t.receiveRequestPage.plain,
                        accent: vm.sender.https,
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(tokens.pad, 0, tokens.pad, 16),
                          children: vm.message != null
                              ? _messageContent(context, vm: vm, alias: alias, smallUi: smallUi)
                              : _requestContent(context, vm: vm, alias: alias),
                        ),
                      ),
                    ),
                  ),
                  if (vm.message == null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(tokens.pad, 0, tokens.pad, 8),
                      child: Text(
                        _policyText(
                          quickSave: settings.quickSave,
                          quickSaveFromFavorites: settings.quickSaveFromFavorites,
                          isFavorite: senderFavoriteEntry != null,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.monoSm.copyWith(color: tokens.colors.faint),
                      ),
                    ),
                  _Actions(vm),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _channelLabel(ReceivePageVm vm) {
    return vm.sender.https ? t.receiveRequestPage.channelTls : t.receiveRequestPage.channelPlain;
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

  Widget _senderBlock(BuildContext context, ReceivePageVm vm, String alias) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final meta = [
      if (vm.sender.deviceModel != null) vm.sender.deviceModel!,
      if (vm.sender.ip != null) vm.sender.ip!,
      _channelLabel(vm),
    ].join(' · ');

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
              const SizedBox(height: 3),
              Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: tokens.monoSm),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _requestContent(BuildContext context, {required ReceivePageVm vm, required String alias}) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final totalSize = vm.files.fold<int>(0, (sum, file) => sum + file.size);
    final fingerprint = vm.sender.fingerprint;
    final fingerprintShort = fingerprint.length > 12
        ? '${fingerprint.substring(0, 6)}…${fingerprint.substring(fingerprint.length - 4)}'
        : fingerprint;
    final destination = context.watch(settingsProvider.select((state) => state.destination)) ?? t.settingsTab.receive.downloads;

    return [
      const SizedBox(height: 6),
      _senderBlock(context, vm, alias),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          LsChip.text(t.receiveRequestPage.filesCount(n: vm.files.length)),
          LsChip.text(totalSize.asReadableFileSize),
          if (vm.sender.version.isNotEmpty) LsChip.text(t.receiveRequestPage.protocol(version: vm.sender.version)),
        ],
      ),
      const SizedBox(height: 12),
      LsCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          children: [
            for (final file in vm.files) LsFileRow(kind: _kindOf(file), name: file.fileName, meta: file.size.asReadableFileSize),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.receiveRequestPage.saveTo, style: tokens.body),
                const SizedBox(height: 2),
                Text(destination, maxLines: 1, overflow: TextOverflow.ellipsis, style: tokens.bodySm),
              ],
            ),
          ),
          LsButton(
            label: t.receiveRequestPage.change,
            variant: LsButtonVariant.ghost,
            onPressed: () async => context.push(() => ReceiveOptionsPage(vm)),
          ),
        ],
      ),
      LsSectionLabel(label: t.receiveRequestPage.connection, padding: const EdgeInsets.only(top: 6, bottom: 8)),
      LsCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          children: [
            _kvRow(
              context,
              label: t.receiveRequestPage.fingerprint,
              description: t.receiveRequestPage.fingerprintDesc,
              value: fingerprintShort,
            ),
            Divider(color: colors.line, height: 1),
            _kvRow(
              context,
              label: t.receiveRequestPage.channel,
              description: t.receiveRequestPage.sameNetwork,
              value: _channelLabel(vm),
            ),
          ],
        ),
      ),
      if (vm.showSenderInfo) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            LsButton(
              label: t.verifyPage.title,
              icon: LucideIcons.badgeCheck,
              variant: LsButtonVariant.ghost,
              onPressed: !vm.sender.https
                  ? null
                  : () async => context.push(
                      () => VerifyPage(
                        fingerprint: CombinedFingerprint.load(context, vm.sender.fingerprint),
                      ),
                    ),
            ),
            LsButton(
              label: t.receiveOptionsPage.title,
              icon: LucideIcons.slidersHorizontal,
              variant: LsButtonVariant.ghost,
              onPressed: () async => context.push(() => ReceiveOptionsPage(vm)),
            ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _messageContent(BuildContext context, {required ReceivePageVm vm, required String alias, required bool smallUi}) {
    return [
      const SizedBox(height: 6),
      _senderBlock(context, vm, alias),
      const SizedBox(height: 14),
      LsCard(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          height: smallUi ? 80 : 120,
          child: SingleChildScrollView(child: SelectableText(vm.message!)),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (vm.showSenderInfo)
            LsButton(
              label: t.verifyPage.title,
              icon: LucideIcons.badgeCheck,
              variant: LsButtonVariant.ghost,
              onPressed: () async => context.push(
                () => VerifyPage(
                  fingerprint: CombinedFingerprint.load(context, vm.sender.fingerprint),
                ),
              ),
            ),
          LsButton(
            label: t.general.copy,
            icon: LucideIcons.copy,
            variant: LsButtonVariant.ghost,
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

  Widget _kvRow(BuildContext context, {required String label, required String description, required String value}) {
    final tokens = context.ls;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: tokens.body),
                const SizedBox(height: 2),
                Text(description, style: tokens.bodySm),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: tokens.monoSm),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  final ReceivePageVm vm;

  const _Actions(this.vm);

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final selectedFiles = context.watch(selectedReceivingFilesProvider);

    Widget child;
    if (vm.message != null) {
      child = Center(
        child: LsButton(
          label: t.general.close,
          icon: LucideIcons.x,
          variant: LsButtonVariant.ghost,
          onPressed: () {
            vm.onAccept();
            context.global.dispatch(NavigateAction.popUntil<WebSharePage>());
          },
        ),
      );
    } else if (vm.status == SessionStatus.canceledBySender) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              t.receivePage.canceled,
              style: TextStyle(color: tokens.colors.danger),
              textAlign: TextAlign.center,
            ),
          ),
          LsButton(
            label: t.general.close,
            icon: LucideIcons.check,
            variant: LsButtonVariant.ghost,
            onPressed: () {
              vm.onClose();
              context.global.dispatch(NavigateAction.popUntil<WebSharePage>());
            },
          ),
        ],
      );
    } else {
      void decline() {
        vm.onDecline();
        context.global.dispatch(NavigateAction.popUntil<WebSharePage>());
      }

      final onAccept = selectedFiles.isEmpty ? null : vm.onAccept;

      child = Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          final keyboard = HardwareKeyboard.instance;
          if (event is! KeyDownEvent || keyboard.isControlPressed || keyboard.isShiftPressed || keyboard.isAltPressed || keyboard.isMetaPressed) {
            return KeyEventResult.ignored;
          }
          switch (event.logicalKey) {
            case LogicalKeyboardKey.escape:
              decline();
              return KeyEventResult.handled;
            // Only while no button is focused, so that Enter still activates the focused button.
            case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter when node.hasPrimaryFocus:
              onAccept?.call();
              return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Row(
          children: [
            Flexible(
              flex: 4,
              child: LsButton(
                label: t.receiveRequestPage.reject,
                variant: LsButtonVariant.ghost,
                expand: true,
                onPressed: decline,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              flex: 6,
              child: LsButton(
                label: t.receiveRequestPage.acceptFiles(n: vm.files.length),
                icon: LucideIcons.download,
                expand: true,
                onPressed: onAccept,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: tokens.colors.bg,
        border: Border(
          top: BorderSide(color: tokens.colors.line, width: tokens.hairlineOf(context)),
        ),
      ),
      child: child,
    );
  }
}
