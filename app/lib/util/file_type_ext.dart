import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sonar_isolates/model/file_type.dart';

extension FileTypeExt on FileType {
  IconData get icon {
    return switch (this) {
      FileType.image => LucideIcons.image,
      FileType.video => LucideIcons.film,
      FileType.pdf => LucideIcons.fileText,
      FileType.text => LucideIcons.alignLeft,
      FileType.apk => LucideIcons.bot,
      FileType.other => LucideIcons.file,
    };
  }
}

/// The uppercase extension of [name], capped at four characters.
///
/// Falls back to [fallback] when [name] carries no extension: the file rows show
/// this in a fixed-width mono column, so the label never grows past four
/// characters and never collapses to nothing.
String fileKind(String name, {String fallback = 'FILE'}) {
  final dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) {
    return fallback;
  }
  final kind = name.substring(dot + 1).toUpperCase();
  return kind.length > 4 ? kind.substring(0, 4) : kind;
}
