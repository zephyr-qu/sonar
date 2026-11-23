import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/pages/about/about_page.dart';
import 'package:sonar/pages/changelog_page.dart';
import 'package:sonar/pages/donation/donation_page.dart';
import 'package:sonar/pages/settings/settings_section_page.dart';
import 'package:sonar/pages/settings/settings_sections.dart';
import 'package:sonar/pages/tabs/settings_tab_controller.dart';
import 'package:sonar/pages/tabs/settings_tab_vm.dart';
import 'package:sonar/provider/version_provider.dart';
import 'package:sonar/util/native/platform_check.dart';
import 'package:sonar/widget/desktop_scaffold.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_header.dart';
import 'package:sonar/widget/ls/ls_mark.dart';
import 'package:sonar/widget/ls/ls_search_field.dart';
import 'package:sonar/widget/ls/ls_state_tag.dart';
import 'package:url_launcher/url_launcher.dart';

/// The settings area: a five/six-row index on mobile (each row opens a short
/// detail page) and a category/content split view on desktop. Both levels are
/// rendered from the same [SettingsSection] definitions.
class SettingsPage extends StatelessWidget {
  /// Whether the page is a screen inside the desktop shell. The shell already
  /// provides the rail, so this only adds the shared window header.
  final bool desktop;

  const SettingsPage({this.desktop = false, super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      provider: (ref) => settingsTabControllerProvider,
      builder: (context, vm) => _SettingsView(vm: vm, desktop: desktop),
    );
  }
}

class _SettingsView extends StatefulWidget {
  final SettingsTabVm vm;
  final bool desktop;

  const _SettingsView({required this.vm, required this.desktop});

  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  final _query = TextEditingController();
  final _desktopTargetKey = GlobalKey();

  SettingsSectionId _selected = SettingsSectionId.device;
  String? _highlightId;
  Timer? _highlightTimer;
  bool _desktopScrollScheduled = false;

  /// Rows of every section, built at most once per build (see [_rowsOf]).
  final Map<SettingsSectionId, List<SettingsRow>> _rowsCache = {};

  /// The rows matching the current query, filtered at most once per build. The
  /// count text and the result list both ask for it (on desktop that is the
  /// sidebar and the content), so filtering used to run twice per keystroke.
  List<(SettingsSection, SettingsRow)>? _searchCache;
  String? _searchCacheQuery;

  SettingsTabVm get vm => widget.vm;

