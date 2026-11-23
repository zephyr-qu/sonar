import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sonar/config/design_tokens.dart';

/// Pull-to-refresh as a single hairline: dragging the list past its top edge grows a 1px line out of the
/// centre, and releasing it once the line is at full length fires [onRefresh].
///
/// Deliberately not a [RefreshIndicator]. That one wraps the gesture in a material spinner — a foreign
/// element in this palette — and holds it open until the returned future completes, so work that keeps
/// running after the visible result is already there (a staged network scan) leaves the spinner turning
/// long after the refresh looks done. Here the line fades the moment the finger lifts, and [onRefresh]
/// returns immediately.
///
/// The child's scroll view must use [AlwaysScrollableScrollPhysics]: otherwise a list shorter than the
/// viewport — a near-empty device grid — swallows the drag and nothing can ever be refreshed.
class LsRefreshIndicator extends StatefulWidget {
  /// Fired once per armed release. Not awaited: the indicator retracts right away, so the work may
  /// take as long as it actually takes without the gesture tracking it.
  final VoidCallback onRefresh;

  final Widget child;

  /// How far (logical pixels) the list has to be pulled past its top edge to arm the refresh.
  final double threshold;

  const LsRefreshIndicator({
    required this.onRefresh,
    required this.child,
    this.threshold = 56,
  });

  @override
  State<LsRefreshIndicator> createState() => _LsRefreshIndicatorState();
}

/// The line is one hairline centred in a 3px strip, so nothing is clipped when it grows.
const double _stripHeight = 3;

/// Longest the line gets, centred, at which point the pull is armed. Deliberately short of the screen
/// width: the gesture is a hint, not a progress bar.
const double _maxWidth = 152;

class _LsRefreshIndicatorState extends State<LsRefreshIndicator> with SingleTickerProviderStateMixin {
  /// Progress of the current pull (0 hidden, 1 armed) and the opacity of the line. They move together
  /// while dragging and part ways on release: the line keeps its length and only fades, which reads as
  /// "done" instead of "cancelled".
  final ValueNotifier<(double, double)> _state = ValueNotifier<(double, double)>((0, 0));

  /// Drives the fade after the finger lifts.
  late final AnimationController _retract = AnimationController(vsync: this, duration: const Duration(milliseconds: 180))
    ..addListener(_onRetractTick);

  double _retractFrom = 1;

  /// Drag distance past the top edge reported as rejected overscroll (clamping physics). Bouncing
  /// physics instead lets [ScrollMetrics.pixels] go negative, which is read directly.
  double _overscroll = 0;

  bool _pulling = false;

  double get _progress => _state.value.$1;

  @override
  void dispose() {
    _retract.dispose();
    _state.dispose();
    super.dispose();
  }

  void _onRetractTick() {
    if (_retract.isCompleted) {
      // Length is reset only once the line is invisible, so the fade never shrinks it under the eye.
      _state.value = (0, 1);
    } else {
      _state.value = (_progress, _retractFrom * (1 - _retract.value));
    }
  }

  void _setProgress(double progress) {
    if (progress != _progress) {
      _state.value = (progress, 1);
    }
  }

  void _retractLine() {
    _retractFrom = _state.value.$2;
    _retract.stop();
    unawaited(_retract.forward(from: 0));
  }

  bool _onNotification(ScrollNotification notification) {
    // Only the page's own list drives the gesture; the nested file grid never scrolls.
    if (notification.depth != 0) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      if (notification.dragDetails == null) {
        return false;
      }
      _pulling = true;
      _overscroll = 0;
      _retract.stop();
      _state.value = (0, 1);
      return false;
    }

    if (!_pulling) {
      return false;
    }

    if (notification is ScrollEndNotification) {
      _pulling = false;
      final armed = _progress >= 1;
      _retractLine();
      if (armed) {
        widget.onRefresh();
      }
      return false;
    }

    final metrics = notification.metrics;
    if (metrics.pixels > metrics.minScrollExtent) {
      _overscroll = 0;
    } else if (notification is OverscrollNotification && notification.overscroll < 0) {
      _overscroll -= notification.overscroll;
    }

    final beyondTop = math.max(_overscroll, metrics.minScrollExtent - metrics.pixels);
    _setProgress((beyondTop / widget.threshold).clamp(0.0, 1.0));
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ls.colors;
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onNotification,
          child: widget.child,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: ValueListenableBuilder<(double, double)>(
              valueListenable: _state,
              builder: (context, state, _) {
                final (progress, alpha) = state;
                if (progress <= 0 || alpha <= 0) {
                  return const SizedBox(height: _stripHeight);
                }
                final armed = progress >= 1;
                return SizedBox(
                  height: _stripHeight,
                  child: Center(
                    child: SizedBox(
                      key: const ValueKey('ls_refresh_line'),
                      width: _maxWidth * progress,
                      height: 1,
                      child: ColoredBox(
                        // Neutral white while pulling, the signal accent the moment the pull is armed:
                        // that colour change is the only "go" cue the gesture has.
                        color: armed ? colors.accent.withValues(alpha: alpha) : colors.fg.withValues(alpha: alpha * (0.18 + 0.32 * progress)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
