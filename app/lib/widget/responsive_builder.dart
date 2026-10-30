import 'package:flutter/material.dart';

class SizingInformation {
  final bool isMobile;
  final bool isTabletOrDesktop;
  final bool isDesktop;

  const SizingInformation(double width) : isMobile = width < 700, isTabletOrDesktop = width >= 700, isDesktop = width >= 800;
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(SizingInformation sizingInformation) builder;

  const ResponsiveBuilder({required this.builder});

  @override
  Widget build(BuildContext context) {
    // `MediaQuery.sizeOf` only rebuilds on a size change; `MediaQuery.of` also
    // rebuilds for every other media query change (keyboard insets, view insets).
    final width = MediaQuery.sizeOf(context).width;
    return builder(SizingInformation(width));
  }
}
