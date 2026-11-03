import 'package:sonar/util/ip_address.dart';
import 'package:test/test.dart';

void main() {
  group('isValidIpAddress (IPv4)', () {
    test('accepts a dotted quad', () {
      expect(isValidIpAddress('192.168.2.1'), true);
      expect(isValidIpAddress('0.0.0.0'), true);
      expect(isValidIpAddress('255.255.255.255'), true);
      expect(isValidIpAddress('  10.0.0.1  '), true);
    });

    test('rejects out of range octets', () {
      expect(isValidIpAddress('256.0.0.1'), false);
      expect(isValidIpAddress('192.168.2.999'), false);
    });

    test('rejects wrong group counts', () {
      expect(isValidIpAddress('192.168.2'), false);
      expect(isValidIpAddress('192.168.2.1.5'), false);
      expect(isValidIpAddress('192.168.2.'), false);
    });

    test('rejects non-numeric and ambiguous octets', () {
      expect(isValidIpAddress('192.168.2.abc'), false);
      expect(isValidIpAddress('192.168.-1.1'), false);
      expect(isValidIpAddress('192.168.001.1'), false);
      expect(isValidIpAddress(''), false);
      expect(isValidIpAddress('localhost'), false);
    });
  });

  group('isValidIpAddress (IPv6)', () {
    test('accepts full and compressed forms', () {
      expect(isValidIpAddress('1::1'), true);
      expect(isValidIpAddress('::1'), true);
      expect(isValidIpAddress('::'), true);
      expect(isValidIpAddress('2001:0db8:85a3:0000:0000:8a2e:0370:7334'), true);
      expect(isValidIpAddress('2001:db8::8a2e:370:7334'), true);
      expect(isValidIpAddress('FE80::1'), true);
    });

    test('accepts a dotted IPv4 tail', () {
      expect(isValidIpAddress('::ffff:192.168.2.1'), true);
      expect(isValidIpAddress('::ffff:192.168.2.999'), false);
    });

    test('rejects malformed forms', () {
      expect(isValidIpAddress('1:::1'), false);
      expect(isValidIpAddress('1::2::3'), false);
      expect(isValidIpAddress('2001:db8:0:0:0:0:0:0:1'), false);
      expect(isValidIpAddress('12345::1'), false);
      expect(isValidIpAddress('gggg::1'), false);
      expect(isValidIpAddress(':1::2'), false);
      expect(isValidIpAddress('1:2:3:4:5:6:7'), false);
    });
  });

  group('isValidIpAddress (zone)', () {
    test('accepts a scope id on IPv6 only', () {
      expect(isValidIpAddress('fe80::1%3'), true);
      expect(isValidIpAddress('fe80::1%eth0'), true);
      expect(isValidIpAddress('fe80::1%'), false);
      expect(isValidIpAddress('192.168.2.1%3'), false);
    });
  });

  group('isValidIpv4HostPart', () {
    test('accepts usable host numbers', () {
      expect(isValidIpv4HostPart('1'), true);
      expect(isValidIpv4HostPart('123'), true);
      expect(isValidIpv4HostPart('254'), true);
      expect(isValidIpv4HostPart(' 42 '), true);
    });

    test('rejects network, broadcast and out of range values', () {
      expect(isValidIpv4HostPart('0'), false);
      expect(isValidIpv4HostPart('255'), false);
      expect(isValidIpv4HostPart('256'), false);
      expect(isValidIpv4HostPart('9999'), false);
    });

    test('rejects malformed input', () {
      expect(isValidIpv4HostPart(''), false);
      expect(isValidIpv4HostPart('012'), false);
      expect(isValidIpv4HostPart('12a'), false);
      expect(isValidIpv4HostPart('-1'), false);
      expect(isValidIpv4HostPart('1.2'), false);
    });
  });
}
