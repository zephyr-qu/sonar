import 'package:flutter/material.dart';
import 'package:localsend_isolates/model/file_type.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
