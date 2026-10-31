import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/widget/ls/ls_dashed.dart';
import 'package:localsend_app/widget/ls/ls_progress_bar.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// One cell of the pending-file grid: square thumbnail, kind glyph, name and a remove button.
class LsFileTile extends StatelessWidget {
  final String kind;
  final String name;
  final String? meta;
  final Color? tint;
  final Widget? thumbnail;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const LsFileTile({
    required this.kind,
    required this.name,
    this.meta,
    this.tint,
    this.thumbnail,
    this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Semantics(
      label: meta == null ? name : '$name $meta',
      button: onTap != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Material(
                    color: tint ?? colors.bg3,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: colors.line, width: tokens.hairlineOf(context)),
                    ),
                    child: InkWell(
                      onTap: onTap,
                      child: Center(
                        child:
                            thumbnail ??
                            Text(
                              kind,
                              style: tokens.tabLabel.copyWith(color: colors.fg),
                            ),
                      ),
                    ),
                  ),
                ),
                if (thumbnail != null)
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: _KindBadge(kind: kind),
                  ),
                if (onRemove != null)
                  if (onRemove != null)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: _RemoveButton(onTap: onRemove!, label: name),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            // The file grid reserves a fixed 16px strip for the caption, so keep the line box tight.
            style: tokens.label.copyWith(height: 1.05),
          ),
        ],
      ),
    );
  }
}

/// Small mono label naming the file kind on top of a real thumbnail, so the
/// tile still reads as "PDF" / "HEIC" without hiding the preview.
class _KindBadge extends StatelessWidget {
  final String kind;

  const _KindBadge({required this.kind});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: colors.bg.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        kind,
        style: tokens.tabLabel.copyWith(color: colors.fg),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _RemoveButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Tooltip(
      message: label,
      child: Material(
        color: colors.bg.withValues(alpha: 0.72),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 24,
            height: 24,
            child: Icon(LucideIcons.x, size: 12, color: colors.fg),
          ),
        ),
      ),
    );
  }
}

/// The dashed "add file" tile that always ends the pending grid.
class LsAddFileTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const LsAddFileTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: LsDashedBox(
              color: colors.lineStrong,
              child: Icon(LucideIcons.plus, size: 18, color: colors.accent),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            // Same fixed 16px caption strip as [LsFileTile].
            style: tokens.label.copyWith(height: 1.05),
          ),
        ],
      ),
    );
  }
}

/// A file row with a kind glyph, name, mono meta and an optional inline progress bar.
class LsFileRow extends StatelessWidget {
  final String kind;
  final String name;
  final String meta;
  final double? progress;
  final Widget? trailing;
  final IconData? leadingIcon;
  final bool showDivider;

