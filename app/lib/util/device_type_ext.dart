import 'package:flutter/material.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:lucide_icons/lucide_icons.dart';

extension DeviceTypeExt on DeviceType {
  IconData get icon {
    return switch (this) {
      DeviceType.mobile => LucideIcons.smartphone,
      DeviceType.desktop => LucideIcons.monitor,
      DeviceType.web => LucideIcons.globe,
      DeviceType.headless => LucideIcons.terminal,
      DeviceType.server => LucideIcons.server,
    };
  }
}
