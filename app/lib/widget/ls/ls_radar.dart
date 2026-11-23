import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/widget/ls/ls_dashed.dart';

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

  /// Tapping the label opens the device details. The bubble already owns tap (send)
  /// and long press (multi-select), so the label is the only surface left without a
  /// gesture — see [LsRadarPeer.onTap].
  final VoidCallback? onLabelTap;

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
    this.onLabelTap,
  });
}

/// The "signal" radar: three rings, a sweeping conic highlight and orbiting peers.
class LsRadar extends StatefulWidget {
  final double size;
  final Widget center;
  final List<LsRadarPeer> peers;
  final bool animate;

  /// Pinned to the bottom-right corner of the square, just outside the dashed rim —
  /// the empty wedge no peer or peer label reaches. The nearby radar puts its
  /// "shown/total" count there.
  final Widget? corner;

  const LsRadar({
    required this.size,
    required this.center,
    this.peers = const [],
    this.animate = true,
    this.corner,
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
          if (widget.corner != null) Positioned(right: 0, bottom: 0, child: widget.corner!),
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

    // An offline peer is outlined with dashes instead of a hairline. The dashes are
    // painted by [LsDashedRing] over the bubble, so the decorated border stays empty
    // for it; a selected peer keeps the solid accent ring (selection outranks offline).
    final dashedOffline = peer.offline && !peer.selected;

    Widget circle = AnimatedContainer(
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
        border: dashedOffline
            ? null
            : Border.all(
                color: peer.selected ? colors.accent : colors.lineStrong,
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

    if (dashedOffline) {
      circle = SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            circle,
            // Painted inside the bubble's bounds, so the dashes never bleed into a
            // neighbouring peer or into the radar rings behind the bubble.
            IgnorePointer(
              child: LsDashedRing(size: size - 1, color: colors.line),
            ),
          ],
        ),
      );
    }

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

    final fontSize = size >= 52 ? 10.0 : 9.5;
    final label = SizedBox(
      height: _PeerLabel.height,
      child: peer.onLabelTap == null
          ? Center(
              child: Text(
                peer.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: tokens.monoSm.copyWith(fontSize: fontSize),
              ),
            )
          : _PeerLabel(text: peer.label, fontSize: fontSize, onTap: peer.onLabelTap!),
    );
    // The label only ever sits on one side of the bubble, so a box that stacks
    // [button, gap, label] would put the dot off the orbit point — and, because above and
    // below differ, by a different amount per peer, which is what used to make the ring
    // look wobbly. The column is padded symmetrically instead: the bubble is the box's
    // centre, so the parent's centring lands it exactly on the ring. Padding rather than a
    // painted offset also keeps the label inside the box, which is what makes it tappable
    // (a translated child painting outside its box fails the parent's hit test).
    const gap = 5.0;
    final pad = gap + _PeerLabel.height;

    return SizedBox(
      width: 96,
      height: size + 2 * pad,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: peer.labelAbove
            ? [label, const SizedBox(height: gap), button, SizedBox(height: pad)]
            : [SizedBox(height: pad), button, const SizedBox(height: gap), label],
      ),
    );
  }
}

/// The name pill of a radar peer — the radar's way into the device details.
///
/// The bubble already owns tap (send) and long press (multi-select), so the label is the
/// only surface without a gesture. It is drawn as a filled capsule carrying the same
/// `info` glyph the device tile uses for "details": a bare 9.5 px alias reads as a caption,
/// not as a target.
class _PeerLabel extends StatelessWidget {
  /// Pill height; `_Peer` pads its column by exactly this much on both sides of the
  /// bubble, so the two numbers cannot drift apart and the bubble stays on the ring.
  static const double height = 20;

  final String text;
  final double fontSize;
  final VoidCallback onTap;

  const _PeerLabel({required this.text, required this.fontSize, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(color: colors.bg3, borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.info, size: fontSize, color: colors.muted),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.monoSm.copyWith(fontSize: fontSize, color: colors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
