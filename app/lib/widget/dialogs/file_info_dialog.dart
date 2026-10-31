import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/transfer_history_session.dart';
import 'package:localsend_app/util/system_date_time_formatter.dart';
import 'package:localsend_app/widget/ls/ls_buttons.dart';
import 'package:localsend_app/widget/ls/ls_dialog.dart';
import 'package:localsend_isolates/util/file_size_helper.dart';
import 'package:routerino/routerino.dart';

class FileInfoDialog extends StatelessWidget {
  final TransferHistoryFile file;
  final TransferHistorySession session;

  const FileInfoDialog({required this.file, required this.session, super.key});

  @override
  Widget build(BuildContext context) {
    final time = file.modified ?? session.timestamp;
    return LsDialog(
      maxWidth: 480,
      title: Text(t.dialogs.fileInfo.title),
      content: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Table(
                columnWidths: const {
                  0: IntrinsicColumnWidth(),
                  1: IntrinsicColumnWidth(),
                  2: IntrinsicColumnWidth(),
                },
                children: [
                  if (!file.isMessage) ...[
                    TableRow(
                      children: [
                        Text(t.dialogs.fileInfo.fileName, maxLines: 1),
                        const SizedBox(width: 10),
                        SelectableText(file.fileName),
                      ],
                    ),
                    TableRow(
                      children: [
                        Text(t.dialogs.fileInfo.path),
                        const SizedBox(width: 10),
                        SelectableText(file.savedToGallery ? t.progressPage.savedToGallery : (file.path ?? '')),
                      ],
                    ),
                  ],
                  TableRow(
                    children: [
                      Text(t.dialogs.fileInfo.size),
                      const SizedBox(width: 10),
                      SelectableText(file.fileSize.asReadableFileSize),
                    ],
                  ),
                  TableRow(
                    children: [
                      Text(session.isSend ? t.dialogs.fileInfo.receiver : t.dialogs.fileInfo.sender),
                      const SizedBox(width: 10),
                      SelectableText(session.peerAlias),
                    ],
                  ),
                  TableRow(
                    children: [
                      Text(t.dialogs.fileInfo.time),
                      const SizedBox(width: 10),
                      SelectableText(SystemDateTimeFormatter.dateTime(context, time.toLocal())),
                    ],
                  ),
                ],
              ),
              if (file.isMessage)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SelectableText(file.fileName),
                ),
            ],
          ),
        ),
      ),
      actions: [
        LsButton(
          label: t.general.close,
          onPressed: () => context.pop(),
        ),
      ],
    );
  }
}
