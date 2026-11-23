import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:moform/moform.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/provider/settings_provider.dart';
import 'package:sonar/widget/dialogs/text_field_tv.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_card.dart';
import 'package:sonar/widget/ls/ls_chip.dart';
import 'package:sonar/widget/ls/ls_scaffold.dart';
import 'package:sonar/widget/ls/ls_section_label.dart';
import 'package:sonar/widget/ls/ls_segmented.dart';
import 'package:sonar_isolates/util/network_interfaces.dart';

/// Whitelist and blacklist are mutually exclusive: `null` means "filter off".
enum _NetworkFilterMode { off, whitelist, blacklist }

class NetworkInterfacesPage extends StatefulWidget {
  const NetworkInterfacesPage();

  @override
  State<NetworkInterfacesPage> createState() => _NetworkInterfacesPageState();
}

class _NetworkInterfacesPageState extends State<NetworkInterfacesPage> {
  /// Every interface of the device, including the ones the filter currently excludes.
  List<(String, List<String>)>? _rawInterfaces;

  /// Set when the interfaces could not be read: the card then says so instead of spinning forever.
  String? _interfaceError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInterfaces());
  }

  Future<void> _loadInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list();
      if (!mounted) return;
      setState(() {
        _rawInterfaces = interfaces.map((interface) => (interface.name, interface.addresses.map((address) => address.address).toList())).toList();
        _interfaceError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _interfaceError = e.toString();
      });
    }
  }

  static _NetworkFilterMode _modeOf(List<String>? whitelist, List<String>? blacklist) {
    if (whitelist != null) return _NetworkFilterMode.whitelist;
    if (blacklist != null) return _NetworkFilterMode.blacklist;
    return _NetworkFilterMode.off;
  }

  Future<void> _setMode(_NetworkFilterMode mode, List<String> rules) async {
    final notifier = context.notifier(settingsProvider);
    // An empty list would mean "filter off", so the list always keeps one (blank) rule.
    final seed = rules.isEmpty ? <String>[''] : List<String>.of(rules);
    switch (mode) {
      case _NetworkFilterMode.off:
        await notifier.setNetworkWhitelist(null);
        await notifier.setNetworkBlacklist(null);
      // The two lists are mutually exclusive, so the other one is cleared first.
      // Switching between them keeps the rules: they are reinterpreted as the other list.
      case _NetworkFilterMode.whitelist:
        await notifier.setNetworkBlacklist(null);
        await notifier.setNetworkWhitelist(seed);
      case _NetworkFilterMode.blacklist:
        await notifier.setNetworkWhitelist(null);
        await notifier.setNetworkBlacklist(seed);
    }
  }

  Future<void> _updateRules(_NetworkFilterMode mode, List<String> next) {
    final notifier = context.notifier(settingsProvider);
    final rules = next.isEmpty ? <String>[''] : next;
    return switch (mode) {
      _NetworkFilterMode.whitelist => notifier.setNetworkWhitelist(rules),
      _NetworkFilterMode.blacklist => notifier.setNetworkBlacklist(rules),
      _NetworkFilterMode.off => Future.value(),
    };
  }

  /// Tapping an address adds (or removes) it as an exact rule.
  Future<void> _toggleAddress(_NetworkFilterMode mode, List<String> rules, String address) {
    final next = List<String>.of(rules);
    if (next.contains(address)) {
      next.remove(address);
    } else {
      // Drop the blank placeholder so the list does not keep an empty rule around.
      next.removeWhere((rule) => rule.isEmpty);
      next.add(address);
    }
    return _updateRules(mode, next);
  }

  Future<void> _setRule(_NetworkFilterMode mode, List<String> rules, int index, String value) {
    final next = List<String>.of(rules);
    next[index] = value;
    return _updateRules(mode, next);
  }

  Future<void> _deleteRule(_NetworkFilterMode mode, List<String> rules, int index) async {
    final next = List<String>.of(rules)..removeAt(index);
    if (next.isEmpty) {
      // Removing the last rule turns the filter off again.
      await _setMode(_NetworkFilterMode.off, const []);
      return;
    }
    await _updateRules(mode, next);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final settings = context.watch(settingsProvider);
    final mode = _modeOf(settings.networkWhitelist, settings.networkBlacklist);
    final rules = settings.networkWhitelist ?? settings.networkBlacklist ?? const <String>[];
    final filterEnabled = mode != _NetworkFilterMode.off;
    final rulesLabel = mode == _NetworkFilterMode.blacklist ? t.networkInterfacesPage.blacklist : t.networkInterfacesPage.whitelist;
    final interfaces = _rawInterfaces;
    final ignoredCount = interfaces
        ?.where(
          (interface) => isNetworkIgnoredRaw(
            networkWhitelist: settings.networkWhitelist,
            networkBlacklist: settings.networkBlacklist,
            interface: interface.$2,
          ),
        )
        .length;
    final interfaceCount = interfaces?.length;

    return LsPageScaffold(
      title: t.networkInterfacesPage.title,
      actions: [
        LsChip.text(
          filterEnabled ? t.settingsTab.network.networkOptions.filtered : t.settingsTab.network.networkOptions.all,
          accent: filterEnabled,
        ),
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(tokens.pad, 0, tokens.pad, 24),
        children: [
          Text(t.networkInterfacesPage.info, style: tokens.bodySm),
          const SizedBox(height: 14),
          LsSegmented(
            options: [t.general.off, t.networkInterfacesPage.whitelist, t.networkInterfacesPage.blacklist],
            index: mode.index,
            onChanged: (index) {
              final next = _NetworkFilterMode.values[index];
              if (next == mode) return;
              unawaited(_setMode(next, rules));
            },
          ),
          LsSectionLabel(
            label: t.settingsTab.network.network,
            count: interfaceCount == null ? null : '${interfaceCount - (ignoredCount ?? 0)}/$interfaceCount',
          ),
          _buildInterfaces(
            rules: rules,
            mode: mode,
            whitelist: settings.networkWhitelist,
            blacklist: settings.networkBlacklist,
          ),
          if (filterEnabled) ...[
            LsSectionLabel(label: rulesLabel, count: '${rules.where((rule) => rule.isNotEmpty).length}'),
            for (var i = 0; i < rules.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: StringField(
                  value: rules[i],
                  onChanged: (value) => _setRule(mode, rules, i, value),
                  builder: (context, controller) => TextFieldTv(
                    name: rulesLabel,
                    controller: controller,
                    textAlign: TextAlign.start,
                    onDelete: () => _deleteRule(mode, rules, i),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                LsButton(
                  label: t.general.add,
                  icon: LucideIcons.plus,
                  variant: LsButtonVariant.ghost,
                  compact: true,
                  onPressed: () => _updateRules(mode, [...rules, '']),
                ),
                const Spacer(),
                Flexible(
                  child: Text('${t.general.example}: 123.123.123.123 · 123.123.123.*', style: tokens.monoSm, textAlign: TextAlign.right),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInterfaces({
    required List<String> rules,
    required _NetworkFilterMode mode,
    required List<String>? whitelist,
    required List<String>? blacklist,
  }) {
    final tokens = context.ls;
    final interfaces = _rawInterfaces;
    if (interfaces == null && _interfaceError == null) {
      return LsCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: tokens.colors.faint)),
          ),
        ),
      );
    }

    if (_interfaceError != null) {
      return LsCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.general.error, style: tokens.bodyStrong),
              const SizedBox(height: 2),
              Text(_interfaceError!, style: tokens.bodySm),
            ],
          ),
        ),
      );
    }

    if (interfaces == null) return const SizedBox();

    if (interfaces.isEmpty) {
      return LsCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text('—', style: tokens.monoSm),
          ),
        ),
      );
    }
    return LsCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < interfaces.length; i++)
            _InterfaceRow(
              index: i + 1,
              name: interfaces[i].$1,
              addresses: interfaces[i].$2,
              ignored: isNetworkIgnoredRaw(networkWhitelist: whitelist, networkBlacklist: blacklist, interface: interfaces[i].$2),
              rules: rules,
              filterEnabled: mode != _NetworkFilterMode.off,
              onToggleAddress: (address) => _toggleAddress(mode, rules, address),
              showDivider: i > 0,
            ),
        ],
      ),
    );
  }
}

