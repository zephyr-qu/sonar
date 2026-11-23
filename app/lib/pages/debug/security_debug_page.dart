import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/provider/security_provider.dart';
import 'package:sonar/widget/debug_entry.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_scaffold.dart';

class SecurityDebugPage extends StatelessWidget {
  const SecurityDebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final securityContext = context.ref.watch(securityProvider);

    return LsPageScaffold(
      title: 'Security Debugging',
      maxWidth: 700,
      body: ListView(
        padding: EdgeInsets.fromLTRB(tokens.pad, 8, tokens.pad, 32),
        children: [
          LsButton(
            label: 'Reset',
            icon: LucideIcons.rotateCcw,
            variant: LsButtonVariant.ghost,
            compact: true,
            onPressed: () => context.ref.redux(securityProvider).dispatchAsync(ResetSecurityContextAction()),
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
