import 'package:flutter/material.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/widget/ls/ls_header.dart';

class LsTabItem {
  final IconData icon;
  final String label;

  const LsTabItem({required this.icon, required this.label});
}

/// Mobile bottom navigation: two flat tabs, accents on the active icon, mono labels.
class LsTabBar extends StatelessWidget {
  final List<LsTabItem> items;
  final int index;
  final ValueChanged<int> onTap;

  const LsTabBar({
    required this.items,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(
          top: BorderSide(color: colors.line, width: tokens.hairlineOf(context)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, 8, 16, 10 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Material(
                color: Colors.transparent,
                borderRadius: tokens.tileRadius,
                child: InkWell(
                  borderRadius: tokens.tileRadius,
                  onTap: () => onTap(i),
                  hoverColor: colors.bg3,
                  child: SizedBox(
                    height: 46,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[i].icon,
                          size: 18,
                          color: i == index ? colors.accent : colors.faint,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[i].label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.tabLabel.copyWith(color: i == index ? colors.fg : colors.faint),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Desktop navigation rail: 78px wide, accent mark on top, tabs then a footer slot.
class LsRail extends StatelessWidget {
  final List<LsTabItem> items;
  final int index;
  final ValueChanged<int> onTap;
  final Widget mark;
  final List<Widget> footer;

  const LsRail({
    required this.items,
    required this.index,
    required this.onTap,
    required this.mark,
    this.footer = const [],
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Container(
      width: 78,
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(
          right: BorderSide(color: colors.line, width: tokens.hairlineOf(context)),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.accent, borderRadius: BorderRadius.circular(tokens.radiusSm)),
            child: IconTheme(
              data: IconThemeData(size: 17, color: colors.accentFg),
              child: mark,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: LsRailButton(
                icon: items[i].icon,
                label: items[i].label,
                selected: i == index,
                onTap: () => onTap(i),
              ),
            ),
          const Spacer(),
          ...footer,
        ],
      ),
    );
  }
}

/// Rail entry button; also usable in [LsRail.footer] to pin an item at the
/// bottom of the rail.
class LsRailButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const LsRailButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<LsRailButton> createState() => _LsRailButtonState();
}

class _LsRailButtonState extends State<LsRailButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final active = widget.selected || _hover;
    final iconColor = widget.selected
        ? colors.accent
        : _hover
        ? colors.fg
        : colors.faint;

    return Tooltip(
      message: widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            // 62 keeps the 10px uppercase label ("TRANSFER") on one line inside
            // the 78px rail.
            width: 62,
            height: 46,
            decoration: BoxDecoration(
              color: active ? colors.bg3 : Colors.transparent,
              borderRadius: tokens.tileRadius,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<Color?>(
                  duration: const Duration(milliseconds: 140),
                  tween: ColorTween(end: iconColor),
                  builder: (context, animated, child) => Icon(widget.icon, size: 17, color: animated),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.tabLabel.copyWith(color: active ? colors.fg : colors.faint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Page shell of a pushed screen: `LsSubHeader` on top, scrollable body below,
/// centered to [maxWidth] on wide windows.
class LsPageScaffold extends StatelessWidget {
  final String title;
  final Widget? subtitle;
  final List<Widget> actions;
  final Widget body;
  final double maxWidth;
  final bool resizeToAvoidBottomInset;

  const LsPageScaffold({
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.maxWidth = 640,
    this.resizeToAvoidBottomInset = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LsSubHeader(
                  title: title,
                  subtitle: subtitle,
                  actions: actions,
                  onBack: () => Navigator.maybePop(context),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
