import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:routerino/routerino.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/util/native/channel/android_channel.dart' as android_channel;
import 'package:sonar/util/native/open_file.dart';
import 'package:sonar/util/native/open_folder.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';
import 'package:sonar_isolates/model/file_type.dart';

/// Asks whether the file that just arrived should be opened.
///
/// This used to count down and pop itself after five seconds. A question that
/// answers itself before the user has read it is worse than one that waits, so
/// the dialog now stays until it is answered or dismissed.
class OpenFileDialog extends StatelessWidget {
  final String filePath;
  final FileType fileType;
  final bool openGallery;

  const OpenFileDialog({
    super.key,
    required this.filePath,
    required this.fileType,
    required this.openGallery,
  });

  static Future<void> open(
    BuildContext context, {
    required String filePath,
    required FileType fileType,
    required bool openGallery,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => OpenFileDialog(
        filePath: filePath,
        fileType: fileType,
        openGallery: openGallery,
      ),
    );
  }

  /// Mobile platforms cannot select the file in a file manager, so the action opens the file manager instead.
  bool get _isMobile => defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    return LsDialog(
      title: Text(t.dialogs.openFile.title),
      content: Text(t.dialogs.openFile.content),
      actions: [
        if (!openGallery)
          LsButton(
            label: _isMobile ? t.dialogs.openFile.openFileManager : t.receiveHistoryPage.entryActions.showInFolder,
            variant: LsButtonVariant.ghost,
            compact: true,
            onPressed: () async => await openFolder(
              folderPath: File(filePath).parent.path,
              fileName: path.basename(filePath),
            ),
          ),
        LsButton(
          label: t.general.close,
          variant: LsButtonVariant.ghost,
          compact: true,
          onPressed: () => context.pop(),
        ),
        LsButton(
          label: t.general.open,
          compact: true,
          onPressed: () async {
            if (openGallery && defaultTargetPlatform == TargetPlatform.android) {
              await android_channel.openGallery();
            } else {
              await openFile(context, fileType, filePath);
            }
            // The dialog asked a question that is now answered, so it does not stay up
            // behind the opened file.
            if (context.mounted) {
              context.pop();
            }
          },
        ),
      ],
    );
  }
}
