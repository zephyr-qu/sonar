import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/cross_file.dart';
import 'package:sonar/model/state/send/web/web_download_session.dart';
import 'package:sonar/model/state/send/web/web_download_state.dart';
import 'package:sonar/model/state/server/web_share_state.dart';
import 'package:sonar/provider/local_ip_provider.dart';
import 'package:sonar/provider/network/server/server_provider.dart';
import 'package:sonar/provider/settings_provider.dart';
import 'package:sonar/util/native/platform_check.dart';
import 'package:sonar/util/ui/snackbar.dart';
import 'package:sonar/widget/desktop_scaffold.dart';
import 'package:sonar/widget/dialogs/pin_dialog.dart';
import 'package:sonar/widget/dialogs/qr_dialog.dart';
import 'package:sonar/widget/dialogs/zoom_dialog.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_card.dart';
import 'package:sonar/widget/ls/ls_chip.dart';
import 'package:sonar/widget/ls/ls_header.dart';
import 'package:sonar/widget/ls/ls_section_label.dart';
import 'package:sonar/widget/ls/ls_switch.dart';
import 'package:sonar_isolates/util/file_size_helper.dart';
import 'package:sonar_isolates/util/sleep.dart';

final _logger = Logger('WebSharePage');

enum _ServerState { initializing, running, error, stopping }

/// Shares a link with web browsers, in one of two modes:
/// - send: offers [WebSharePage.files] for download.
/// - receive: serves the upload page so browsers can upload files to this device.
///   Incoming requests are not listed here because they open the receive dialog
///   like any other incoming request.
///
/// This is the mobile form: a page pushed above the app. Desktop uses
/// [WebSharePanel], which renders the same session inside the nearby tab.
class WebSharePage extends StatelessWidget {
  /// The files offered for download (share via link).
  /// `null` serves the upload page instead (receive via link).
  final List<CrossFile>? files;

  const WebSharePage({super.key, this.files});

  @override
  Widget build(BuildContext context) => WebShareSession(files: files);
}

/// The desktop form of [WebSharePage]: the same session rendered as a panel
/// inside the nearby tab instead of a route above it. The rail, the device
/// header and its visible toggle stay in place, which is what a desktop window
/// with a 1200px canvas can afford — a pushed page covered all of it.
class WebSharePanel extends StatelessWidget {
  /// The files offered for download. `null` serves the upload page (receive via link).
  final List<CrossFile>? files;

  /// Called once the server was restored. The host clears its panel state.
  final VoidCallback onClosed;

  const WebSharePanel({super.key, required this.files, required this.onClosed});

  @override
  Widget build(BuildContext context) => WebShareSession(files: files, desktop: true, onClosed: onClosed);
}

/// The session behind both forms: it restarts the server for web sharing and
/// restores the previous server state on the way out.
class WebShareSession extends StatefulWidget {
  final List<CrossFile>? files;

  /// Panel mode: no scaffold, no route. Leaving calls [onClosed] instead of popping.
  final bool desktop;

  final VoidCallback? onClosed;

  const WebShareSession({super.key, this.files, this.desktop = false, this.onClosed});

  @override
  State<WebShareSession> createState() => _WebShareSessionState();
}

class _WebShareSessionState extends State<WebShareSession> with Refena {
  _ServerState _stateEnum = _ServerState.initializing;
  bool _encrypted = false;

  /// Which of [localIpProvider]'s addresses the desktop aside QR shows; the
  /// link rows' QR buttons pick it.
  int _selectedIp = 0;
  String? _initializedError;

  /// Guards the auto-close below against re-entering while the callback pends.
  bool _closedByServer = false;

  bool get _sendMode => widget.files != null;

