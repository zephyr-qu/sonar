import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonar/model/persistence/favorite_device.dart';
import 'package:sonar_isolates/model/device.dart';

void main() {
  test('Should keep the device type across a serialize round-trip', () {
    final favorite = FavoriteDevice.fromValues(
      fingerprint: 'fingerprint',
      ip: '192.168.1.2',
      port: 53317,
      alias: 'Tablet',
      deviceType: DeviceType.tablet,
    );

    final restored = FavoriteDevice.fromJson(jsonDecode(favorite.serialize()) as Map<String, dynamic>);

    expect(restored.deviceType, DeviceType.tablet);
    expect(restored, favorite);
  });

  // The offline favorites grid used to hard-code the desktop glyph. Entries saved before the device
  // type was persisted have no `deviceType` key at all, and they must keep decoding — as desktop,
  // which is the glyph they were shown with until now.
  test('Should decode an entry saved without a device type as desktop', () {
    final restored = FavoriteDevice.fromJson(const {
      'id': 'device-id',
      'fingerprint': 'fingerprint',
      'ip': '192.168.1.2',
      'port': 53317,
      'alias': 'Phone',
      'customAlias': false,
    });

    expect(restored.deviceType, DeviceType.desktop);
    expect(restored.alias, 'Phone');
  });
}
