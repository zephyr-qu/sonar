import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/model/state/send/web/web_download_session.dart';
import 'package:localsend_app/model/state/server/web_share_state.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/ui/snackbar.dart';
import 'package:localsend_app/widget/dialogs/pin_dialog.dart';
import 'package:localsend_app/widget/dialogs/qr_dialog.dart';
import 'package:localsend_app/widget/dialogs/zoom_dialog.dart';
import 'package:localsend_app/widget/ls/ls_buttons.dart';
import 'package:localsend_app/widget/ls/ls_card.dart';
import 'package:localsend_app/widget/ls/ls_chip.dart';
import 'package:localsend_app/widget/ls/ls_header.dart';
import 'package:localsend_app/widget/ls/ls_section_label.dart';
import 'package:localsend_app/widget/ls/ls_switch.dart';
import 'package:localsend_isolates/util/file_size_helper.dart';
import 'package:localsend_isolates/util/sleep.dart';
import 'package:logging/logging.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

final _logger = Logger('WebSharePage');

enum _ServerState { initializing, running, error, stopping }

/// Shares a link with web browsers, in one of two modes:
/// - send: offers [WebSharePage.files] for download.
/// - receive: serves the upload page so browsers can upload files to this device.
///   Incoming requests are not listed here because they open the receive page
///   like any other incoming request.
class WebSharePage extends StatefulWidget {
  /// The files offered for download (share via link).
  /// `null` serves the upload page instead (receive via link).
  final List<CrossFile>? files;

  const WebSharePage({this.files});

  @override
  State<WebSharePage> createState() => _WebSharePageState();
}

class _WebSharePageState extends State<WebSharePage> with Refena {
  _ServerState _stateEnum = _ServerState.initializing;
  bool _encrypted = false;
  String? _initializedError;

