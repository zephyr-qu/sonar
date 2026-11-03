/// Whether [input] is a bare IPv4 or IPv6 address literal.
///
/// An IPv6 literal may carry a zone/scope suffix (e.g. `fe80::1%3`), because the
/// core keeps that form as a dialable host (`PeerIp`). Hostnames are rejected on
/// purpose: every caller of this helper asks the user for an address, not a name.
bool isValidIpAddress(String input) {
  var address = input.trim();
  final zoneIndex = address.indexOf('%');
  if (zoneIndex != -1) {
    final zone = address.substring(zoneIndex + 1);
    address = address.substring(0, zoneIndex);
    // A zone only makes sense on an IPv6 literal, and it must not be blank.
    if (!address.contains(':') || zone.isEmpty || zone.trim() != zone) {
      return false;
    }
  }

  return address.contains(':') ? _isValidIpv6(address) : _isValidIpv4(address);
}

/// Whether [input] is the last octet of an IPv4 address, i.e. the `#` short
/// number the address dialog accepts.
///
/// The dialog assumes a /24 (it only knows the first three octets of the local
/// interfaces), so `0` (network) and `255` (broadcast) are not usable hosts.
bool isValidIpv4HostPart(String input) {
  final part = input.trim();
  if (part.isEmpty || part.length > 3) {
    return false;
  }
  if (part.length > 1 && part.startsWith('0')) {
    return false;
  }
  for (var i = 0; i < part.length; i++) {
    final code = part.codeUnitAt(i);
    if (code < 0x30 || code > 0x39) {
      return false;
    }
  }

  final value = int.parse(part);
  return value >= 1 && value <= 254;
}

bool _isValidIpv4(String address) {
  final parts = address.split('.');
  if (parts.length != 4) {
    return false;
  }

  for (final part in parts) {
    if (part.isEmpty || part.length > 3) {
      return false;
    }
    if (part.length > 1 && part.startsWith('0')) {
      // Leading zeros are ambiguous (octal on some hosts), so reject them.
      return false;
    }
    for (var i = 0; i < part.length; i++) {
      final code = part.codeUnitAt(i);
      if (code < 0x30 || code > 0x39) {
        return false;
      }
    }
    if (int.parse(part) > 255) {
      return false;
    }
  }

  return true;
}

bool _isValidIpv6(String address) {
  final halves = address.split('::');
  if (halves.length > 2) {
    return false;
  }

  if (halves.length == 1) {
    return _ipv6GroupCount(halves.first, allowTrailingIpv4: true) == 8;
  }

  var groups = 0;
  if (halves[0].isNotEmpty) {
    final count = _ipv6GroupCount(halves[0], allowTrailingIpv4: false);
    if (count < 0) {
      return false;
    }
    groups += count;
  }
  if (halves[1].isNotEmpty) {
    final count = _ipv6GroupCount(halves[1], allowTrailingIpv4: true);
    if (count < 0) {
      return false;
    }
    groups += count;
  }

  // `::` stands for at least one all-zero group.
  return groups <= 7;
}

/// Number of 16-bit groups encoded by [part] (`-1` when invalid).
///
/// A dotted IPv4 tail (`::ffff:192.168.0.1`) counts as two groups and is only
/// allowed where the caller says it may appear.
int _ipv6GroupCount(String part, {required bool allowTrailingIpv4}) {
  final groups = part.split(':');
  var count = 0;
  for (var i = 0; i < groups.length; i++) {
    final group = groups[i];
    if (allowTrailingIpv4 && i == groups.length - 1 && group.contains('.')) {
      if (!_isValidIpv4(group)) {
        return -1;
      }
      count += 2;
      continue;
    }
    if (group.isEmpty || group.length > 4) {
      return -1;
    }
    for (var j = 0; j < group.length; j++) {
      final code = group.codeUnitAt(j);
      final isDigit = code >= 0x30 && code <= 0x39;
      final isHexLetter = (code >= 0x61 && code <= 0x66) || (code >= 0x41 && code <= 0x46);
      if (!isDigit && !isHexLetter) {
        return -1;
      }
    }
    count += 1;
  }

  return count;
}
