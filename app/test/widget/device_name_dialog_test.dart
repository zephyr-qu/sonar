import 'package:flutter_test/flutter_test.dart';
import 'package:sonar/widget/dialogs/device_name_dialog.dart';

void main() {
  group('validateDeviceName', () {
    test('accepts a plain name', () {
      expect(validateDeviceName('My Device'), isNull);
    });

    test('rejects an empty or blank name', () {
      expect(validateDeviceName(''), isNotNull);
      expect(validateDeviceName('   '), isNotNull);
    });

    test('accepts a name at the length limit and rejects one over it', () {
      expect(validateDeviceName('a' * maxDeviceNameLength), isNull);
      expect(validateDeviceName('a' * (maxDeviceNameLength + 1)), isNotNull);
    });

    test('measures the name without its surrounding whitespace', () {
      expect(validateDeviceName('  My Device  '), isNull);
      expect(validateDeviceName('  ${'a' * (maxDeviceNameLength + 1)}  '), isNotNull);
    });

    test('rejects a name carrying control characters', () {
      expect(validateDeviceName('My\nDevice'), isNotNull);
      expect(validateDeviceName('My\tDevice'), isNotNull);
      expect(validateDeviceName('My\x7fDevice'), isNotNull);
    });
  });
}
