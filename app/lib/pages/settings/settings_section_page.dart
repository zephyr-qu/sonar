import 'dart:async';

import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/pages/settings/settings_sections.dart';
import 'package:sonar/pages/tabs/settings_tab_controller.dart';
import 'package:sonar/widget/ls/ls_header.dart';

/// Second level of the mobile settings: one category per page, opened from the
/// settings index. Kept deliberately short: 3–7 rows, no further nesting.
class SettingsSectionPage extends StatefulWidget {
  final SettingsSectionId sectionId;

  /// Set when the page was opened from a search result: scrolls to the row and
  /// washes it with the accent for a moment.
  final String? highlightRowId;

  const SettingsSectionPage({required this.sectionId, this.highlightRowId, super.key});

  @override
  State<SettingsSectionPage> createState() => _SettingsSectionPageState();
}

class _SettingsSectionPageState extends State<SettingsSectionPage> {
  final _targetKey = GlobalKey();
  Timer? _highlightTimer;
  bool _scrolled = false;

  String? get _highlightedId => _highlightTimer?.isActive ?? false ? widget.highlightRowId : null;

  @override
  void initState() {
    super.initState();
    if (widget.highlightRowId != null) {
      _highlightTimer = Timer(const Duration(milliseconds: 2400), () {
        if (mounted) {
          setState(() => _highlightTimer = null);
        }
      });
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final vm = context.watch(settingsTabControllerProvider);
    final section = buildSettingsSections().firstWhere((section) => section.id == widget.sectionId);
    final rows = section.buildRows(context, vm);

    if (!_scrolled && widget.highlightRowId != null) {
      _scrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetContext = _targetKey.currentContext;
        if (targetContext != null) {
          unawaited(
            Scrollable.ensureVisible(targetContext, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic, alignment: 0.25),
          );
        }
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LsSubHeader(
                  title: section.title,
                  onBack: () => context.pop(),
                ),
                Divider(color: colors.line, height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => Divider(color: colors.line, height: 1),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final highlighted = row.id == _highlightedId;
                      return SettingsRowTile(
                        key: row.id == widget.highlightRowId ? _targetKey : null,
                        row: row,
                        highlighted: highlighted,
                      );
                    },
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
