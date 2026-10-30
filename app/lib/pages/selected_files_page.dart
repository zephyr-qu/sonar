import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/native/open_file.dart';
import 'package:localsend_app/util/ui/nav_bar_padding.dart';
import 'package:localsend_app/widget/dialogs/message_input_dialog.dart';
import 'package:localsend_app/widget/ls/ls_buttons.dart';
import 'package:localsend_app/widget/ls/ls_card.dart';
import 'package:localsend_app/widget/ls/ls_header.dart';
import 'package:localsend_app/widget/ls/ls_section_label.dart';
import 'package:localsend_app/widget/ls/ls_tile.dart';
import 'package:localsend_isolates/model/file_type.dart';
import 'package:localsend_isolates/util/file_size_helper.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class SelectedFilesPage extends StatelessWidget {
  const SelectedFilesPage();

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final selectedFiles = ref.watch(selectedSendingFilesProvider);
    final totalSize = selectedFiles.fold<int>(0, (prev, curr) => prev + curr.size);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LsSubHeader(
              title: t.selectedFilesPage.title,
              subtitle: Text(
                '${t.sendTab.selection.files(files: selectedFiles.length)} · ${totalSize.asReadableFileSize}',
                style: context.ls.monoSm,
              ),
              onBack: () => Navigator.of(context).maybePop(),
              actions: [
                if (selectedFiles.isNotEmpty)
                  LsButton(
                    label: t.selectedFilesPage.deleteAll,
                    variant: LsButtonVariant.ghost,
                    onPressed: () {
                      ref.redux(selectedSendingFilesProvider).dispatch(ClearSelectionAction());
                      context.popUntilRoot();
                    },
                  ),
              ],
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: selectedFiles.isEmpty
                      ? Center(child: Text(t.nearbyTab.filesEmpty, style: context.ls.bodySm))
                      : ListView(
                          padding: EdgeInsets.fromLTRB(context.ls.pad, 4, context.ls.pad, 16 + getNavBarPadding(context)),
                          children: [
                            LsSectionLabel(label: t.general.files, count: totalSize.asReadableFileSize),
                            LsCard(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              child: Column(
                                children: [
                                  for (var index = 0; index < selectedFiles.length; index++)
                                    _FileRow(
                                      file: selectedFiles[index],
                                      index: index,
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

class _FileRow extends StatelessWidget {
  final CrossFile file;
  final int index;
  final bool showDivider;

  const _FileRow({required this.file, required this.index, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final isText = file.fileType == FileType.text && file.bytes != null;
    final name = isText ? '"${file.displayName.replaceAll('\n', ' ')}"' : file.name;

    return InkWell(
      onTap: file.path != null
          ? () async {
              await openFile(context, file.fileType, file.path!);
            }
          : null,
      child: LsFileRow(
        kind: _kindOf(file.name),
        name: name,
        meta: file.size.asReadableFileSize,
        showDivider: showDivider,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isText)
              LsIconButton(
                icon: LucideIcons.pencil,
                tooltip: t.general.edit,
                onPressed: () async {
                  final result = await showDialog<String>(
                    context: context,
                    builder: (_) => MessageInputDialog(initialText: file.displayName),
                  );
                  if (result != null) {
                    ref.redux(selectedSendingFilesProvider).dispatch(UpdateMessageAction(message: result, index: index));
                  }
                },
              ),
            LsIconButton(
              icon: LucideIcons.x,
              tooltip: t.general.delete,
              onPressed: () {
                final currCount = ref.read(selectedSendingFilesProvider).length;
                ref.redux(selectedSendingFilesProvider).dispatch(RemoveSelectedFileAction(index));
                if (currCount == 1) {
                  context.popUntilRoot();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _kindOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) {
      return 'FILE';
    }
    final kind = name.substring(dot + 1).toUpperCase();
    return kind.length > 4 ? kind.substring(0, 4) : kind;
  }
}
