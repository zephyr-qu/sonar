import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/favorite_device.dart';
import 'package:localsend_app/pages/verify_page.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/system_date_time_formatter.dart';
import 'package:localsend_app/util/ui/snackbar.dart';
import 'package:localsend_app/widget/dialogs/favorite_delete_dialog.dart';
import 'package:localsend_app/widget/dialogs/favorite_edit_dialog.dart';
import 'package:localsend_app/widget/ls/ls_buttons.dart';
import 'package:localsend_app/widget/ls/ls_card.dart';
import 'package:localsend_app/widget/ls/ls_header.dart';
import 'package:localsend_app/widget/ls/ls_section_label.dart';
import 'package:localsend_isolates/isolate.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

/// Shows the general information of a discovered device and
/// the log of its retained discovery confirmations.
class DeviceDetailsPage extends StatefulWidget {
  final Device device;

  const DeviceDetailsPage({required this.device});

  @override
  State<DeviceDetailsPage> createState() => _DeviceDetailsPageState();
}

class _DeviceDetailsPageState extends State<DeviceDetailsPage> with Refena {
  List<DeviceLog> _logs = const [];

  @override
  void initState() {
    super.initState();

    ensureRef((ref) async {
      final logs = await ref
          .redux(parentIsolateProvider)
          .dispatchAsyncTakeResult(IsolateDiscoveryDeviceLogsAction(fingerprint: widget.device.fingerprint));
      if (mounted) {
        setState(() => _logs = logs);
      }
    });
  }

  Future<void> _toggleFavorite(FavoriteDevice? favoriteEntry) async {
    if (favoriteEntry != null) {
      final result = await showDialog<bool>(
        context: context,
        builder: (_) => FavoriteDeleteDialog(favoriteEntry),
      );
      if (result == true) {
        await ref.redux(favoritesProvider).dispatchAsync(RemoveFavoriteAction(deviceFingerprint: widget.device.fingerprint));
      }
    } else {
      await showDialog(
        context: context,
        builder: (_) => FavoriteEditDialog(prefilledDevice: widget.device),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final tokens = context.ls;
    final colors = tokens.colors;
    final favoriteEntry = ref.watch(favoritesProvider).findDevice(device);
    final meta = [
      if (device.deviceModel != null) device.deviceModel!,
      if (device.ip != null) '${device.ip}:${device.port}',
    ].join(' · ');

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LsSubHeader(
              title: t.deviceDetailsPage.title,
              subtitle: Text(
                meta.isEmpty ? device.alias : meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.mono,
              ),
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(tokens.pad, 4, tokens.pad, 20),
                    children: [
                      LsCard(
                        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: colors.bg3, borderRadius: BorderRadius.circular(tokens.radiusSm)),
                              child: Icon(device.deviceType.icon, size: 20, color: colors.fg),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(device.alias, maxLines: 1, overflow: TextOverflow.ellipsis, style: tokens.subtitle),
                                  const SizedBox(height: 3),
                                  Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: tokens.mono),
                                ],
                              ),
                            ),
                            LsIconButton(
                              icon: favoriteEntry != null ? LucideIcons.heart : LucideIcons.heart,
                              tooltip: t.deviceDetailsPage.favorite,
                              active: favoriteEntry != null,
                              onPressed: () async => _toggleFavorite(favoriteEntry),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          LsButton(
                            label: favoriteEntry != null ? t.deviceDetailsPage.favorite : t.deviceDetailsPage.favorite,
                            icon: favoriteEntry != null ? LucideIcons.heart : LucideIcons.heart,
                            variant: LsButtonVariant.ghost,
                            onPressed: () async => _toggleFavorite(favoriteEntry),
                          ),
                          LsButton(
                            label: t.deviceDetailsPage.verify,
                            icon: LucideIcons.badgeCheck,
                            variant: LsButtonVariant.ghost,
                            onPressed: () async => context.push(
                              () => VerifyPage(fingerprint: CombinedFingerprint.load(context, device.fingerprint)),
                            ),
                          ),
                        ],
                      ),
                      LsSectionLabel(label: t.deviceDetailsPage.info.title),
                      LsCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        child: Column(
                          children: [
                            _kvRow(context, t.deviceDetailsPage.info.name, device.alias),
                            Divider(color: colors.line, height: 1),
                            _kvRow(context, t.deviceDetailsPage.info.version, t.deviceDetailsPage.info.protocol(version: device.version)),
                            if (device.ip != null) ...[
                              Divider(color: colors.line, height: 1),
                              _kvRow(context, t.deviceDetailsPage.info.address, '${device.ip}:${device.port}'),
                            ],
                            if (device.rttMs != null) ...[
                              Divider(color: colors.line, height: 1),
                              _kvRow(context, t.deviceDetailsPage.info.latency, '${device.rttMs} ms'),
                            ],
                          ],
                        ),
                      ),
                      LsSectionLabel(label: t.deviceDetailsPage.logs.title, count: '${_logs.length}'),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _logs.isEmpty ? t.deviceDetailsPage.logs.empty : t.deviceDetailsPage.logs.title,
                              style: tokens.bodySm,
                            ),
                          ),
                          LsIconButton(
                            icon: LucideIcons.copy,
                            tooltip: t.general.copy,
                            onPressed: _logs.isEmpty ? null : () => _copyLogs(context),
                          ),
                        ],
                      ),
                      if (_logs.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        LsCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          child: Column(
                            children: [
                              for (var index = 0; index < _logs.length; index++) _logRow(context, _logs[index], showDivider: index > 0),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kvRow(BuildContext context, String label, String value) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: tokens.bodySm.copyWith(color: colors.fg)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: tokens.mono,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logRow(BuildContext context, DeviceLog log, {required bool showDivider}) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                top: BorderSide(color: colors.line, width: tokens.hairlineOf(context)),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            SystemDateTimeFormatter.time(context, log.timestamp),
            style: tokens.monoSm.copyWith(color: colors.faint),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(log.description, style: tokens.bodySm)),
        ],
      ),
    );
  }

  Future<void> _copyLogs(BuildContext context) async {
    try {
      await Clipboard.setData(
        ClipboardData(
          text: _logs.map((log) => '[${SystemDateTimeFormatter.time(context, log.timestamp)}] ${log.description}').join('\n'),
        ),
      );
      if (context.mounted) {
        context.showSnackBar(t.general.copiedToClipboard);
      }
    } catch (e) {
      if (context.mounted) {
        context.showSnackBar('${t.general.error}: $e');
      }
    }
  }
}

extension on DeviceLog {
  String get description {
    final protocol = channel.https ? 'HTTPS' : 'HTTP';
    return switch (kind) {
      DeviceLogKind.discovered => t.deviceDetailsPage.logs.discovered(protocol: protocol, host: channel.host),
      DeviceLogKind.updated => t.deviceDetailsPage.logs.updated(protocol: protocol, host: channel.host),
    };
  }
}