  bool get _sendMode => widget.files != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init(encrypted: false);
    });
  }

  void _init({required bool encrypted}) async {
    final settings = ref.read(settingsProvider);
    setState(() {
      _stateEnum = _ServerState.initializing;
      _encrypted = encrypted;
      _initializedError = null;
    });
    await sleepAsync(500);
    try {
      final files = widget.files;

      // The pin of a previous web share session is kept;
      // receive mode initially uses the receive pin from settings.
      final previousWeb = ref.read(serverProvider)?.web;
      final webPin = previousWeb != null ? previousWeb.pin : (files == null ? settings.receivePin : null);

      if (files != null) {
        // The auto accept setting of a previous web download state is kept.
        await ref
            .notifier(serverProvider)
            .restartServerWithWebDownload(
              alias: settings.alias,
              port: settings.port,
              https: _encrypted,
              files: files,
              pin: webPin,
            );
      } else {
        await ref
            .notifier(serverProvider)
            .restartServer(
              alias: settings.alias,
              port: settings.port,
              https: _encrypted,
              web: WebShareUpload(pin: webPin),
            );
      }
      setState(() {
        _stateEnum = _ServerState.running;
      });
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _stateEnum = _ServerState.error;
          _initializedError = e.toString();
        });
      }
    }
  }

  /// Web share uses unencrypted http by default, so we need to revert to the previous state.
  Future<void> _revertServerState() async {
    await ref.notifier(serverProvider).restartServerFromSettings();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, _) async {
        if (_stateEnum == _ServerState.initializing || _stateEnum == _ServerState.stopping) {
          return;
        }

        setState(() {
          _stateEnum = _ServerState.stopping;
        });
        await sleepAsync(250);
        try {
          // Also needed in the error state: the failed restart already stopped the old server.
          await _revertServerState();
        } catch (e) {
          _logger.warning('Failed to restore the server', e);
        }
        await sleepAsync(250);

        if (context.mounted) {
          context.pop();
        }
      },
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              LsSubHeader(
                title: _sendMode ? t.webSharePage.title : t.webReceivePage.title,
                subtitle: switch (widget.files) {
                  final files? => Text(
                    '${t.transferTab.items(n: files.length)} · ${files.fold<int>(0, (sum, file) => sum + file.size).asReadableFileSize}',
                    style: context.ls.monoSm,
                  ),
                  null => null,
                },
                onBack: () => Navigator.of(context).maybePop(),
                actions: [
                  LsChip.text(_encrypted ? t.receiveRequestPage.secure : t.receiveRequestPage.plain, accent: _encrypted),
                ],
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final tokens = context.ls;
                    final colors = tokens.colors;

                    if (_stateEnum != _ServerState.running) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_stateEnum == _ServerState.initializing || _stateEnum == _ServerState.stopping) ...[
                                CircularProgressIndicator(color: colors.accent),
                                const SizedBox(height: 16),
                                Text(
                                  _stateEnum == _ServerState.initializing ? t.webSharePage.loading : t.webSharePage.stopping,
                                  style: tokens.bodySm,
                                  textAlign: TextAlign.center,
                                ),
                              ] else if (_initializedError != null) ...[
                                Icon(LucideIcons.alertCircle, size: 40, color: colors.danger),
                                const SizedBox(height: 12),
                                Text(t.webSharePage.error, style: tokens.title, textAlign: TextAlign.center),
                                const SizedBox(height: 8),
                                SelectableText(_initializedError!, style: tokens.bodySm, textAlign: TextAlign.center),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    final serverState = context.watch(serverProvider);
                    final webDownloadState = serverState?.webDownloadState;
                    if (serverState == null || (_sendMode && webDownloadState == null)) {
                      // the server is restarting (e.g. because the pin changed)
                      return const Center(child: CircularProgressIndicator());
                    }
                    final networkState = context.watch(localIpProvider);
                    final settings = context.watch(settingsProvider);
                    final pin = serverState.web?.pin;
                    final baseUrl = networkState.localIps.isEmpty
                        ? null
                        : '${_encrypted ? 'https' : 'http'}://${networkState.localIps.first}:${serverState.port}';

                    void copy(String url) {
                      Clipboard.setData(ClipboardData(text: url)); // ignore: discarded_futures
                      if (context.mounted) {
                        context.showSnackBar(t.general.copiedToClipboard);
                      }
                    }

                    return Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 640),
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                children: [
                                  Text(
                                    t.webSharePage.openLink(n: networkState.localIps.length),
                                    style: tokens.bodySm,
                                  ),
                                  const SizedBox(height: 8),
                                  LsCard(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    child: Column(
                                      children: [
                                        for (var i = 0; i < networkState.localIps.length; i++) ...[
                                          if (i > 0) Divider(color: colors.line, height: 1),
                                          _LinkRow(
                                            url: '${_encrypted ? 'https' : 'http'}://${networkState.localIps[i]}:${serverState.port}',
                                            urlWithPin: switch (pin) {
                                              String() =>
                                                '${_encrypted ? 'https' : 'http'}://${networkState.localIps[i]}:${serverState.port}/?pin=${Uri.encodeQueryComponent(pin)}',
                                              null => '${_encrypted ? 'https' : 'http'}://${networkState.localIps[i]}:${serverState.port}',
                                            },
                                            pin: pin,
                                            listenIncoming: _sendMode,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (_sendMode)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(t.webSharePage.expiresHint, style: tokens.bodySm.copyWith(color: colors.faint)),
                                    ),
                                  if (webDownloadState != null) ...[
                                    LsSectionLabel(
                                      label: t.webSharePage.requests,
                                      count: null,
                                    ),
                                    if (webDownloadState.sessions.isEmpty)
                                      LsCard(
                                        padding: const EdgeInsets.all(14),
                                        child: Text(t.webSharePage.noRequests, style: tokens.bodySm),
                                      )
                                    else
                                      for (final entry in webDownloadState.sessions.entries)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: LsCard(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                            child: _WebRequestRow(
                                              session: entry.value,
                                              onAccept: () => ref.notifier(serverProvider).acceptWebDownloadRequest(entry.key),
                                              onDecline: () => ref.notifier(serverProvider).declineWebDownloadRequest(entry.key),
                                            ),
                                          ),
                                        ),
                                  ],
                                  LsSectionLabel(label: t.general.settings),
                                  LsCard(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                    child: Column(
                                      children: [
                                        _settingRow(
                                          context,
                                          label: t.webSharePage.encryption,
                                          description: _encrypted ? t.webSharePage.encryptionHint : null,
                                          value: LsChip.text(_encrypted ? 'HTTPS' : 'HTTP', accent: _encrypted),
                                          trailing: LsSwitch(
                                            value: _encrypted,
                                            label: t.webSharePage.encryption,
                                            onChanged: (value) => _init(encrypted: value),
                                          ),
                                        ),
                                        Divider(color: colors.line, height: 1),
                                        _settingRow(
                                          context,
                                          label: t.webSharePage.autoAccept,
                                          value: null,
                                          trailing: LsSwitch(
                                            value: webDownloadState != null ? webDownloadState.autoAccept : settings.receiveViaLinkAutoAccept,
                                            label: t.webSharePage.autoAccept,
                                            onChanged: (value) async {
                                              if (webDownloadState != null) {
                                                ref.notifier(serverProvider).setWebDownloadAutoAccept(value);
                                              } else {
                                                await ref.notifier(settingsProvider).setReceiveViaLinkAutoAccept(value);
                                              }
                                            },
                                          ),
                                        ),
                                        Divider(color: colors.line, height: 1),
                                        _settingRow(
                                          context,
                                          label: t.webSharePage.requirePin,
                                          description: pin == null ? null : t.webSharePage.pinHint(pin: pin),
                                          value: Text(
                                            pin ?? '----',
                                            style: tokens.mono.copyWith(color: pin == null ? colors.faint : colors.accent),
                                          ),
                                          trailing: LsSwitch(
                                            value: pin != null,
                                            label: t.webSharePage.requirePin,
                                            onChanged: (value) async {
                                              if (pin != null) {
                                                await ref.notifier(serverProvider).setWebPin(null);
                                              } else {
                                                final String? newPin = await showDialog<String>(
                                                  context: context,
                                                  builder: (_) => const PinDialog(
                                                    obscureText: false,
                                                    generateRandom: true,
                                                  ),
                                                );
                                                if (newPin != null && newPin.isNotEmpty) {
                                                  await ref.notifier(serverProvider).setWebPin(newPin);
                                                }
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          decoration: BoxDecoration(
                            color: colors.bg,
                            border: Border(
                              top: BorderSide(color: colors.line, width: tokens.hairlineOf(context)),
                            ),
                          ),
                          child: LsButton(
                            label: t.webSharePage.copyLink,
                            icon: LucideIcons.link,
                            expand: true,
                            onPressed: baseUrl == null
                                ? null
                                : () {
                                    final currentPin = serverState.web?.pin;
                                    final url = switch (currentPin) {
                                      String() => '$baseUrl/?pin=${Uri.encodeQueryComponent(currentPin)}',
                                      null => baseUrl,
                                    };
                                    copy(url);
                                  },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingRow(
    BuildContext context, {
    required String label,
    String? description,
    Widget? value,
    required Widget trailing,
  }) {
    final tokens = context.ls;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: tokens.body),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(description, style: tokens.bodySm),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 10),
            value,
          ],
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String url;
  final String urlWithPin;
  final String? pin;
  final bool listenIncoming;

  const _LinkRow({
    required this.url,
    required this.urlWithPin,
    required this.pin,
    required this.listenIncoming,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              url,
              maxLines: 2,
              style: tokens.mono.copyWith(color: colors.fg),
            ),
          ),
          const SizedBox(width: 8),
          LsChip.text(
            t.general.copy,
            accent: true,
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: urlWithPin));
              if (context.mounted && checkPlatformIsDesktop()) {
                context.showSnackBar(t.general.copiedToClipboard);
              }
            },
          ),
          const SizedBox(width: 2),
          LsIconButton(
            icon: LucideIcons.qrCode,
            tooltip: t.webSharePage.title,
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (_) => QrDialog(
                  data: urlWithPin,
                  label: url,
                  listenIncomingWebDownloadRequests: listenIncoming,
                  pin: pin,
                ),
              );
            },
          ),
          LsIconButton(
            icon: LucideIcons.tv,
            tooltip: t.general.open,
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (_) => ZoomDialog(
                  label: url,
                  listenIncomingWebDownloadRequests: listenIncoming,
                  pin: pin,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WebRequestRow extends StatelessWidget {
  final WebDownloadSession session;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _WebRequestRow({
    required this.session,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final pending = session.pending;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                session.deviceInfo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.body.copyWith(color: pending ? colors.danger : colors.fg),
              ),
              const SizedBox(height: 2),
              Text(session.ip, style: tokens.monoSm),
            ],
          ),
        ),
        if (pending) ...[
          LsIconButton(icon: LucideIcons.x, tooltip: t.general.decline, onPressed: onDecline),
          LsIconButton(icon: LucideIcons.check, tooltip: t.general.accept, onPressed: onAccept),
        ] else
          LsChip.text(t.general.accepted, accent: true),
      ],
    );
  }
}
