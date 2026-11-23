import 'package:flutter_test/flutter_test.dart';
import 'package:sonar/util/transfer_failure.dart';

void main() {
  test('a session error names the request and wins over per-file reasons', () {
    expect(
      transferFailureReason(
        sessionError: 'The other device did not respond.',
        files: [('a.jpg', 'connection reset')],
      ),
      'The other device did not respond.',
    );
  });

  test('a per-file reason is reported with its file name', () {
    expect(
      transferFailureReason(files: [('a.jpg', null), ('b.jpg', 'disk full')]),
      'b.jpg: disk full',
    );
  });

  test('nothing failed means no reason', () {
    expect(transferFailureReason(files: [('a.jpg', null)]), isNull);
    expect(transferFailureReason(sessionError: '   '), isNull);
    expect(transferFailureReason(), isNull);
  });
}
