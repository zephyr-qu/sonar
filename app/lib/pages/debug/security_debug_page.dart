import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/provider/security_provider.dart';
import 'package:sonar/widget/debug_entry.dart';
import 'package:sonar/widget/ls/ls_scaffold.dart';
import 'package:sonar/widget/responsive_list_view.dart';

class SecurityDebugPage extends StatelessWidget {
  const SecurityDebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final securityContext = context.ref.watch(securityProvider);
    return LsPageScaffold(
      title: 'Security Debugging',
      maxWidth: 700,
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        maxWidth: 700,
        children: [
          Row(
            children: [
              FilledButton(
                onPressed: () async => await context.ref.redux(securityProvider).dispatchAsync(ResetSecurityContextAction()),
                child: const Text('Reset'),
              ),
            ],
          ),
          DebugEntry(
            name: 'Certificate SHA-256 (fingerprint)',
            value: securityContext.certificateHash,
          ),
          DebugEntry(
            name: 'Certificate',
            value: securityContext.certificate,
          ),
          DebugEntry(
            name: 'Private Key',
            value: securityContext.privateKey,
          ),
          DebugEntry(
            name: 'Public Key',
            value: securityContext.publicKey,
          ),
        ],
      ),
    );
  }
}
