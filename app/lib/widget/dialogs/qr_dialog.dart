import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/theme.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/state/send/web/web_download_state.dart';
import 'package:sonar/provider/network/server/server_provider.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';

class QrDialog extends StatelessWidget {
  final String data;
  final String? label;
  final bool listenIncomingWebDownloadRequests;
  final String? pin;

  const QrDialog({
    required this.data,
    this.label,
    this.listenIncomingWebDownloadRequests = false,
    this.pin,
  });

  @override
  Widget build(BuildContext context) {
    final WebDownloadState? webDownloadState;
    if (listenIncomingWebDownloadRequests) {
      webDownloadState = context.ref.watch(serverProvider.select((s) => s?.webDownloadState));
    } else {
      webDownloadState = null;
    }

    return LsDialog(
      title: Text(t.dialogs.qr.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: 200,
              height: 200,
              child: PrettyQrView.data(
                errorCorrectLevel: QrErrorCorrectLevel.Q,
                data: data,
                decoration: PrettyQrDecoration(
                  shape: PrettyQrSmoothSymbol(
                    roundFactor: 0,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(label ?? data, textAlign: TextAlign.center),
          if (listenIncomingWebDownloadRequests && webDownloadState != null)
            Builder(
              builder: (context) {
                final pending = webDownloadState?.sessions.values.fold<int>(0, (prev, curr) => prev + (curr.pending ? 1 : 0)) ?? 0;
                if (pending != 0) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      t.webSharePage.pendingRequests(n: pending),
                      style: TextStyle(color: Theme.of(context).colorScheme.warning),
                      textAlign: TextAlign.center,
                    ),
                  );
                } else {
                  return Container();
                }
              },
            ),
          if (pin != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.key),
                  const SizedBox(width: 5),
                  Text(pin!),
                ],
              ),
            ),
        ],
      ),
      onClose: () => context.pop(),
    );
  }
}
