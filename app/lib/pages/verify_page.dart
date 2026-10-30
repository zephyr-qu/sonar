import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/security_provider.dart';
import 'package:localsend_app/util/fingerprint_alphabet.dart';
import 'package:localsend_app/widget/ls/ls_card.dart';
import 'package:localsend_app/widget/ls/ls_header.dart';
import 'package:localsend_app/widget/ls/ls_segmented.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class CombinedFingerprint {
  final String combined;
  final List<IconData> icons;

  CombinedFingerprint({
    required this.combined,
    required this.icons,
  });

  factory CombinedFingerprint.load(BuildContext context, String fingerprint) {
    final myFingerprint = context.read(securityProvider.select((s) => s.certificateHash));
    final fingerprints = [myFingerprint, fingerprint]..sort();
    final combined = fingerprints.join();
    final icons = fingerprintToIcons(combined);
    return CombinedFingerprint(
      combined: combined,
      icons: icons,
    );
  }
}

enum VerifyMode {
  icons,
  text,
}

/// Verifies the identity of a discovered device by comparing the fingerprints
/// of both sides.
class VerifyPage extends StatefulWidget {
  final CombinedFingerprint fingerprint;

  const VerifyPage({required this.fingerprint});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  VerifyMode _mode = VerifyMode.icons;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LsSubHeader(
                  title: t.verifyPage.title,
                  onBack: () => context.pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      LsSegmented(
                        options: [t.verifyPage.icons, t.verifyPage.text],
                        index: _mode.index,
                        onChanged: (index) => setState(() => _mode = VerifyMode.values[index]),
                      ),
                      const SizedBox(height: 12),
                      LsCard(
                        padding: const EdgeInsets.all(16),
                        child: VerifyWidget(
                          mode: _mode,
                          fingerprint: widget.fingerprint,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        t.verifyPage.question,
                        textAlign: TextAlign.center,
                        style: tokens.bodySm.copyWith(color: colors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VerifyWidget extends StatelessWidget {
  final VerifyMode mode;
  final CombinedFingerprint fingerprint;

  const VerifyWidget({
    required this.mode,
    required this.fingerprint,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;

    return switch (mode) {
      VerifyMode.icons => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final icon in fingerprint.icons) Icon(icon, size: 30, color: colors.fg),
            ],
          ),
        ),
      ),
      VerifyMode.text => SelectableText(fingerprint.combined, style: tokens.mono.copyWith(height: 1.6, color: colors.fg)),
    };
  }
}
