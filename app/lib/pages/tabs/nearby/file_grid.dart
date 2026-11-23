import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/pages/selected_files_page.dart';
import 'package:sonar/pages/tabs/nearby_tab_vm.dart';
import 'package:sonar/util/file_type_ext.dart';
import 'package:sonar/widget/file_thumbnail.dart';
import 'package:sonar/widget/ls/ls_tile.dart';
import 'package:sonar_isolates/util/file_size_helper.dart';

/// The pending-files tray, shared by the grid and the radar layouts.
///
/// [maxTileWidth] caps the tile squares so the radar's file tray never grows past the center bubble; the cells keep the
/// [columns] rhythm and the extra width becomes gutter.
class NearbyFileGrid extends StatelessWidget {
  final NearbyTabVm vm;
  final int columns;
  final double? maxTileWidth;

  const NearbyFileGrid({
    required this.vm,
    required this.columns,
    this.maxTileWidth,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final files = vm.selectedFiles;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final cellWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final tileWidth = maxTileWidth == null ? cellWidth : math.min(cellWidth, maxTileWidth!);
        // The caption band follows the text scale, so a larger system font grows the cell
        // instead of overflowing it (see [fileTileCaptionHeight]).
        final captionHeight = fileTileCaptionHeight(context);
        Widget cell(Widget child) => Center(
          child: SizedBox(width: tileWidth, child: child),
        );
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 192),
          child: GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            // the tray caps at 192px; keep the grid scrollable so no file becomes unreachable
            physics: const ClampingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
              mainAxisExtent: tileWidth + captionHeight,
            ),
            itemCount: files.length + 1,
            itemBuilder: (context, index) {
              if (index == files.length) {
                return cell(
                  LsAddFileTile(
                    label: t.nearbyTab.addFile,
                    onTap: () async => vm.onAddFiles(context),
                  ),
                );
              }
              final file = files[index];
              final kind = fileKind(file.name);
              return cell(
                LsFileTile(
                  kind: kind,
                  name: file.name,
                  meta: file.size.asReadableFileSize,
                  tint: lsKindTint[kind],
                  thumbnail: SmartFileThumbnail.fromCrossFile(file),
                  onRemove: () => vm.onRemoveFile(index),
                  onTap: () async => context.push(() => const SelectedFilesPage()),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