class _InterfaceRow extends StatelessWidget {
  final int index;
  final String name;
  final List<String> addresses;
  final bool ignored;
  final List<String> rules;
  final bool filterEnabled;
  final ValueChanged<String> onToggleAddress;
  final bool showDivider;

  const _InterfaceRow({
    required this.index,
    required this.name,
    required this.addresses,
    required this.ignored,
    required this.rules,
    required this.filterEnabled,
    required this.onToggleAddress,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                top: BorderSide(color: colors.line, width: tokens.hairlineOf(context)),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(shape: BoxShape.circle, color: ignored ? colors.faint : colors.accent),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('#$index', style: tokens.monoSm),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ignored
                            ? tokens.bodyStrong.copyWith(color: colors.faint, decoration: TextDecoration.lineThrough, decorationColor: colors.faint)
                            : tokens.bodyStrong,
                      ),
                    ),
                    if (ignored) ...[
                      const SizedBox(width: 6),
                      Icon(LucideIcons.ban, size: 12, color: colors.faint),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final address in addresses)
                      LsChip(
                        accent: rules.contains(address),
                        tooltip: filterEnabled ? (rules.contains(address) ? t.general.delete : t.general.add) : null,
                        onTap: filterEnabled ? () => onToggleAddress(address) : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(address),
                            if (filterEnabled) ...[
                              const SizedBox(width: 4),
                              Icon(rules.contains(address) ? LucideIcons.check : LucideIcons.plus, size: 10),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
