import 'package:flutter/material.dart';

/// One-line text for a file system path that keeps the *tail* visible.
///
/// A folder is identified by its last segments, yet [TextOverflow.ellipsis] cuts
/// exactly those and keeps the drive letter and the user name instead
/// (`/home/s…`). This measures the text and elides the head instead
/// (`…/Pictures/LocalSend`), cutting at a separator so no segment is shown
/// half-way. The full path stays reachable through a tooltip.
class LsPathText extends StatelessWidget {
  final String path;
  final TextStyle? style;

  const LsPathText(this.path, {this.style, super.key});

  @override
  Widget build(BuildContext context) {
    final measuredStyle = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final text = constraints.maxWidth.isFinite ? _fitTail(path, measuredStyle, scaler, constraints.maxWidth) : path;
        return Tooltip(
          message: path,
          child: Text(text, maxLines: 1, softWrap: false, style: style),
        );
      },
    );
  }
}

const String _ellipsis = '…';

/// The longest tail of [path] that fits into [maxWidth], prefixed with an ellipsis.
String _fitTail(String path, TextStyle style, TextScaler scaler, double maxWidth) {
  if (maxWidth <= 0 || _width(path, style, scaler) <= maxWidth) {
    return path;
  }
  // Cut at a separator first: half a folder name reads as a typo.
  for (var index = 0; index < path.length - 1; index++) {
    final char = path[index];
    if (char != '/' && char != r'\') {
      continue;
    }
    final candidate = '$_ellipsis${path.substring(index)}';
    if (_width(candidate, style, scaler) <= maxWidth) {
      return candidate;
    }
  }
  // A single segment wider than the row (a long file name, a network share):
  // trim characters, keeping the rightmost ones.
  var best = _ellipsis;
  var low = 1;
  var high = path.length;
  while (low <= high) {
    final count = (low + high) ~/ 2;
    final candidate = '$_ellipsis${path.substring(path.length - count)}';
    if (_width(candidate, style, scaler) <= maxWidth) {
      best = candidate;
      low = count + 1;
    } else {
      high = count - 1;
    }
  }
  return best;
}

double _width(String text, TextStyle style, TextScaler scaler) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
