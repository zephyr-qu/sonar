import 'package:flutter/material.dart';

/// The palette of the "Signal" redesign.
///
/// The dark values are taken 1:1 from the prototype
/// (`designs/localsend-reimagined/index.html`), the light values are a derived
/// counterpart with the same structure so that every widget can read the same
/// slot names in both brightness modes.
@immutable
class LsColors {
  /// Page background.
  final Color bg;

  /// Cards, sheets, input fields.
  final Color bg2;

  /// Chips, glyph backgrounds, hover surfaces.
  final Color bg3;

  /// Primary foreground.
  final Color fg;

  /// Secondary foreground / secondary text.
  final Color muted;

  /// Tertiary foreground (eyebrows, disabled icons).
  final Color faint;

  /// 1px hairline.
  final Color line;

  /// Stronger hairline (borders of interactive surfaces).
  final Color lineStrong;

  /// The signal accent (lime in the prototype).
  final Color accent;

  /// Foreground on [accent].
  final Color accentFg;

  /// Accent when it is used as text on a surface (needs more contrast in light mode).
  final Color accentInk;

  /// Translucent accent for selected surfaces.
  final Color accentSoft;

  /// Destructive actions.
  final Color danger;

  const LsColors({
    required this.bg,
    required this.bg2,
    required this.bg3,
    required this.fg,
    required this.muted,
    required this.faint,
    required this.line,
    required this.lineStrong,
    required this.accent,
    required this.accentFg,
    required this.accentInk,
    required this.accentSoft,
    required this.danger,
  });

  static const dark = LsColors(
    bg: Color(0xFF0A0B0D),
    bg2: Color(0xFF101216),
    bg3: Color(0xFF171A20),
    fg: Color(0xFFEDEFF2),
    muted: Color(0xFF9AA1AC),
    faint: Color(0xFF7E8590),
    line: Color(0x14FFFFFF),
    lineStrong: Color(0x29FFFFFF),
    accent: Color(0xFFC6F24E),
    accentFg: Color(0xFF0A0B0D),
    accentInk: Color(0xFFC6F24E),
    accentSoft: Color(0x24C6F24E),
    danger: Color(0xFFFF6B57),
  );

  static const light = LsColors(
    bg: Color(0xFFFFFFFF),
    bg2: Color(0xFFF5F6F7),
    bg3: Color(0xFFECEEF1),
    fg: Color(0xFF14161A),
    muted: Color(0xFF545B65),
    faint: Color(0xFF747B86),
    line: Color(0x1414161A),
    lineStrong: Color(0x2914161A),
    accent: Color(0xFFC6F24E),
    accentFg: Color(0xFF0A0B0D),
    accentInk: Color(0xFF5F7A0F),
    accentSoft: Color(0x2EC6F24E),
    danger: Color(0xFFD6452F),
  );

  static LsColors forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  /// Returns a copy where the accent slots follow [accent] (used for the
  /// dynamic-color and custom-color modes).
  LsColors withAccent(Color accent, Color onAccent) {
    return LsColors(
      bg: bg,
      bg2: bg2,
      bg3: bg3,
      fg: fg,
      muted: muted,
      faint: faint,
      line: line,
      lineStrong: lineStrong,
      accent: accent,
      accentFg: onAccent,
      accentInk: accent,
      accentSoft: accent.withValues(alpha: 0.14),
      danger: danger,
    );
  }

  LsColors copyWith({
    Color? bg,
    Color? bg2,
    Color? bg3,
    Color? fg,
    Color? muted,
    Color? faint,
    Color? line,
    Color? lineStrong,
    Color? accent,
    Color? accentFg,
    Color? accentInk,
    Color? accentSoft,
    Color? danger,
  }) {
    return LsColors(
      bg: bg ?? this.bg,
      bg2: bg2 ?? this.bg2,
      bg3: bg3 ?? this.bg3,
      fg: fg ?? this.fg,
      muted: muted ?? this.muted,
      faint: faint ?? this.faint,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      accent: accent ?? this.accent,
      accentFg: accentFg ?? this.accentFg,
      accentInk: accentInk ?? this.accentInk,
      accentSoft: accentSoft ?? this.accentSoft,
      danger: danger ?? this.danger,
    );
  }

