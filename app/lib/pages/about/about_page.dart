import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/pages/debug/debug_page.dart';
import 'package:sonar/util/i18n.dart';
import 'package:sonar/widget/ls/ls_card.dart';
import 'package:sonar/widget/ls/ls_scaffold.dart';
import 'package:sonar/widget/ls/ls_section_label.dart';
import 'package:sonar/widget/sonar_logo.dart';
import 'package:url_launcher/url_launcher.dart';

part 'contributors.dart';
part 'packagers.dart';
part 'translators.dart';

final _translatorWithGithubRegex = RegExp(r'(.+) \(@([\w\-_]+)\)');

class AboutPage extends StatelessWidget {
  const AboutPage();

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;

    return LsPageScaffold(
      title: t.aboutPage.title,
      body: ListView(
        padding: EdgeInsets.fromLTRB(tokens.pad, 4, tokens.pad, 32),
        children: [
          const _IdentityCard(),
          LsSectionLabel(label: t.aboutPage.author),
          const LsCard(
            padding: EdgeInsets.all(14),
            child: _CreditList(entries: ['Zephyr (@zephyr-qu)']),
          ),
          LsSectionLabel(label: t.aboutPage.originalAuthor, padding: const EdgeInsets.only(top: 14, bottom: 8)),
          const LsCard(
            padding: EdgeInsets.all(14),
            child: _CreditList(entries: ['Tien Do Nam (@Tienisto)']),
          ),
          LsSectionLabel(label: t.aboutPage.contributors, count: '${_contributors.length}'),
          LsCard(
            padding: const EdgeInsets.all(14),
            child: _CreditList(entries: _contributors),
          ),
          LsSectionLabel(label: t.aboutPage.packagers, count: '${_packagers.length}'),
          LsCard(
            padding: const EdgeInsets.all(14),
            child: _LocaleCreditList(rows: _packagers.entries.toList()),
          ),
          LsSectionLabel(label: t.aboutPage.translators, count: '${_translators.length}'),
          LsCard(
            padding: const EdgeInsets.all(14),
            child: _LocaleCreditList(
              rows: _translators.entries.map((e) => MapEntry(e.key.getLocaleName(), e.value)).toList(),
            ),
          ),
          const SizedBox(height: 22),
          const SizedBox(height: 22),
          const Column(
            spacing: 6,
            children: [
              _LinkRow(icon: LucideIcons.globe, label: 'localsend.org', url: 'https://localsend.org'),
              _LinkRow(icon: LucideIcons.github, label: 'Source Code (Github)', url: 'https://github.com/zephyr-qu/sonar'),
              _LinkRow(icon: LucideIcons.gitFork, label: 'LocalSend (upstream)', url: 'https://localsend.org'),
              _LinkRow(icon: LucideIcons.scale, label: 'Apache License 2.0', url: 'https://www.apache.org/licenses/LICENSE-2.0'),
              _LinkRow(icon: LucideIcons.fileText, label: 'License Notices', page: LicensePage()),
              _LinkRow(icon: LucideIcons.bug, label: 'Debugging', page: DebugPage()),
            ],
          ),
        ],
      ),
    );
  }
}

/// Logo, name, ownership and the app description as one hero card.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard();

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;

    return LsCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SonarLogo(withText: false, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sonar', style: tokens.title),
                    const SizedBox(height: 3),
                    Text(
                      '© ${DateTime.now().year} Zephyr · Based on LocalSend © Tien Do Nam',
                      style: tokens.bodySm,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final paragraph in t.aboutPage.description)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(paragraph, style: tokens.bodySm.copyWith(color: colors.fg)),
            ),
        ],
      ),
    );
  }
}

/// A name plus an optional github handle, one per row.
class _CreditList extends StatelessWidget {
  final List<String> entries;

  const _CreditList({required this.entries});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text.rich(
              _buildContributor(label: entry, primaryColor: colors.accent),
              style: tokens.bodySm.copyWith(color: colors.fg),
            ),
          ),
      ],
    );
  }
}

/// Locale → translators, the locale as a mono caption above its names.
class _LocaleCreditList extends StatelessWidget {
  final List<MapEntry<String, List<String>>> rows;

  const _LocaleCreditList({required this.rows});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < rows.length; index++)
          Padding(
            padding: EdgeInsets.only(bottom: index == rows.length - 1 ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rows[index].key, style: tokens.mono),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: rows[index].value
                        .mapIndexed(
                          (nameIndex, translator) => _buildContributor(
                            label: translator,
                            primaryColor: colors.accent,
                            newLine: nameIndex != 0,
                          ),
                        )
                        .toList(),
                  ),
                  style: tokens.bodySm.copyWith(color: colors.fg),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One footer link as its own tile: icon, label and the outbound arrow.
class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? url;
  final Widget? page;

  const _LinkRow({required this.icon, required this.label, this.url, this.page});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;

    return LsCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: tokens.tileRadius,
      onTap: () async {
        if (page != null) {
          await context.push(() => page!);
          return;
        }
        await launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication);
      },
      child: Row(
        children: [
          Icon(icon, size: 14, color: colors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: tokens.body.copyWith(color: colors.fg)),
          ),
          Icon(LucideIcons.arrowUpRight, size: 13, color: colors.faint),
        ],
      ),
    );
  }
}

/// Displays the contributor name and links to their github profile.
InlineSpan _buildContributor({required String label, required Color primaryColor, bool newLine = false}) {
  final newLineStr = newLine ? '\n' : '';

  if (label.startsWith('@')) {
    // Only github name
    return TextSpan(
      text: '$newLineStr$label',
      style: TextStyle(color: primaryColor),
      recognizer: TapGestureRecognizer()
        ..onTap = () async {
          await launchUrl(Uri.parse('https://github.com/${label.substring(1)}'), mode: LaunchMode.externalApplication);
        },
    );
  }

  final match = _translatorWithGithubRegex.firstMatch(label);
  if (match != null) {
    // Full name and github name
    final fullName = match.group(1)!;
    final githubName = match.group(2)!;
    return TextSpan(
      children: [
        TextSpan(text: '$newLineStr$fullName'),
        const TextSpan(text: ' '),
        TextSpan(
          text: '@$githubName',
          style: TextStyle(color: primaryColor),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              await launchUrl(Uri.parse('https://github.com/$githubName'), mode: LaunchMode.externalApplication);
            },
        ),
      ],
    );
  }

  // Only full name
  return TextSpan(text: '$newLineStr$label');
}
