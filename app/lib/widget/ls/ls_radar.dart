import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/widget/ls/ls_dashed.dart';

/// One device orbiting the radar center.
class LsRadarPeer {
  final Widget child;
  final String label;
  final double angle; // degrees, 0 = right, 90 = down
  final double radius; // distance from the center

  /// Diameter of the bubble; nearer peers are bigger (see `layoutRadarSlots`).
  final double size;
  final bool offline;
  final bool labelAbove;

  /// Multi-select state: accent hairline around the bubble plus a soft accent
  /// wash, matching the selected device tile.
  final bool selected;
  final String? tooltip;
  final VoidCallback? onTap;

  /// Long press enters multi-select (same behaviour as the device grid). When
  /// set, the tooltip is not shown on long press: the gesture belongs to the
  /// selection, and two long-press recognizers would fight over it on Android.
  final VoidCallback? onLongPress;

  const LsRadarPeer({
    required this.child,
    required this.label,
    required this.angle,
    required this.radius,
    this.size = 44,
    this.offline = false,
    this.labelAbove = false,
    this.selected = false,
    this.tooltip,
    this.onTap,
    this.onLongPress,
  });
}

/// The "signal" radar: three rings, a sweeping conic highlight and orbiting peers.
class LsRadar extends StatefulWidget {
  final double size;
  final Widget center;
  final List<LsRadarPeer> peers;
  final bool animate;

  const LsRadar({
    required this.size,
    required this.center,
    this.peers = const [],
    this.animate = true,
  });

  @override
  State<LsRadar> createState() => _LsRadarState();
}

class _LsRadarState extends State<LsRadar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 5500));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant LsRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  /// A reduced-motion system setting outranks [LsRadar.animate]: the sweep is
  /// decoration, and an endless animation is exactly what the setting asks apps
  /// not to run. Stopping the controller also stops the frame callbacks.
  void _syncAnimation() {
    final animate = widget.animate && !MediaQuery.disableAnimationsOf(context);
    if (animate == _controller.isAnimating) {
      return;
    }
    if (animate) {
      unawaited(_controller.repeat());
    } else {
      _controller.stop();
    }
    _animate = animate;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final size = widget.size;
    final radius = size / 2;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // inner rings
          for (final factor in [0.36, 0.62])
            Container(
              width: size * factor,
              height: size * factor,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.line),
              ),
            ),
          // dashed rim
          RepaintBoundary(
            child: LsDashedRing(size: size - 2, color: colors.line),
          ),
          // sweep
          if (_animate)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.rotate(angle: _controller.value * 2 * math.pi, child: child);
              },
              child: RepaintBoundary(
                // The gradient never changes, so it lives in its own layer: the
                // rotation above then only rewrites a transform matrix instead of
                // re-rasterizing the sweep on every animation frame.
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [colors.accent.withValues(alpha: 0.16), colors.accent.withValues(alpha: 0)],
                      stops: const [0, 0.3],
                    ),
                  ),
                ),
              ),
            ),
          widget.center,
          for (final peer in widget.peers)
            Transform.translate(
              offset: Offset(
                math.cos(peer.angle * math.pi / 180) * math.min(peer.radius, radius - peer.size / 2 - 2),
                math.sin(peer.angle * math.pi / 180) * math.min(peer.radius, radius - peer.size / 2 - 2),
              ),
              child: RepaintBoundary(child: _Peer(peer: peer)),
            ),
        ],
      ),
    );
  }
}

class _Peer extends StatelessWidget {
  final LsRadarPeer peer;

  const _Peer({required this.peer});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final size = peer.size;

    final circle = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Selected follows the device tile's `.devcard.is-selected` treatment:
        // accent hairline plus a soft accent wash instead of a solid fill.
        color: peer.selected
            ? colors.accentSoft
            : peer.offline
            ? colors.bg
            : colors.bg2,
        shape: BoxShape.circle,
        border: Border.all(
          color: peer.selected
              ? colors.accent
              : peer.offline
              ? colors.line
              : colors.lineStrong,
          width: peer.selected ? 2 : 1,
        ),
      ),
      child: Opacity(
        opacity: peer.offline ? 0.4 : 1,
        child: IconTheme(
          // Capped below the 24 px center glyph, so the biggest peer never out-shouts "me".
          data: IconThemeData(
            size: (size * 0.36).clamp(13.0, 21.0),
            color: peer.selected ? colors.accentInk : colors.fg,
          ),
          child: peer.child,
        ),
      ),
    );

    final hasLongPress = peer.onLongPress != null;
    Widget button = circle;
    if (peer.onTap != null || hasLongPress) {
      button = Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: peer.onTap,
          onLongPress: peer.onLongPress,
          customBorder: const CircleBorder(),
          child: circle,
        ),
      );
    }
    // A peer that uses long press for multi-select must not also open a tooltip
    // on long press (the two long-press recognizers conflict on touch devices).
    if (peer.tooltip != null && !hasLongPress) {
      button = Tooltip(message: peer.tooltip!, child: button);
    }

    if (peer.label.isEmpty) {
      return button;
    }

    final label = Text(
      peer.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: tokens.monoSm.copyWith(fontSize: size >= 52 ? 10 : 9.5),
    );

    return SizedBox(
      width: 96,
      height: size + 26,
      child: Column(
        mainAxisAlignment: peer.labelAbove ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: peer.labelAbove
            ? [
                label,
                const SizedBox(height: 6),
                button,
              ]
            : [
                button,
                const SizedBox(height: 4),
                label,
              ],
      ),
    );
  }
}
