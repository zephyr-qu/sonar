import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/provider/logging/discovery_logs_provider.dart';
import 'package:sonar/provider/network/nearby_devices_provider.dart';
import 'package:sonar/util/ui/snackbar.dart';
import 'package:sonar/widget/copyable_text.dart';
import 'package:sonar/widget/ls/ls_scaffold.dart';
import 'package:sonar/widget/responsive_list_view.dart';

final _dateFormat = DateFormat.Hms();

class DiscoveryDebugPage extends StatelessWidget {
  const DiscoveryDebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final logs = ref.watch(discoveryLoggerProvider);
    return LsPageScaffold(
      title: 'Discovery Debugging',
      actions: [
        IconButton(
          tooltip: 'Copy all logs',
          icon: const Icon(LucideIcons.copy),
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
                      context.showSnackBar('Copied discovery logs to clipboard');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      context.showSnackBar('Failed to copy logs: $e');
                    }
                  }
                },
        ),
      ],
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        children: [
          Row(
            children: [
              ElevatedButton(
                onPressed: () => ref.redux(nearbyDevicesProvider).dispatch(StartMulticastScan()),
                child: const Text('Announce'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: () => ref.notifier(discoveryLoggerProvider).clear(),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...logs.map(
            (log) => CopyableText(
              prefix: TextSpan(
                text: '[${_dateFormat.format(log.timestamp)}] ',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
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
