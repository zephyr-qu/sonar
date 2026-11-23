import 'package:flutter/material.dart';

/// Paints a dashed rounded rectangle or circle outline (the prototype uses
/// dashed borders for the "add file" tile, the radar rim and offline peers).
class LsDashedBox extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final Color color;
  final double strokeWidth;

  const LsDashedBox({
    required this.child,
    required this.color,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.strokeWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedPathPainter(
        pathBuilder: (size) => Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, borderRadius.topLeft)),
        color: color,
        dashLength: 4,
        gapLength: 3,
        strokeWidth: strokeWidth,
      ),
      child: child,
    );
  }
}

/// A dashed circle of a fixed size.
class LsDashedRing extends StatelessWidget {
  final double size;
  final Color color;

  const LsDashedRing({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _DashedPathPainter(
        pathBuilder: (s) => Path()..addOval(Offset.zero & s),
        color: color,
        dashLength: 5,
        gapLength: 4,
        strokeWidth: 1,
      ),
    );
  }
}

class _DashedPathPainter extends CustomPainter {
  final Path Function(Size size) pathBuilder;
  final Color color;
  final double dashLength;
  final double gapLength;
  final double strokeWidth;

  /// Dash segments of the last painted geometry. An animating radar repaints
  /// this ring far more often than its geometry changes, so the segments are
  /// extracted once and reused instead of on every frame.
  final _DashCache _cache = _DashCache();

  _DashedPathPainter({
    required this.pathBuilder,
    required this.color,
    required this.dashLength,
    required this.gapLength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final dash in _cache.segment(size, dashLength, gapLength, pathBuilder)) {
      canvas.drawPath(dash, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPathPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Memoizes the dash segments of one painter, so [CustomPainter.paint] only
/// splits the path again when the geometry actually changes.
class _DashCache {
  Size? _size;
  double? _dashLength;
  double? _gapLength;
  List<Path> _dashes = const [];

  List<Path> segment(Size size, double dashLength, double gapLength, Path Function(Size size) pathBuilder) {
    if (_size == size && _dashLength == dashLength && _gapLength == gapLength) {
      return _dashes;
    }

    final dashes = <Path>[];
    final path = pathBuilder(size);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dashLength).clamp(0.0, metric.length).toDouble();
        dashes.add(metric.extractPath(distance, next));
        distance = next + gapLength;
      }
    }

    _size = size;
    _dashLength = dashLength;
    _gapLength = gapLength;
    _dashes = List.unmodifiable(dashes);
    return _dashes;
  }
}
