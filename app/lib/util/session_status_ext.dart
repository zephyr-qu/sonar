import 'package:sonar/gen/strings.g.dart';
import 'package:sonar_isolates/model/session_status.dart';

/// What a session status means for the UI.
extension SessionStatusInfo on SessionStatus {
  /// The receiver answered the request without accepting it, so no file moved.
  bool get isRefused => this == SessionStatus.declined || this == SessionStatus.recipientBusy || this == SessionStatus.tooManyAttempts;

  /// A session that ended badly, whether a transfer ran or not.
  ///
  /// These keep a card until they are dismissed, in the Transfers tab and as the
  /// single newest failure in the desktop sidebar.
  bool get isTerminalFailure => this == SessionStatus.finishedWithErrors || isRefused;
}

/// One-line label of a session status, or `null` for a running transfer, which
/// shows progress instead of a status.
String? sessionStatusText(SessionStatus status) {
  return switch (status) {
    SessionStatus.waiting => t.sendPage.waiting,
    SessionStatus.recipientBusy => t.sendPage.busy,
    SessionStatus.declined => t.sendPage.rejected,
    SessionStatus.tooManyAttempts => t.sendPage.tooManyAttempts,
    SessionStatus.sending => null,
    SessionStatus.finished => t.general.finished,
    SessionStatus.finishedWithErrors => t.progressPage.total.title.finishedError,
    SessionStatus.canceledBySender => t.progressPage.total.title.canceledSender,
    SessionStatus.canceledByReceiver => t.progressPage.total.title.canceledReceiver,
  };
}
