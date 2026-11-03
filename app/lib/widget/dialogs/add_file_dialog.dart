import 'package:flutter/material.dart';
import 'package:refena_flutter/addons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/util/native/file_picker.dart';
import 'package:sonar/util/native/platform_check.dart';
import 'package:sonar/widget/big_button.dart';
import 'package:sonar/widget/dialogs/custom_bottom_sheet.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';
import 'package:sonar/widget/responsive_builder.dart';

class AddFileDialog extends StatelessWidget {
  final List<FilePickerOption> options;

  const AddFileDialog({required this.options});

  static Future<void> open({required BuildContext context, required List<FilePickerOption> options}) async {
    if (checkPlatformIsDesktop()) {
      await showDialog(
        context: context,
        builder: (_) => LsDialog(
          title: Text(t.dialogs.addFile.title),
          // Wide enough for four buttons of 100 plus their spacing: the four desktop
          // options then sit in one row instead of a 3 + 1 block.
          maxWidth: 500,
          content: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.dialogs.addFile.content),
                const SizedBox(height: 20),
                AddFileDialog(options: options),
              ],
            ),
          ),
          actions: [
            LsButton(
              label: t.general.close,
              onPressed: () {
                context.pop();
              },
            ),
          ],
        ),
      );
    } else {
      await context.pushBottomSheet(
        () => CustomBottomSheet(
          title: t.dialogs.addFile.title,
          description: t.dialogs.addFile.content,
          child: AddFileDialog(options: options),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const spacing = 15.0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final buttonWidth = SizingInformation(screenWidth).isDesktop ? BigButton.desktopWidth : BigButton.mobileWidth;

    // Four or fewer options fit a single row. More read better as full rows of three
    // than as a full row plus a stray button: six in two rows of four would leave a
    // lopsided 4 + 2 block, and two per row stacks three rows into a narrow column.
    final preferredColumns = options.length <= 4 ? options.length : 3;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Narrow sheets (a small phone, or a dialog clamped by its inset padding) get
        // fewer columns rather than an overflowing row.
        final available = constraints.maxWidth.isFinite ? constraints.maxWidth : screenWidth;
        final columns = ((available + spacing) / (buttonWidth + spacing)).floor().clamp(1, preferredColumns).toInt();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var start = 0; start < options.length; start += columns) ...[
              if (start > 0) const SizedBox(height: spacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = start; index < start + columns && index < options.length; index++) ...[
                    if (index > start) const SizedBox(width: spacing),
                    BigButton(
                      icon: options[index].icon,
                      label: options[index].label,
                      filled: true,
                      width: buttonWidth,
                      onTap: () async {
                        final ref = context.ref;
                        await ref.global.dispatchAsync(PickFileAction(option: options[index], context: context));
                        ref.global.dispatch(NavigateAction.popUntilRoot());
                      },
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