  @override
  void dispose() {
    _query.dispose();
    _highlightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A desktop-only section additionally needs rows that are usable on this
    // platform: a tablet gets the desktop layout once its window is wide
    // enough, but has no tray, window placement or autostart, so every row of
    // the desktop section is gated off and the tile would show "0 items" and
    // open an empty page. Sections without any row are dropped instead.
    final sections = [
      for (final section in buildSettingsSections())
        if ((!section.desktopOnly || widget.desktop) && _rowsOf(context, section).isNotEmpty) section,
    ];
    final query = _query.text.trim().toLowerCase();
    _rowsCache.clear();
    _searchCache = null;
    _searchCacheQuery = null;

    if (widget.desktop) {
      return Column(
        children: [
          const LsDesktopDeviceHeader(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _desktopSidebar(context, sections: sections, query: query),
                Expanded(
                  child: _desktopContent(context, sections: sections, query: query),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LsSubHeader(
              title: t.settingsTab.title,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: LsSearchField(
                controller: _query,
                hint: t.settingsPage.searchHint,
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                child: Text(
                  t.settingsPage.results(
                    n: _search(context, sections: sections, query: query).length,
                  ),
                  style: context.ls.eyebrow,
                ),
              ),
            Expanded(
              child: query.isEmpty ? _mobileIndex(context, sections: sections) : _searchResults(context, sections: sections, query: query),
            ),
          ],
        ),
      ),
    );
  }

  /// The rows of one section, built at most once per build.
  ///
  /// The rows are needed for the row count and for rendering, and the search box
  /// rebuilds this page on every keystroke, so building them again per use
  /// tripled the work of one frame.
  List<SettingsRow> _rowsOf(BuildContext context, SettingsSection section) =>
      _rowsCache.putIfAbsent(section.id, () => section.buildRows(context, vm));

  // ------------------------------------------------------------------ mobile

  Widget _mobileIndex(BuildContext context, {required List<SettingsSection> sections}) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final section in sections) ...[
          _mobileSectionTile(context, section),
          Divider(color: colors.line, height: 1),
        ],
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _footer(context),
        ),
      ],
    );
  }

  Widget _mobileSectionTile(BuildContext context, SettingsSection section) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final rows = _rowsOf(context, section);
    final tags = section.buildTags(context, vm);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        hoverColor: colors.bg3,
        onTap: () async => context.push(() => SettingsSectionPage(sectionId: section.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              LsMark.icon(section.icon, iconSize: 16, iconColor: colors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(section.title, style: tokens.title.copyWith(fontSize: 15)),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      SettingsTagsLine(tags: tags),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                t.settingsPage.items(n: rows.length),
                style: tokens.monoSm.copyWith(color: colors.faint),
              ),
              const SizedBox(width: 4),
              Icon(LucideIcons.chevronRight, size: 16, color: colors.faint),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchResults(BuildContext context, {required List<SettingsSection> sections, required String query}) {
    final tokens = context.ls;
    final results = _search(context, sections: sections, query: query);
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Text(t.settingsPage.noResults(query: _query.text.trim()), style: tokens.bodySm),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: results.length,
      separatorBuilder: (_, _) => Divider(color: tokens.colors.line, height: 1),
      itemBuilder: (context, index) {
        final section = results[index].$1;
        final row = results[index].$2;
        return _searchResultTile(
          context,
          section: section,
          row: row,
          onTap: () async => context.push(() => SettingsSectionPage(sectionId: section.id, highlightRowId: row.id)),
        );
      },
    );
  }

  Widget _searchResultTile(BuildContext context, {required SettingsSection section, required SettingsRow row, required VoidCallback onTap}) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        hoverColor: colors.bg3,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(section.title, style: tokens.eyebrow),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: Text(row.label, style: tokens.body.copyWith(height: 1.3)),
                  ),
                  if (row.on != null && row.value == null) ...[
                    const SizedBox(width: 10),
                    LsSwitchIndicator(on: row.on!),
                  ] else if (row.value != null) ...[
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(row.value!, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: tokens.mono),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Icon(LucideIcons.chevronRight, size: 14, color: colors.faint),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- desktop

  Widget _desktopSidebar(BuildContext context, {required List<SettingsSection> sections, required String query}) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Container(
      width: 300,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: colors.line, width: tokens.hairlineOf(context)),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        children: [
          Text(t.settingsTab.title, style: tokens.pageTitle),
          const SizedBox(height: 14),
          LsSearchField(
            controller: _query,
            hint: t.settingsPage.searchHint,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          for (final section in sections) _desktopSectionTile(context, section),
          const SizedBox(height: 20),
          _footer(context),
        ],
      ),
    );
  }

  Widget _desktopSectionTile(BuildContext context, SettingsSection section) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final rows = _rowsOf(context, section);
    final selected = section.id == _selected && _query.text.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? colors.accentSoft : Colors.transparent,
        borderRadius: tokens.tileRadius,
        child: InkWell(
          borderRadius: tokens.tileRadius,
          hoverColor: colors.bg3,
          onTap: () => setState(() {
            _selected = section.id;
            _highlightId = null;
            _query.clear();
          }),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 9, 10, 9),
            child: Row(
              children: [
                Icon(section.icon, size: 15, color: selected ? colors.accentInk : colors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.body.copyWith(
                      height: 1.2,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? colors.accentInk : colors.fg,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  rows.length.toString(),
                  style: tokens.monoSm.copyWith(color: selected ? colors.accentInk : colors.faint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopContent(BuildContext context, {required List<SettingsSection> sections, required String query}) {
    final tokens = context.ls;
    if (query.isNotEmpty) {
      final results = _search(context, sections: sections, query: query);
      return _desktopBody(
        ListView(
          padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
          children: [
            Text(t.settingsPage.results(n: results.length), style: tokens.display.copyWith(fontSize: 24)),
            const SizedBox(height: 8),
            if (results.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(t.settingsPage.noResults(query: _query.text.trim()), style: tokens.bodySm),
              )
            else
              for (final result in results) ...[
                Divider(color: tokens.colors.line, height: 1),
                _searchResultTile(
                  context,
                  section: result.$1,
                  row: result.$2,
                  onTap: () {
                    setState(() {
                      _selected = result.$1.id;
                      _query.clear();
                    });
                    _highlightOnDesktop(result.$2.id);
                  },
                ),
              ],
          ],
        ),
      );
    }

    final section = sections.firstWhere((section) => section.id == _selected, orElse: () => sections.first);
    final rows = _rowsOf(context, section);
    if (_highlightId != null && !_desktopScrollScheduled) {
      _desktopScrollScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetContext = _desktopTargetKey.currentContext;
        if (targetContext != null) {
          unawaited(Scrollable.ensureVisible(targetContext, duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic, alignment: 0.2));
        }
      });
    }
    return _desktopBody(
      ListView(
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
        children: [
          Text(section.title, style: tokens.pageTitle),
          const SizedBox(height: 12),
          Divider(color: tokens.colors.line, height: 1),
          for (final row in rows)
            SettingsRowTile(
              key: row.id == _highlightId ? _desktopTargetKey : null,
              row: row,
              highlighted: row.id == _highlightId,
            ),
        ],
      ),
    );
  }

  /// Keeps the desktop content column readable on very wide windows.
  Widget _desktopBody(Widget child) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: child,
      ),
    );
  }

  /// Reached a row from the desktop search: select its section, scroll to it
  /// and keep the accent wash for a moment.
  void _highlightOnDesktop(String rowId) {
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) {
        setState(() => _highlightId = null);
      }
    });
    setState(() {
      _highlightId = rowId;
      _desktopScrollScheduled = false;
    });
  }

  // ------------------------------------------------------------------ helpers

  List<(SettingsSection, SettingsRow)> _search(BuildContext context, {required List<SettingsSection> sections, required String query}) {
    final cached = _searchCache;
    if (cached != null && _searchCacheQuery == query) {
      return cached;
    }
    final results = <(SettingsSection, SettingsRow)>[];
    for (final section in sections) {
      // Matching the section title keeps a whole category reachable by name: typing
      // "network" should surface its rows even though none of them repeats the word.
      final titleMatches = section.title.toLowerCase().contains(query);
      for (final row in _rowsOf(context, section)) {
        if (titleMatches || row.matches(query)) {
          results.add((section, row));
        }
      }
    }
    _searchCache = results;
    _searchCacheQuery = query;
    return results;
  }

  Widget _footer(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final version = context
        .watch(versionProvider)
        .maybeWhen<String?>(
          data: (version) => version.combinedString,
          orElse: () => null,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LsLinkRow(
          label: t.aboutPage.title,
          showTopBorder: false,
          onTap: () async => context.push(() => const AboutPage()),
        ),
        LsLinkRow(
          label: t.settingsTab.other.support,
          onTap: () async => context.push(() => const DonationPage()),
        ),
        LsLinkRow(
          label: t.settingsTab.other.privacyPolicy,
          onTap: () async {
            await launchUrl(Uri.parse('https://localsend.org/privacy'), mode: LaunchMode.externalApplication);
          },
        ),
        if (checkPlatform([TargetPlatform.iOS, TargetPlatform.macOS]))
          LsLinkRow(
            label: t.settingsTab.other.termsOfUse,
            onTap: () async {
              await launchUrl(
                Uri.parse('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
        LsLinkRow(
          label: t.changelogPage.title,
          onTap: () async => context.push(() => const ChangelogPage()),
        ),
        const SizedBox(height: 10),
        Text(
          [t.appName, ?version].join(' '),
          textAlign: TextAlign.center,
          style: tokens.monoSm.copyWith(color: colors.faint),
        ),
        const SizedBox(height: 2),
        Text(
          '© ${DateTime.now().year} Zephyr',
          textAlign: TextAlign.center,
          style: tokens.monoSm.copyWith(color: colors.faint),
        ),
        const SizedBox(height: 2),
        Text(
          'Based on LocalSend © Tien Do Nam',
          textAlign: TextAlign.center,
          style: tokens.monoSm.copyWith(color: colors.faint),
        ),
      ],
    );
  }
}
