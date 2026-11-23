import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/provider/logging/http_logs_provider.dart';
import 'package:sonar/util/ui/snackbar.dart';
import 'package:sonar/widget/copyable_text.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_scaffold.dart';

final _dateFormat = DateFormat.Hms();

/// Log lines are meant to be copied, not read on screen, so the page runs wide.
const _logPageWidth = 760.0;

class HttpLogsPage extends StatelessWidget {
  const HttpLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final ref = context.ref;
    final logs = ref.watch(httpLogsProvider);

    return LsPageScaffold(
      title: 'HTTP Logs',
      maxWidth: _logPageWidth,
      actions: [
        LsIconButton(
          tooltip: 'Copy all logs',
          icon: LucideIcons.copy,
          onPressed: logs.isEmpty
              ? null
              : () async {
                  try {
                    await Clipboard.setData(
                      ClipboardData(
                        text: logs.map((log) => '[${_dateFormat.format(log.timestamp)}] ${log.log}').join('\n'),
                      ),
                    );
                    if (context.mounted) {
                      context.showSnackBar('Copied HTTP logs to clipboard');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      context.showSnackBar('Failed to copy logs: $e');
                    }
                  }
                },
        ),
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(tokens.pad, 8, tokens.pad, 32),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              LsButton(
                label: 'Clear',
                icon: LucideIcons.trash2,
                variant: LsButtonVariant.ghost,
                compact: true,
                onPressed: () => ref.notifier(httpLogsProvider).clear(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...logs.map(
            (log) => CopyableText(
              prefix: TextSpan(
                text: '[${_dateFormat.format(log.timestamp)}] ',
                style: TextStyle(color: tokens.colors.accent, fontWeight: FontWeight.w700),
              ),
              name: log.log,
              value: log.log,
            ),
          ),
        ],
      ),
    );
  }
}
