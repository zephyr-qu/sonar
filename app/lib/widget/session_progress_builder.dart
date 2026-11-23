import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/provider/file_transfer_provider.dart';

/// Rebuilds only [builder] when the progress of [sessionId] changes.
///
/// Progress events arrive up to 50 times per second, so watching
/// [fileTransferProvider] would rebuild the whole page (on the transfer tab
/// including a full regrouping of the history, in the tray the whole sidebar)
/// for every single tick.
class SessionProgressBuilder extends StatelessWidget {
  final String sessionId;
  final Widget Function(BuildContext context, FileTransferNotifier transfer) builder;

  const SessionProgressBuilder({required this.sessionId, required this.builder, super.key});

  @override
  Widget build(BuildContext context) {
    final transfer = context.ref.read(fileTransferProvider);
    return ValueListenableBuilder<int>(
      valueListenable: transfer.sessionTick(sessionId),
      builder: (context, _, _) => builder(context, transfer),
    );
  }
}
