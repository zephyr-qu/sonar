import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/pages/receive_page.dart';
import 'package:sonar/provider/network/server/server_provider.dart';
import 'package:sonar/provider/selection/selected_receiving_files_provider.dart';
import 'package:sonar/util/file_type_ext.dart';
import 'package:sonar/util/native/pick_directory_path.dart';
import 'package:sonar/util/native/platform_check.dart';
import 'package:sonar/widget/dialogs/file_name_input_dialog.dart';
import 'package:sonar/widget/dialogs/quick_actions_dialog.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_card.dart';
import 'package:sonar/widget/ls/ls_chip.dart';
import 'package:sonar/widget/ls/ls_header.dart';
import 'package:sonar/widget/ls/ls_section_label.dart';
import 'package:sonar/widget/ls/ls_switch.dart';
import 'package:sonar/widget/ls/ls_tile.dart';
import 'package:sonar_isolates/model/dto/file_dto.dart';
import 'package:sonar_isolates/util/file_size_helper.dart';

class ReceiveOptionsPage extends StatelessWidget {
  final ReceivePageVm vm;

  const ReceiveOptionsPage(this.vm);

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final tokens = context.ls;
    final receiveSession = ref.watch(serverProvider.select((s) => s?.session));
    if (receiveSession == null) {
      // The session can disappear while this page is open (the sender cancels, or the
      // transfer completes); a blank scaffold would strand the user there.
      return const _SessionGonePage();
    }
    final selectState = ref.watch(selectedReceivingFilesProvider);
    final destination = checkPlatformWithFileSystem() ? receiveSession.destinationDirectory : t.receiveOptionsPage.appDirectory;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LsSubHeader(
              title: t.receiveOptionsPage.title,
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
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(tokens.pad, 2, tokens.pad, 20),
                    children: [
                      LsSectionLabel(label: t.receiveOptionsPage.destination),
                      LsCard(
                        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    destination,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tokens.bodySm.copyWith(color: tokens.colors.fg),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    checkPlatformWithFileSystem() ? t.receiveOptionsPage.destination : t.receiveOptionsPage.appDirectory,
                                    style: tokens.monoSm,
                                  ),
                                ],
                              ),
                            ),
                            if (checkPlatformWithFileSystem())
                              LsIconButton(
                                icon: LucideIcons.pencil,
                                tooltip: t.receiveRequestPage.change,
                                onPressed: () async {
                                  final directory = await pickDirectoryPath();
                                  if (directory != null) {
                                    ref.notifier(serverProvider).setSessionDestinationDir(directory);
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                      if (checkPlatformWithGallery()) ...[
                        const SizedBox(height: 6),
                        LsCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(t.receiveOptionsPage.saveToGallery, style: tokens.bodySm.copyWith(color: tokens.colors.fg)),
                              ),
                              LsSwitch(
                                value: receiveSession.saveToGallery,
                                label: t.receiveOptionsPage.saveToGallery,
                                onChanged: (value) => ref.notifier(serverProvider).setSessionSaveToGallery(value),
                              ),
                            ],
                          ),
                        ),
                        if (receiveSession.containsDirectories && !receiveSession.saveToGallery)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(t.receiveOptionsPage.saveToGalleryOff, style: tokens.bodySm.copyWith(color: tokens.colors.danger)),
                          ),
                      ],
                      LsSectionLabel(
                        label: t.general.files,
                        count: '${selectState.length}/${vm.files.length}',
                      ),
                      Row(
                        children: [
                          LsChip.text(
                            t.dialogs.quickActions.title,
                            onTap: () async => showDialog(context: context, builder: (_) => const QuickActionsDialog()),
                          ),
                          const SizedBox(width: 8),
                          LsChip.text(
                            t.general.reset,
                            onTap: () => ref.notifier(selectedReceivingFilesProvider).setFiles(vm.files),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LsCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        child: Column(
                          children: [
                            for (var index = 0; index < vm.files.length; index++)
                              _ReceiveFileRow(
                                file: vm.files[index],
                                desiredName: selectState[vm.files[index].id],
                                showDivider: index > 0,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiveFileRow extends StatelessWidget {
  final FileDto file;
  final String? desiredName;
  final bool showDivider;

  const _ReceiveFileRow({required this.file, required this.desiredName, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final selected = desiredName != null;
    final status = !selected ? t.general.skipped : (desiredName == file.fileName ? t.general.unchanged : t.general.renamed);

    return LsFileRow(
      kind: fileKind(file.fileName),
      leadingIcon: file.fileType.icon,
      name: desiredName ?? file.fileName,
      meta: '$status  ${file.size.asReadableFileSize}',
      showDivider: showDivider,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LsIconButton(
            icon: LucideIcons.pencil,
            tooltip: t.general.edit,
            onPressed: !selected
                ? null
                : () async {
                    final result = await showDialog<String>(
                      context: context,
                      builder: (_) => FileNameInputDialog(originalName: file.fileName, initialName: desiredName!),
                    );
                    if (result != null) {
                      ref.notifier(selectedReceivingFilesProvider).rename(file.id, result);
                    }
                  },
          ),
          const SizedBox(width: 4),
          LsSwitch(
            value: selected,
            label: file.fileName,
            onChanged: (value) {
              if (value) {
                ref.notifier(selectedReceivingFilesProvider).select(file);
              } else {
                ref.notifier(selectedReceivingFilesProvider).unselect(file.id);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Shown when the receive session disappears while [ReceiveOptionsPage] is open.
///
/// It closes itself so the user lands back on the receive page, which already explains what
/// happened to the session. The button is the fallback for the frame before the pop lands and
/// for the case where this page was not pushed.
class _SessionGonePage extends StatefulWidget {
  const _SessionGonePage();

  @override
  State<_SessionGonePage> createState() => _SessionGonePageState();
}

class _SessionGonePageState extends State<_SessionGonePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && Navigator.of(context).canPop()) {
        await Navigator.of(context).maybePop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LsSubHeader(
              title: t.receiveOptionsPage.title,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Center(
                child: LsButton(
                  label: t.general.close,
                  variant: LsButtonVariant.ghost,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
