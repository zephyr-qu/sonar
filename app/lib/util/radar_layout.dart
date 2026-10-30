import 'dart:math' as math;

/// One slot on the nearby radar: where a device sits and how big its bubble is.
class RadarSlot {
  /// Degrees, 0 = right, 90 = down (screen coordinates).
  final double angle;

  /// Distance from the radar center, in logical pixels.
  final double radius;

  /// Diameter of the device bubble, in logical pixels.
  final double size;

  /// Whether this slot belongs to the offline favorite instead of a reachable device.
  final bool offline;

  const RadarSlot({
    required this.angle,
    required this.radius,
    required this.size,
    this.offline = false,
  });
}

/// How many online devices the radar shows before falling back to the "x of y shown" hint.
///
/// Six is the measured ceiling for the 344 px radar: with seven slots the bubbles are still
/// apart, but the labels start touching (and the near/far size contrast flattens out).
const int maxRadarOnlineDevices = 6;

/// Orbit radii of the radar. Peers alternate between them so neighboring labels do not stack.
const double radarInnerRadius = 108;
const double radarOuterRadius = 130;

/// The offline favorite keeps its own, slightly wider orbit so it reads as "not here".
const double radarOfflineRadius = 148;

/// Bubble size range for [onlineCount] devices.
///
/// More devices -> smaller bubbles, so six peers plus the offline favorite still keep enough
/// room for their labels. The upper bound stays below the 76 px center bubble on purpose.
({double max, double min}) radarPeerSizeRange(int onlineCount) => onlineCount >= maxRadarOnlineDevices ? (max: 54, min: 34) : (max: 60, min: 36);

/// Lays out the radar slots for [onlineCount] devices plus an optional offline favorite.
///
/// Slots are spread evenly over the whole circle, the offline favorite included: parking it at
/// a fixed 215° made the sixth device overlap it by ~18 px. Bubble size follows the screen
/// depth — the lower the slot, the closer it reads and the bigger it gets — interpolated
/// between the [radarPeerSizeRange] bounds.
List<RadarSlot> layoutRadarSlots({required int onlineCount, bool hasOffline = false}) {
  final total = onlineCount + (hasOffline ? 1 : 0);
  if (total == 0) {
    return const [];
  }
  final range = radarPeerSizeRange(onlineCount);
  final step = 360 / total;

  final angles = <double>[
    for (var i = 0; i < onlineCount; i++) -90 + step * i,
  ];
  final radii = <double>[
    for (var i = 0; i < onlineCount; i++) i.isEven ? radarInnerRadius : radarOuterRadius,
  ];
  // y grows downwards, so the bottom-most slot reads as the closest one.
  final depths = <double>[
    for (var i = 0; i < onlineCount; i++) math.sin(angles[i] * math.pi / 180) * radii[i],
  ];
  final yMin = depths.isEmpty ? 0.0 : depths.reduce(math.min);
  final yMax = depths.isEmpty ? 0.0 : depths.reduce(math.max);
  final spread = yMax - yMin;

  final slots = <RadarSlot>[
    for (var i = 0; i < onlineCount; i++)
      RadarSlot(
        angle: angles[i],
        radius: radii[i],
        // A lone device has no depth to compare against, so it gets the full bubble.
        size: spread < 0.001 ? range.max : range.min + (range.max - range.min) * ((depths[i] - yMin) / spread),
      ),
  ];

  if (hasOffline) {
    slots.add(
      RadarSlot(
        // Without any online device there is nothing to distribute: keep the familiar top-left spot.
        angle: onlineCount == 0 ? 215 : -90 + step * onlineCount,
        radius: radarOfflineRadius,
        size: range.min,
        offline: true,
      ),
    );
  }
  return slots;
}