  LsColors lerp(LsColors other, double t) {
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return LsColors(
      bg: mix(bg, other.bg),
      bg2: mix(bg2, other.bg2),
      bg3: mix(bg3, other.bg3),
      fg: mix(fg, other.fg),
      muted: mix(muted, other.muted),
      faint: mix(faint, other.faint),
      line: mix(line, other.line),
      lineStrong: mix(lineStrong, other.lineStrong),
      accent: mix(accent, other.accent),
      accentFg: mix(accentFg, other.accentFg),
      accentInk: mix(accentInk, other.accentInk),
      accentSoft: mix(accentSoft, other.accentSoft),
      danger: mix(danger, other.danger),
    );
  }
}

/// Design tokens of the "Signal" redesign.
///
/// Widgets read them through [LsTokens.of]; every theme built by
/// `getTheme` registers an instance as a [ThemeExtension] so that `yaru`
/// (which is returned untouched) still falls back to a derived instance.
@immutable
class LsTokens extends ThemeExtension<LsTokens> {
  final LsColors colors;

  /// Card / sheet radius (16 in the prototype).
  final double radius;

  /// Small radius for tiles, buttons and inputs (10 in the prototype).
  final double radiusSm;

  /// Horizontal page padding (16 in the prototype).
  final double pad;

  /// Platform monospace family used for numerals and labels.
  final String monoFamily;

  /// Fallbacks for glyphs that JetBrains Mono does not cover (e.g. CJK labels).
  static const _monoFallback = <String>[
    'Consolas',
    'Menlo',
    'DejaVu Sans Mono',
    'Noto Sans SC',
    'Noto Sans CJK SC',
    'Microsoft YaHei UI',
    'monospace',
  ];

  // Not `const` any more: the type scale below is cached per instance, and a
  // `const` constructor cannot have lazily initialised fields.
  LsTokens({
    required this.colors,
    this.radius = 16,
    this.radiusSm = 10,
    this.pad = 16,
    this.monoFamily = 'JetBrains Mono',
  });

