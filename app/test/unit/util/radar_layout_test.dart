import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonar/util/radar_layout.dart';

(double, double) _center(RadarSlot slot) => (
  math.cos(slot.angle * math.pi / 180) * slot.radius,
  math.sin(slot.angle * math.pi / 180) * slot.radius,
);

double _distance(RadarSlot a, RadarSlot b) {
  final (ax, ay) = _center(a);
  final (bx, by) = _center(b);
  return math.sqrt(math.pow(ax - bx, 2) + math.pow(ay - by, 2));
}

void main() {
  group('layoutRadarSlots', () {
    test('returns no slots without devices', () {
      expect(layoutRadarSlots(onlineCount: 0), isEmpty);
    });

    test('spreads online devices evenly and alternates the two orbits', () {
      final slots = layoutRadarSlots(onlineCount: 5);

      expect(slots, hasLength(5));
      expect(slots.map((slot) => slot.angle), [-90.0, -18.0, 54.0, 126.0, 198.0]);
      expect(slots.map((slot) => slot.radius), [radarInnerRadius, radarOuterRadius, radarInnerRadius, radarOuterRadius, radarInnerRadius]);
      expect(slots.every((slot) => !slot.offline), isTrue);
    });

    test('gives a lone device the full bubble, because it has no depth to compare', () {
      final slots = layoutRadarSlots(onlineCount: 1);

      expect(slots.single.size, radarPeerSizeRange(1).max);
    });

    test('makes the bottom-most device the biggest one', () {
      final slots = layoutRadarSlots(onlineCount: 5);
      final sizes = slots.map((slot) => slot.size).toList();

      expect(sizes.reduce(math.max), radarPeerSizeRange(5).max);
      expect(sizes.reduce(math.min), radarPeerSizeRange(5).min);
      // index 3 sits at 90° (bottom of the screen) and reads as the closest device
      expect(slots[3].size, sizes.reduce(math.max));
    });

    test('keeps the offline favorite as its own last slot', () {
      final slots = layoutRadarSlots(onlineCount: 5, hasOffline: true);

      expect(slots, hasLength(6));
      expect(slots.last.offline, isTrue);
      expect(slots.last.radius, radarOfflineRadius);
      expect(slots.last.size, radarPeerSizeRange(5).min);
      // 6 slots -> 60° each, so the favorite takes the one after the last online device
      expect(slots.last.angle, closeTo(-90 + 60 * 5, 0.001));
    });

    test('keeps the familiar top-left spot when only the favorite exists', () {
      final slots = layoutRadarSlots(onlineCount: 0, hasOffline: true);

      expect(slots, hasLength(1));
      expect(slots.single.offline, isTrue);
      expect(slots.single.angle, 215);
      expect(slots.single.radius, radarOfflineRadius);
    });

    test('shrinks the bubbles once six online devices share the radar', () {
      expect(radarPeerSizeRange(5), (max: 60.0, min: 36.0));
      expect(radarPeerSizeRange(6), (max: 54.0, min: 34.0));
      expect(maxRadarOnlineDevices, 6);
    });

    for (final (onlineCount, hasOffline) in [(5, true), (6, true), (6, false)]) {
      test('leaves room between every pair of bubbles ($onlineCount online, offline: $hasOffline)', () {
        final slots = layoutRadarSlots(onlineCount: onlineCount, hasOffline: hasOffline);

        expect(slots, hasLength(onlineCount + (hasOffline ? 1 : 0)));
        for (var i = 0; i < slots.length; i++) {
          for (var j = i + 1; j < slots.length; j++) {
            final gap = _distance(slots[i], slots[j]) - (slots[i].size + slots[j].size) / 2;
            expect(gap, greaterThan(40), reason: 'slots $i and $j are too close ($gap px apart)');
          }
        }
      });
    }
  });
}