  bool get _busy => _stateEnum == _ServerState.initializing || _stateEnum == _ServerState.stopping;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_init(encrypted: false));
    });
  }

  Future<void> _init({required bool encrypted}) async {
    final settings = ref.read(settingsProvider);
    final files = widget.files;

    setState(() {
      _encrypted = encrypted;
      _stateEnum = _ServerState.initializing;
      _initializedError = null;
    });

    // Workaround for black screen glitch
    await sleepAsync(500);

    try {
      final previousWeb = ref.read(serverProvider)?.web;
      final webPin = previousWeb != null ? previousWeb.pin : (files == null ? settings.receivePin : null);

      if (files != null) {
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
      if (!mounted) {
        return;
      }
      setState(() {
        _stateEnum = _ServerState.running;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _stateEnum = _ServerState.error;
        _initializedError = e.toString();
      });
    }
  }

  /// Web share uses unencrypted http by default, so we need to revert to the previous state.
  Future<void> _revertServerState() async {
    await ref.notifier(serverProvider).restartServerFromSettings();
  }

  /// Restores the server and leaves — by popping the page or by clearing the panel.
  Future<void> _stop() async {
    if (_busy) {
      return;
    }

    setState(() {
      _stateEnum = _ServerState.stopping;
    });
    if (!widget.desktop) {
      await sleepAsync(250);
    }
    try {
      // Also needed in the error state: the failed restart already stopped the old server.
      await _revertServerState();
    } catch (e) {
      _logger.warning('Failed to restore the server', e);
    }
    if (!widget.desktop) {
      await sleepAsync(250);
    }

    if (!mounted) {
      return;
    }
    final onClosed = widget.onClosed;
    if (onClosed != null) {
      onClosed();
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.desktop) {
      return _buildDesktop(context);
    }
    return PopScope(
      onPopInvokedWithResult: (_, _) async {
        // Back goes through [_stop]: popping directly would leave the custom
        // server state behind.
        await _stop();
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
                    '${t.transferTab.items(n: files.length)}  ${files.fold<int>(0, (sum, file) => sum + file.size).asReadableFileSize}',
                    style: context.ls.monoSm,
                  ),
                  null => null,
                },
                onBack: () => Navigator.of(context).maybePop(),
                actions: [
                  LsChip.text(_encrypted ? t.receiveRequestPage.secure : t.receiveRequestPage.plain, accent: _encrypted),
                ],
              ),
              Expanded(child: _buildPageBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- mobile page

  Widget _buildPageBody(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;

    if (_stateEnum != _ServerState.running) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy) ...[
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
    final pin = serverState.web?.pin;
    final scheme = _encrypted ? 'https' : 'http';
    final baseUrl = networkState.localIps.isEmpty ? null : '$scheme://${networkState.localIps.first}:${serverState.port}';

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
                  _linksCard(context, port: serverState.port, localIps: networkState.localIps, pin: pin),
                  if (_sendMode) _expiresHint(context),
                  ..._requestsSection(context, webDownloadState),
                  LsSectionLabel(label: t.general.settings),
                  LsCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    child: _settingsColumn(context, webDownloadState: webDownloadState),
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
                    _copyLink(context, url);
                  },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------- desktop panel

  Widget _buildDesktop(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final serverState = context.watch(serverProvider);
    final networkState = context.watch(localIpProvider);
    final webDownloadState = serverState?.webDownloadState;
    final pin = serverState?.web?.pin;
    final port = serverState?.port;
    final scheme = _encrypted ? 'https' : 'http';
    final busy = _busy || serverState == null || (_sendMode && webDownloadState == null);
    // The link rows' QR buttons pick which address the aside QR shows, so the
    // address under the QR and the copied URL follow that choice.
    final localIps = networkState.localIps;
    final selectedIp = localIps.isEmpty ? null : localIps[_selectedIp.clamp(0, localIps.length - 1)];

    // The 可见/隐藏 toggle in the device header stops the server underneath us;
    // collapse the panel instead of spinning on a session that no longer exists.
    if (_stateEnum == _ServerState.running && serverState == null && !_closedByServer) {
      _closedByServer = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _closedByServer = false;
        if (mounted) {
          widget.onClosed?.call();
        }
      });
    }

    return LsDesktopLayout(
      content: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
        children: [
          _panelHeader(context),
          if (_stateEnum == _ServerState.error)
            _panelError(context)
          else if (busy)
            _panelBusy(context)
          else ...[
            Text(t.webSharePage.openLink(n: networkState.localIps.length), style: tokens.bodySm),
            const SizedBox(height: 8),
            _linksCard(
              context,
              port: port,
              localIps: networkState.localIps,
              pin: pin,
              selectedIp: _selectedIp,
              onSelectIp: (index) => setState(() => _selectedIp = index),
            ),
            if (_sendMode) _expiresHint(context),
            ..._requestsSection(context, webDownloadState),
            if (_encrypted)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.info, size: 13, color: colors.faint),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(t.webSharePage.encryptionHint, style: tokens.bodySm.copyWith(color: colors.faint)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
      // LsDesktopLayout already pads the aside; a Column keeps the QR caption and
      // the settings in one scroll flow instead of a nested scrollable.
      aside: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (busy || networkState.localIps.isEmpty || port == null)
            _QrPlaceholder(busy: busy)
          else
            _QrPanel(
              url: '$scheme://$selectedIp:$port',
              urlWithPin: switch (pin) {
                String() => '$scheme://$selectedIp:$port/?pin=${Uri.encodeQueryComponent(pin)}',
                null => '$scheme://$selectedIp:$port',
              },
              pin: pin,
              listenIncoming: _sendMode,
            ),
          const SizedBox(height: 16),
          LsSectionLabel(label: t.general.settings),
          LsCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: _settingsColumn(context, webDownloadState: webDownloadState, dense: true),
          ),
        ],
      ),
    );
  }

  /// Title, file summary and the panel's own close control (the panel has no back arrow).
  Widget _panelHeader(BuildContext context) {
    final tokens = context.ls;
    final files = widget.files;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_sendMode ? t.webSharePage.title : t.webReceivePage.title, style: tokens.pageTitle),
                if (files != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${t.transferTab.items(n: files.length)}  ${files.fold<int>(0, (sum, file) => sum + file.size).asReadableFileSize}',
                    style: tokens.monoSm,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          LsIconButton(icon: LucideIcons.x, tooltip: t.general.close, onPressed: _stop),
        ],
      ),
    );
  }

  /// Compact progress line, so a settings toggle does not blank the whole panel.
  Widget _panelBusy(BuildContext context) {
    final tokens = context.ls;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: tokens.colors.accent),
          ),
          const SizedBox(width: 10),
          Text(
            _stateEnum == _ServerState.initializing ? t.webSharePage.loading : t.webSharePage.stopping,
            style: tokens.bodySm,
          ),
        ],
      ),
    );
  }

  Widget _panelError(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: LsCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.alertCircle, size: 18, color: colors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.webSharePage.error, style: tokens.bodyStrong),
                  if (_initializedError != null) ...[
                    const SizedBox(height: 4),
                    SelectableText(_initializedError!, style: tokens.bodySm),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ shared parts

  Widget _linksCard(
    BuildContext context, {
    required int? port,
    required List<String> localIps,
    required String? pin,
    bool showQr = true,

    /// Index of the address the desktop aside QR currently shows; its row keeps
    /// the QR button lit.
    int? selectedIp,

    /// Picks the aside QR's address instead of opening a QR dialog. Only the
    /// desktop panel passes this.
    ValueChanged<int>? onSelectIp,
  }) {
    final colors = context.ls.colors;
    final scheme = _encrypted ? 'https' : 'http';
    if (port == null) {
      return const SizedBox.shrink();
    }
    return LsCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < localIps.length; i++) ...[
            if (i > 0) Divider(color: colors.line, height: 1),
            _LinkRow(
              url: '$scheme://${localIps[i]}:$port',
              urlWithPin: switch (pin) {
                String() => '$scheme://${localIps[i]}:$port/?pin=${Uri.encodeQueryComponent(pin)}',
                null => '$scheme://${localIps[i]}:$port',
              },
              pin: pin,
              listenIncoming: _sendMode,
              showQr: showQr,
              selected: i == selectedIp,
              onQrTap: onSelectIp == null ? null : () => onSelectIp(i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _expiresHint(BuildContext context) {
    final tokens = context.ls;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(t.webSharePage.expiresHint, style: tokens.bodySm.copyWith(color: tokens.colors.faint)),
    );
  }

  List<Widget> _requestsSection(BuildContext context, WebDownloadState? webDownloadState) {
    if (webDownloadState == null) {
      return const [];
    }
    final tokens = context.ls;
    return [
      LsSectionLabel(label: t.webSharePage.requests),
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
    ];
  }

  /// The three switches of the panel's settings card. [dense] tightens the rows,
  /// which the 300px aside needs: three rows plus two dividers filled the card.
  Widget _settingsColumn(BuildContext context, {required WebDownloadState? webDownloadState, bool dense = false}) {
    final rowPadding = dense ? 6.0 : 10.0;
    final tokens = context.ls;
    final colors = tokens.colors;
    final settings = context.watch(settingsProvider);
    final pin = context.watch(serverProvider)?.web?.pin;

    return Column(
      children: [
        _settingRow(
          context,
          verticalPadding: rowPadding,
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
          verticalPadding: rowPadding,
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
          verticalPadding: rowPadding,
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
    );
  }

  Widget _settingRow(
    BuildContext context, {
    required String label,
    String? description,
    Widget? value,
    required Widget trailing,

    /// Space above and below the row; the desktop aside passes a tighter one.
    double verticalPadding = 10,
  }) {
    final tokens = context.ls;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
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

void _copyLink(BuildContext context, String url) {
  Clipboard.setData(ClipboardData(text: url)); // ignore: discarded_futures
  if (context.mounted) {
    context.showSnackBar(t.general.copiedToClipboard);
  }
}

class _LinkRow extends StatelessWidget {
  final String url;
  final String urlWithPin;
  final String? pin;
  final bool listenIncoming;

  /// Shows the QR button. On mobile it opens a QR dialog; on desktop it hands
  /// the tap to [onQrTap], which points the aside QR at this row's address.
  final bool showQr;

  /// This row's address is the one the aside QR shows.
  final bool selected;

  /// Desktop only: replaces the QR dialog with a pick of the aside QR's address.
  final VoidCallback? onQrTap;

  const _LinkRow({
    required this.url,
    required this.urlWithPin,
    required this.pin,
    required this.listenIncoming,
    this.showQr = true,
    this.selected = false,
    this.onQrTap,
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
          if (showQr) ...[
            const SizedBox(width: 2),
            LsIconButton(
              icon: LucideIcons.qrCode,
              tooltip: t.webSharePage.title,
              active: selected,
              onPressed: () async {
                final onQrTap = this.onQrTap;
                if (onQrTap != null) {
                  onQrTap();
                  return;
                }
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
          ],
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

/// The always-visible QR of the desktop aside. Clicking it opens the full-screen
/// [ZoomDialog], which is what the QR button of the mobile link row opens directly.
class _QrPanel extends StatelessWidget {
  final String url;
  final String urlWithPin;
  final String? pin;
  final bool listenIncoming;

  const _QrPanel({
    required this.url,
    required this.urlWithPin,
    required this.pin,
    required this.listenIncoming,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Column(
      children: [
        Tooltip(
          message: t.general.open,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () async {
                await showDialog(
                  context: context,
                  builder: (_) => ZoomDialog(
                    label: url,
                    listenIncomingWebDownloadRequests: listenIncoming,
                    pin: pin,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.bg,
                  borderRadius: tokens.cardRadius,
                  border: Border.all(color: colors.line, width: tokens.hairlineOf(context)),
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: PrettyQrView.data(
                    errorCorrectLevel: QrErrorCorrectLevel.Q,
                    data: urlWithPin,
                    decoration: PrettyQrDecoration(
                      shape: PrettyQrSmoothSymbol(
                        roundFactor: 0,
                        color: colors.fg,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.monoSm,
              ),
            ),
            const SizedBox(width: 8),
            LsChip.text(t.general.copy, accent: true, onTap: () => _copyLink(context, urlWithPin)),
          ],
        ),
      ],
    );
  }
}

class _QrPlaceholder extends StatelessWidget {
  final bool busy;

  const _QrPlaceholder({required this.busy});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: tokens.cardRadius,
          border: Border.all(color: colors.line, width: tokens.hairlineOf(context)),
        ),
        child: Center(
          child: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.faint),
                )
              : Icon(LucideIcons.qrCode, size: 40, color: colors.faint),
        ),
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
