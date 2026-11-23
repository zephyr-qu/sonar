/// Appearance of the app, picked in the accent row of the appearance settings.
enum ColorMode {
  /// Brand accent on the fork's own palettes; the default.
  localsend,

  /// Brand accent on pure black surfaces (dark only, saves power on OLED panels).
  oled,

  /// User-defined seed color.
  custom,
}