  const LsFileRow({
    required this.kind,
    required this.name,
    required this.meta,
    this.progress,
    this.trailing,
    this.leadingIcon,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(color: colors.line, width: tokens.hairlineOf(context)),
              )
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.bg3, borderRadius: BorderRadius.circular(10)),
            child: leadingIcon != null
                ? Icon(leadingIcon, size: 14, color: colors.muted)
                : Text(
                    kind,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: tokens.tabLabel.copyWith(color: colors.muted),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.bodyStrong,
                ),
                const SizedBox(height: 1),
                Text(
                  progress == null ? meta : '$meta ${(progress! * 100).round()}%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.monoSm,
                ),
                if (progress != null) ...[
                  const SizedBox(height: 5),
                  LsProgressBar(value: progress!, height: 3),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// The two-column device tile of the "many devices" layout.
class LsDeviceTile extends StatelessWidget {
  final Widget glyph;
  final String name;
  final String meta;
  final bool selected;
  final bool offline;
  final bool favorite;
  final bool multi;
  final bool showFavoriteButton;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onFavorite;
  final VoidCallback? onDetails;

  const LsDeviceTile({
    required this.glyph,
    required this.name,
    required this.meta,
    this.selected = false,
    this.offline = false,
    this.favorite = false,
    this.multi = false,
    this.showFavoriteButton = true,
    this.onTap,
    this.onLongPress,
    this.onFavorite,
    this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return Opacity(
      opacity: offline ? 0.55 : 1,
      child: Material(
        color: selected ? colors.accentSoft : colors.bg2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? colors.accent : colors.line),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          hoverColor: colors.bg3,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 26, 8),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: colors.bg3, borderRadius: BorderRadius.circular(8)),
                      child: IconTheme(
                        data: IconThemeData(size: 16, color: selected ? colors.accentInk : colors.fg),
                        child: glyph,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            // The device grid caps the tile at 62px; pin the line box so a two-line name still fits.
                            style: tokens.bodyStrong.copyWith(height: 1.15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.monoSm,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (multi)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(
                    selected ? LucideIcons.checkCircle : LucideIcons.circle,
                    size: 14,
                    color: selected ? colors.accent : colors.faint,
                  ),
                )
              else if (showFavoriteButton && onFavorite != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _FavoriteStar(favorite: favorite, onTap: onFavorite!, size: 22, iconSize: 13, hitSize: 28),
                ),
              if (!multi && onDetails != null)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: _DetailsButton(onTap: onDetails!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The device card of the desktop grid (glyph + star, title, mono meta lines).
class LsDeviceCard extends StatefulWidget {
  final Widget glyph;
  final String name;
  final String meta;
  final String? metaSecondary;
  final bool selected;
  final bool offline;
  final bool favorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onDetails;

  const LsDeviceCard({
    super.key,
    required this.glyph,
    required this.name,
    required this.meta,
    this.metaSecondary,
    this.selected = false,
    this.offline = false,
    this.favorite = false,
    this.onTap,
    this.onFavorite,
    this.onDetails,
  });

  @override
  State<LsDeviceCard> createState() => _LsDeviceCardState();
}

class _LsDeviceCardState extends State<LsDeviceCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    // Desktop hover follows the prototype: the hairline brightens and the card
    // lifts 1px instead of getting a flat tint.
    final borderColor = widget.selected
        ? colors.accent
        : _hover
        ? colors.lineStrong
        : colors.line;

    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transformAlignment: Alignment.center,
        transform: Matrix4.translationValues(0, _hover ? -1 : 0, 0),
        decoration: BoxDecoration(
          color: widget.selected ? colors.accentSoft : colors.bg2,
          borderRadius: tokens.cardRadius,
          border: Border.all(color: borderColor, width: tokens.hairlineOf(context)),
        ),
        child: Material(
          type: MaterialType.transparency,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: tokens.cardRadius),
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onDetails,
            hoverColor: colors.bg3,
            borderRadius: tokens.cardRadius,
            child: Opacity(
              opacity: widget.offline ? 0.6 : 1,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: colors.bg3, borderRadius: BorderRadius.circular(10)),
                              child: IconTheme(
                                data: IconThemeData(size: 18, color: widget.selected ? colors.accentInk : colors.fg),
                                child: widget.glyph,
                              ),
                            ),
                            if (widget.selected)
                              Positioned(
                                right: -4,
                                bottom: -4,
                                child: Container(
                                  width: 15,
                                  height: 15,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: colors.accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: colors.bg2, width: 1.5),
                                  ),
                                  child: Icon(LucideIcons.check, size: 9, color: colors.accentInk),
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        if (widget.onFavorite != null)
                          _FavoriteStar(favorite: widget.favorite, onTap: widget.onFavorite!, size: 30, iconSize: 16, hitSize: 34),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.subtitle,
                    ),
                    const SizedBox(height: 6),
                    Text(widget.meta, style: tokens.monoSm),
                    if (widget.metaSecondary != null) Text(widget.metaSecondary!, style: tokens.monoSm),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The favorite toggle of a device tile / card.
///
/// Lucide has no filled star, so the state is carried by the glyph plate: a
/// favorite sits on an [`LsColors.accentSoft`] disc with the accent star, a
/// non-favorite is a bare faint star. Both branches used to draw the identical
/// glyph, which left the color as the only difference.
class _FavoriteStar extends StatelessWidget {
  final bool favorite;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  /// Tap target around the [size] disc; larger than the disc so the star is not a
  /// 22px hit area on a touch screen.
  final double hitSize;

  const _FavoriteStar({required this.favorite, required this.onTap, required this.size, required this.iconSize, required this.hitSize});

  @override
  Widget build(BuildContext context) {
    final colors = context.ls.colors;
    return Tooltip(
      message: favorite ? t.dialogs.favoriteDeleteDialog.title : t.dialogs.favoriteEditDialog.titleAdd,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: hitSize,
            height: hitSize,
            child: Center(
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: favorite ? BoxDecoration(color: colors.accentSoft, shape: BoxShape.circle) : null,
                child: Icon(LucideIcons.star, size: iconSize, color: favorite ? colors.accent : colors.faint),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "device details" button of a tile. The glyph stays 13px; the 28px box is
/// the tap target, because a 20px corner button is not reachable with a finger.
class _DetailsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DetailsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.ls.colors;
    return Tooltip(
      message: t.deviceDetailsPage.title,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(LucideIcons.info, size: 13, color: colors.faint),
          ),
        ),
      ),
    );
  }
}
