import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Styling of the toast lives in `SnackBarThemeData` (see `config/theme.dart`);
/// this only decides the width and the lifetime.
const _toastDuration = Duration(milliseconds: 3000);
const _toastPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 10);
const _minToastWidth = 96.0;
const _maxToastWidth = 420.0;

/// Horizontal `SnackBarThemeData.insetPadding`, needed to know how much room a
/// floating toast has.
const _toastInset = 24.0;

double _clamp(double value, double min, double max) => math.min(math.max(value, min), max);

extension SnackbarExt on BuildContext {
  void showSnackBar(String text) {
    final scaffold = ScaffoldMessenger.of(this);
    scaffold.removeCurrentSnackBar();
    scaffold.showSnackBar(
      SnackBar(
        content: Text(text, textAlign: TextAlign.center),
        padding: _toastPadding,
        width: _toastWidth(text),
        duration: _toastDuration,
      ),
    );
  }

  /// Width that lets the toast hug its text.
  ///
  /// A floating [SnackBar] without an explicit width stretches across the whole
  /// window (minus the inset padding), which is what makes it look like the
  /// stock platform toast on a desktop-sized window. Long messages still wrap
  /// inside [_maxToastWidth].
  double _toastWidth(String text) {
    final style = Theme.of(this).snackBarTheme.contentTextStyle ?? const TextStyle();
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(this),
      textScaler: MediaQuery.textScalerOf(this),
    )..layout();
    final measured = painter.width;
    painter.dispose();

    final available = MediaQuery.sizeOf(this).width - 2 * _toastInset;
    final maxWidth = _clamp(available, _minToastWidth, _maxToastWidth);
    // + 2 keeps the centred text clear of the hairline border.
    return _clamp(measured + _toastPadding.horizontal + 2, _minToastWidth, maxWidth);
  }
}