  static LsTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<LsTokens>() ?? _fallback(theme);
  }

  static LsTokens _fallback(ThemeData theme) {
    final brightness = theme.brightness;
    final palette = LsColors.forBrightness(brightness);
    final scheme = theme.colorScheme;
    return LsTokens(
      colors: palette
          .withAccent(scheme.primary, scheme.onPrimary)
          .copyWith(
            bg: scheme.surface,
            bg2: scheme.surfaceContainer,
            bg3: scheme.surfaceContainerHigh,
          ),
    );
  }

  /// One physical pixel in logical units, so hairlines stay crisp at 125%/150%
  /// Windows scaling (the prototype's CSS `1px`).
  double hairlineOf(BuildContext context) => 1 / MediaQuery.devicePixelRatioOf(context);

  BorderRadius get cardRadius => BorderRadius.circular(radius);
  BorderRadius get tileRadius => BorderRadius.circular(radiusSm);

  // ---------------------------------------------------------------- type scale
  //
  // The redesign uses ONE size ladder. Never introduce a one-off font size in a
  // widget: pick the role below that matches the content.
  //
  //  30  display      hero title of a screen
  //  24  pageTitle    desktop / large-screen page title
  //  17  title        screen header, sheet / dialog / group title
  //  15  subtitle     emphasized name or secondary title
  //  13  body         body copy, list item title (bodyStrong = 500)
  //  12  bodySm       helper text, dense secondary rows
  //  11  label        chips, buttons, tabs, badges, mono meta (mono)
  //  10  eyebrow      uppercase eyebrow / keycap labels (eyebrow, tabLabel)

  //
  // The styles are cached per instance: they are read on every build, and a getter
  // returning a fresh `TextStyle` each time defeats `const` widgets and makes every
  // `copyWith` allocate a new style as well.
  /// Hero title of a screen (30 / 700 / -0.02em).
  late final TextStyle display = TextStyle(fontSize: 30, height: 1.08, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: colors.fg);

  /// Desktop / large-screen page title (24 / 700 / -0.02em).
  late final TextStyle pageTitle = TextStyle(fontSize: 24, height: 1.12, fontWeight: FontWeight.w700, letterSpacing: -0.48, color: colors.fg);

  /// Screen header, sheet / dialog / group title (17 / 700).
  late final TextStyle title = TextStyle(fontSize: 17, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.34, color: colors.fg);

  /// Emphasized name or secondary title (15 / 600).
  late final TextStyle subtitle = TextStyle(fontSize: 15, height: 1.25, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: colors.fg);

  /// Body copy and list item titles (13 / 400).
  late final TextStyle body = TextStyle(fontSize: 13, height: 1.45, color: colors.fg);

  /// List item title / emphasized body copy (13 / 500).
  late final TextStyle bodyStrong = TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w500, color: colors.fg);

  /// Helper text and dense secondary rows (12 / 400, muted).
  late final TextStyle bodySm = TextStyle(fontSize: 12, height: 1.45, color: colors.muted);

  /// Chips, buttons, tabs, badges and small UI labels (11 / 500).
  late final TextStyle label = TextStyle(fontSize: 11, height: 1.3, fontWeight: FontWeight.w500, color: colors.muted);

  /// Button caption (13 / 600).
  late final TextStyle buttonLabel = TextStyle(fontSize: 13, height: 1.2, fontWeight: FontWeight.w600, letterSpacing: 0.13);

  /// Monospace numerals / meta (11, tabular).
  late final TextStyle mono = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: _monoFallback,
    fontSize: 11,
    height: 1.4,
    letterSpacing: 0.2,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: colors.muted,
  );

  /// Dense monospace meta, e.g. timestamps inside a tile (10, tabular).
  late final TextStyle monoSm = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: _monoFallback,
    fontSize: 10,
    height: 1.35,
    letterSpacing: 0.2,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: colors.muted,
  );

  /// Uppercase eyebrow label (10, 0.12em).
  late final TextStyle eyebrow = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: _monoFallback,
    fontSize: 10,
    height: 1.3,
    letterSpacing: 1.2,
    fontWeight: FontWeight.w500,
    color: colors.faint,
  );

  /// Keycap / tab label (10, 0.05em).
  late final TextStyle tabLabel = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: _monoFallback,
    fontSize: 10,
    letterSpacing: 0.5,
    fontWeight: FontWeight.w500,
    color: colors.faint,
  );

  @override
  LsTokens copyWith({LsColors? colors, double? radius, double? radiusSm, double? pad, String? monoFamily}) {
    return LsTokens(
      colors: colors ?? this.colors,
      radius: radius ?? this.radius,
      radiusSm: radiusSm ?? this.radiusSm,
      pad: pad ?? this.pad,
      monoFamily: monoFamily ?? this.monoFamily,
    );
  }

  @override
  LsTokens lerp(ThemeExtension<LsTokens>? other, double t) {
    if (other is! LsTokens) {
      return this;
    }
    double lerpValue(double a, double b) => a + (b - a) * t;
    return LsTokens(
      colors: colors.lerp(other.colors, t),
      radius: lerpValue(radius, other.radius),
      radiusSm: lerpValue(radiusSm, other.radiusSm),
      pad: lerpValue(pad, other.pad),
      monoFamily: t < 0.5 ? monoFamily : other.monoFamily,
    );
  }
}

extension LsTokensContext on BuildContext {
  /// Shorthand for `LsTokens.of(context)`.
  LsTokens get ls => LsTokens.of(this);
}

/// Type tint used by the file grid (the prototype tints image/lime/red/amber kinds).
const Map<String, Color> lsKindTint = {
  'HEIC': Color(0x2E7AA2FF),
  'JPG': Color(0x2E7AA2FF),
  'JPEG': Color(0x2E7AA2FF),
  'PNG': Color(0x2E7AA2FF),
  'GIF': Color(0x2E7AA2FF),
  'WEBP': Color(0x2E7AA2FF),
  'MOV': Color(0x2E7AA2FF),
  'MP4': Color(0x2E7AA2FF),
  'FIG': Color(0x2EC6F24E),
  'PDF': Color(0x2EF2695E),
  'M4A': Color(0x2EFFB020),
  'MP3': Color(0x2EFFB020),
  'ZIP': Color(0x2E8B929C),
  'TXT': Color(0x2E8B929C),
  'MD': Color(0x2E8B929C),
  'APK': Color(0x2E8B929C),
};
