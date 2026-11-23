import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/pages/debug/discovery_debug_page.dart';
import 'package:sonar/pages/debug/http_logs_page.dart';
import 'package:sonar/pages/debug/security_debug_page.dart';
import 'package:sonar/pages/debug/troubleshoot_section.dart';
import 'package:sonar/provider/app_arguments_provider.dart';
import 'package:sonar/provider/persistence_provider.dart';
import 'package:sonar/util/shared_preferences/shared_preferences_file.dart';
import 'package:sonar/widget/debug_entry.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_scaffold.dart';
import 'package:sonar/widget/ls/ls_section_label.dart';

class DebugPage extends StatelessWidget {
  const DebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final appArguments = context.watch(appArgumentsProvider);
    final portableMode = context.watch(persistenceProvider.select((state) => state.isPortableMode()));
    final store = SharedPreferencesStorePlatform.instance;

    return LsPageScaffold(
      title: 'Debugging',
      body: ListView(
        padding: EdgeInsets.fromLTRB(tokens.pad, 6, tokens.pad, 32),
        children: [
          DebugEntry(
            name: 'Debug Mode',
            value: kDebugMode.toString(),
          ),
          DebugEntry(
            name: 'Portable Mode',
            value: portableMode ? 'true' : 'false',
          ),
          DebugEntry(
            name: 'Executable Path',
            value: Platform.resolvedExecutable,
          ),
          DebugEntry(
            name: 'Working Directory',
            value: Directory.current.path,
          ),
          if (store is SharedPreferencesFile)
            DebugEntry(
              name: 'Settings Path',
              value: store.getPath(),
            ),
          DebugEntry(
            name: 'App Arguments',
            value: appArguments.isEmpty ? null : appArguments.map((e) => '"$e"').join(' '),
          ),
          DebugEntry(
            name: 'Dart SDK',
            value: Platform.version,
          ),
          const TroubleshootSection(),
          const LsSectionLabel(label: 'Pages'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              LsButton(
                label: 'Security',
                icon: LucideIcons.shield,
                variant: LsButtonVariant.ghost,
                compact: true,
                onPressed: () => context.push(() => const SecurityDebugPage()),
              ),
              LsButton(
                label: 'Discovery',
                icon: LucideIcons.radar,
                variant: LsButtonVariant.ghost,
                compact: true,
                onPressed: () => context.push(() => const DiscoveryDebugPage()),
              ),
              LsButton(
                label: 'HTTP Logs',
                icon: LucideIcons.globe,
                variant: LsButtonVariant.ghost,
                compact: true,
                onPressed: () => context.push(() => const HttpLogsPage()),
              ),
              if (kDebugMode)
                LsButton(
                  label: 'Refena Tracing',
                  icon: LucideIcons.activity,
                  variant: LsButtonVariant.ghost,
                  compact: true,
                  onPressed: () => context.push(() => const RefenaTracingPage()),
                ),
              LsButton(
                label: 'Clear settings',
                icon: LucideIcons.trash2,
                variant: LsButtonVariant.ghost,
                compact: true,
                onPressed: () => context.ref.read(persistenceProvider).clear(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
