import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/persistence/color_mode.dart';
import 'package:sonar/provider/device_info_provider.dart';
import 'package:sonar/util/native/platform_check.dart';
import 'package:sonar/util/ui/dynamic_colors.dart';
import 'package:yaru/yaru.dart' as yaru;

/// Display / body face of the redesign (Latin). CJK glyphs use [_fontFamilyFallback].
const _fontFamily = 'Archivo';

/// Monospace face used for numerals, eyebrows and meta labels.
const _monoFontFamily = 'JetBrains Mono';

final _borderRadius = BorderRadius.circular(10);
final _cardRadius = BorderRadius.circular(16);

/// Cache key of [getTheme]: only these inputs can change the resulting theme.
class _ThemeKey {
  final ColorMode colorMode;
  final Color customColor;
  final Brightness brightness;
  final DynamicColors? dynamicColors;

  const _ThemeKey(this.colorMode, this.customColor, this.brightness, this.dynamicColors);

  @override
  bool operator ==(Object other) {
    return other is _ThemeKey &&
        other.colorMode == colorMode &&
        other.customColor == customColor &&
        other.brightness == brightness &&
        // The palette is recomputed by a provider; an unchanged provider state keeps the
        // same instance, so identity is the cheap and correct comparison here.
        identical(other.dynamicColors, dynamicColors);
  }

  @override
  int get hashCode => Object.hash(colorMode, customColor, brightness, identityHashCode(dynamicColors));
}

/// Built themes, keyed by the settings that produced them.
final _themeCache = <_ThemeKey, ThemeData>{};

/// Builds the theme of the "Signal" redesign.
///
/// The [ColorMode] variants are preserved: `system` (dynamic colors), `custom`
/// (user seed color), `oled` (pure black) and `yaru` (untouched).
ThemeData getTheme(ColorMode colorMode, Color customColor, Brightness brightness, DynamicColors? dynamicColors) {
  final key = _ThemeKey(colorMode, customColor, brightness, dynamicColors);
  final cached = _themeCache[key];
  if (cached != null) {
    return cached;
  }

  final theme = _buildTheme(colorMode, customColor, brightness, dynamicColors);
  // `MaterialApp` asks for the light and the dark theme on every build, so a handful of
  // entries covers every realistic case; more than that means stale combinations (e.g. a
  // dragged color picker) and building a theme is cheap enough to redo once.
  if (_themeCache.length >= 8) {
    _themeCache.clear();
  }
  _themeCache[key] = theme;
  return theme;
}

/// Builds a theme from scratch. Prefer [getTheme], which caches the result.
ThemeData _buildTheme(ColorMode colorMode, Color customColor, Brightness brightness, DynamicColors? dynamicColors) {
  if (colorMode == ColorMode.yaru) {
    return _getYaruTheme(brightness);
  }

  final colorScheme = _determineColorScheme(colorMode, customColor, brightness, dynamicColors);
  final tokens = _tokensFor(colorScheme, brightness);
  final palette = tokens.colors;

  final inputBorder = OutlineInputBorder(
    borderSide: BorderSide(color: palette.line),
    borderRadius: _borderRadius,
  );
  final inputFocusedBorder = OutlineInputBorder(
    borderSide: BorderSide(color: palette.accent),
    borderRadius: _borderRadius,
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    brightness: brightness,
    // same density on all platforms so desktop matches mobile (defaults to compact on desktop)
    visualDensity: VisualDensity.standard,
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFamilyFallback(),
    scaffoldBackgroundColor: palette.bg,
    canvasColor: palette.bg,
    cardColor: palette.bg2,
    dividerColor: palette.line,
    // InkWell's default focus overlay is a 12% primary wash, invisible on the
    // near-black background; tie it to the accent, like the focus halo LsSwitch
    // draws for itself.
    focusColor: palette.accent.withValues(alpha: 0.18),
    extensions: [tokens],
    textTheme: _lsTextTheme(tokens),
    cardTheme: CardThemeData(
      color: palette.bg2,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: _cardRadius,
        side: BorderSide(color: palette.line),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: tokens.title,
      iconTheme: IconThemeData(color: palette.fg),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 58,
      backgroundColor: palette.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return tokens.tabLabel.copyWith(color: selected ? palette.fg : palette.faint);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(size: 18, color: selected ? palette.accent : palette.faint);
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: palette.bg,
      indicatorColor: Colors.transparent,
      selectedIconTheme: IconThemeData(color: palette.accent, size: 18),
      unselectedIconTheme: IconThemeData(color: palette.faint, size: 18),
      selectedLabelTextStyle: tokens.tabLabel.copyWith(color: palette.fg),
      unselectedLabelTextStyle: tokens.tabLabel,
    ),
    dividerTheme: DividerThemeData(color: palette.line, thickness: 1, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: palette.accent,
      linearTrackColor: palette.line,
      linearMinHeight: 4,
      circularTrackColor: palette.line,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: palette.bg2,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      border: inputBorder,
      focusedBorder: inputFocusedBorder,
      enabledBorder: inputBorder,
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: palette.danger),
        borderRadius: _borderRadius,
      ),
      hintStyle: TextStyle(color: palette.faint),
      prefixIconColor: palette.muted,
      suffixIconColor: palette.muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: palette.accentFg,
        disabledBackgroundColor: palette.bg3,
        disabledForegroundColor: palette.faint,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: tokens.buttonLabel,
        shape: RoundedRectangleBorder(borderRadius: _borderRadius),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: palette.accentFg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: tokens.buttonLabel,
        shape: RoundedRectangleBorder(borderRadius: _borderRadius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.fg,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        side: BorderSide(color: palette.lineStrong),
        textStyle: tokens.buttonLabel,
        shape: RoundedRectangleBorder(borderRadius: _borderRadius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.fg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: tokens.buttonLabel,
        shape: RoundedRectangleBorder(borderRadius: _borderRadius),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? palette.accentFg : palette.fg;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? palette.accent : palette.lineStrong;
      }),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          // The selected segment uses the theme accent (brand / dynamic / custom
          // color) so every bar-shaped selector follows the theme color.
          return states.contains(WidgetState.selected) ? palette.accent : palette.bg2;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? palette.accentFg : palette.muted;
        }),
        side: WidgetStatePropertyAll(BorderSide(color: palette.line)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        textStyle: WidgetStatePropertyAll(tokens.label.copyWith(color: palette.muted)),
        minimumSize: const WidgetStatePropertyAll(Size(0, 30)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
        visualDensity: VisualDensity.compact,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.bg,
      modalBackgroundColor: palette.bg,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Colors.black.withValues(alpha: 0.42),
      showDragHandle: true,
      dragHandleColor: palette.lineStrong,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.bg2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: _cardRadius,
        side: BorderSide(color: palette.line),
      ),
      titleTextStyle: tokens.title,
      contentTextStyle: tokens.body,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.bg2,
      surfaceTintColor: Colors.transparent,
      textStyle: tokens.body,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.line),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.fg,
      contentTextStyle: tokens.bodySm.copyWith(color: palette.bg),
      behavior: SnackBarBehavior.floating,
      shape: const StadiumBorder(),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: tokens.bodySm.copyWith(color: palette.fg),
      decoration: BoxDecoration(
        color: palette.bg3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.lineStrong),
      ),
      waitDuration: const Duration(milliseconds: 400),
    ),
    splashFactory: InkRipple.splashFactory,
  );
}

/// Bundled family for simplified Chinese text (`assets/fonts/NotoSansSC-*.ttf`).
const _bundledCjkFamily = 'Noto Sans SC';

/// CJK families, in priority order, for glyphs Archivo does not cover.
List<String> _fontFamilyFallback() {
  final platformFamily = _platformFontFamily();
  return [
    ?platformFamily,
    'PingFang SC',
    'Microsoft YaHei UI',
    'Noto Sans CJK SC',
    'Noto Sans SC',
  ];
}

/// The locale specific system font that provides CJK glyphs on this platform.
String? _platformFontFamily() {
  // Simplified Chinese on desktop uses the bundled Noto Sans SC so that the
  // type matches the prototype instead of the heavier Microsoft YaHei.
  if (checkPlatform([TargetPlatform.windows, TargetPlatform.linux]) && LocaleSettings.currentLocale == AppLocale.zhCn) {
    return _bundledCjkFamily;
  }
  // https://github.com/localsend/localsend/issues/52
  if (checkPlatform([TargetPlatform.windows])) {
    return switch (LocaleSettings.currentLocale) {
      AppLocale.ja => 'Yu Gothic UI',
      AppLocale.ko => 'Malgun Gothic',
      AppLocale.zhCn => 'Microsoft YaHei UI',
      AppLocale.zhHk || AppLocale.zhTw => 'Microsoft JhengHei UI',
      _ => 'Segoe UI Variable Display',
    };
  }
  if (checkPlatform([TargetPlatform.linux])) {
    return switch (LocaleSettings.currentLocale) {
      AppLocale.ja => 'Noto Sans CJK JP',
      AppLocale.ko => 'Noto Sans CJK KR',
      AppLocale.zhCn => 'Noto Sans CJK SC',
      AppLocale.zhHk || AppLocale.zhTw => 'Noto Sans CJK TC',
      _ => 'Noto Sans',
    };
  }
  return null;
}

LsTokens _tokensFor(ColorScheme scheme, Brightness brightness) {
  final base = LsColors.forBrightness(brightness);
  final palette = base.withAccent(scheme.primary, scheme.onPrimary, brightness);
  // Follow the resolved scheme surfaces so OLED stays pure black instead of
  // falling back to the brand background, and custom/dynamic schemes keep
  // their own container tints.
  return LsTokens(
    colors: palette.copyWith(
      bg: scheme.surface,
      bg2: scheme.surfaceContainer,
      bg3: scheme.surfaceContainerHigh,
    ),
    monoFamily: _monoFontFamily,
  );
}

TextTheme _lsTextTheme(LsTokens tokens) {
  return TextTheme(
    displayLarge: tokens.display.copyWith(fontSize: 52, letterSpacing: -1.04),
    displayMedium: tokens.display.copyWith(fontSize: 42, letterSpacing: -0.84),
    displaySmall: tokens.display.copyWith(fontSize: 34, letterSpacing: -0.68),
    headlineMedium: tokens.display,
    headlineSmall: tokens.pageTitle,
    titleLarge: tokens.title,
    titleMedium: tokens.subtitle,
    titleSmall: tokens.bodyStrong,
    bodyLarge: tokens.body,
    bodyMedium: tokens.body,
    bodySmall: tokens.bodySm,
    labelLarge: tokens.buttonLabel,
    labelMedium: tokens.label,
    labelSmall: tokens.eyebrow,
  );
}

Future<void> updateSystemOverlayStyle(BuildContext context) async {
  final brightness = Theme.of(context).brightness;
  await updateSystemOverlayStyleWithBrightness(brightness);
}

Future<void> updateSystemOverlayStyleWithBrightness(Brightness brightness) async {
  if (checkPlatform([TargetPlatform.android])) {
    // See https://github.com/flutter/flutter/issues/90098
    final darkMode = brightness == Brightness.dark;
    final androidSdkInt = RefenaScope.defaultRef.read(deviceInfoProvider).androidSdkInt ?? 0;
    final bool edgeToEdge = androidSdkInt >= 29;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); // ignore: unawaited_futures

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.light ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: edgeToEdge ? Colors.transparent : (darkMode ? Colors.black : Colors.white),
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: darkMode ? Brightness.light : Brightness.dark,
      ),
    );
  } else {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarBrightness: brightness, // iOS
        statusBarColor: Colors.transparent, // Not relevant to this issue
      ),
    );
  }
}

extension ThemeDataExt on ThemeData {
  /// This is the actual [cardColor] being used.
  Color get cardColorWithElevation {
    return ElevationOverlay.applySurfaceTint(cardColor, colorScheme.surfaceTint, 1);
  }
}

extension ColorSchemeExt on ColorScheme {
  Color get warning {
    return Colors.orange;
  }

  Color? get secondaryContainerIfDark {
    return brightness == Brightness.dark ? secondaryContainer : null;
  }

  Color? get onSecondaryContainerIfDark {
    return brightness == Brightness.dark ? onSecondaryContainer : null;
  }
}

extension InputDecorationThemeExt on InputDecorationThemeData {
  BorderRadius get borderRadius => _borderRadius;
}

ColorScheme _determineColorScheme(ColorMode mode, Color customColor, Brightness brightness, DynamicColors? dynamicColors) {
  final palette = LsColors.forBrightness(brightness);

  Color primary;
  Color onPrimary;
  Color primaryContainer;
  Color onPrimaryContainer;
  Color tertiary;
  Color onTertiary;

  switch (mode) {
    case ColorMode.system:
      final dynamicScheme = brightness == Brightness.light ? dynamicColors?.light : dynamicColors?.dark;
      primary = dynamicScheme?.primary ?? palette.accent;
      onPrimary = dynamicScheme?.onPrimary ?? palette.accentFg;
      primaryContainer = dynamicScheme?.primaryContainer ?? palette.accentSoft;
      onPrimaryContainer = dynamicScheme?.onPrimaryContainer ?? palette.fg;
      tertiary = dynamicScheme?.tertiary ?? primary;
      onTertiary = dynamicScheme?.onTertiary ?? onPrimary;
      break;
    case ColorMode.custom:
      // The swatches and the color dialog show the exact color the user picked, so the
      // accent must keep it: `fromSeed` would move it onto M3's tonal palette (tone 40
      // in light mode, tone 80 in dark), which is what made the accent look "wrong".
      final seeded = ColorScheme.fromSeed(seedColor: customColor, brightness: brightness);
      primary = customColor;
      onPrimary = LsColors.onAccentFor(customColor);
      primaryContainer = seeded.primaryContainer;
      onPrimaryContainer = seeded.onPrimaryContainer;
      tertiary = seeded.tertiary;
      onTertiary = seeded.onTertiary;
      break;
    case ColorMode.localsend:
    case ColorMode.oled:
    case ColorMode.yaru:
      primary = palette.accent;
      onPrimary = palette.accentFg;
      primaryContainer = palette.accentSoft;
      onPrimaryContainer = palette.fg;
      tertiary = palette.fg;
      onTertiary = palette.bg;
      break;
  }

  final surface = mode == ColorMode.oled ? Colors.black : palette.bg;
  final surfaceContainer = mode == ColorMode.oled ? const Color(0xFF0A0A0A) : palette.bg2;
  final surfaceContainerHigh = mode == ColorMode.oled ? const Color(0xFF141414) : palette.bg3;

  return ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: palette.fg,
    onSecondary: palette.bg,
    secondaryContainer: surfaceContainerHigh,
    onSecondaryContainer: palette.fg,
    tertiary: tertiary,
    onTertiary: onTertiary,
    tertiaryContainer: surfaceContainerHigh,
    onTertiaryContainer: palette.fg,
    error: palette.danger,
    onError: palette.bg,
    errorContainer: palette.danger.withValues(alpha: 0.16),
    onErrorContainer: palette.danger,
    surface: surface,
    onSurface: palette.fg,
    onSurfaceVariant: palette.muted,
    surfaceDim: surface,
    surfaceBright: surfaceContainerHigh,
    surfaceContainerLowest: surface,
    surfaceContainerLow: surfaceContainer,
    surfaceContainer: surfaceContainer,
    surfaceContainerHigh: surfaceContainerHigh,
    surfaceContainerHighest: surfaceContainerHigh,
    outline: palette.lineStrong,
    outlineVariant: palette.line,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: palette.fg,
    onInverseSurface: palette.bg,
    inversePrimary: surfaceContainerHigh,
    // the redesign does not use the M3 elevation tint
    surfaceTint: Colors.transparent,
  );
}

ThemeData _getYaruTheme(Brightness brightness) {
  final baseTheme = brightness == Brightness.light ? yaru.yaruLight : yaru.yaruDark;
  final colorScheme = baseTheme.colorScheme;

  final lightInputBorder = OutlineInputBorder(
    borderSide: BorderSide(color: colorScheme.secondaryContainer),
    borderRadius: _borderRadius,
  );

  final darkInputBorder = OutlineInputBorder(
    borderSide: BorderSide(color: colorScheme.secondaryContainer),
    borderRadius: _borderRadius,
  );

  return baseTheme.copyWith(
    // same density on all platforms so desktop matches mobile (defaults to compact on desktop)
    visualDensity: VisualDensity.standard,
    navigationBarTheme: colorScheme.brightness == Brightness.dark
        ? NavigationBarThemeData(
            iconTheme: WidgetStateProperty.all(const IconThemeData(color: Colors.white)),
          )
        : null,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.secondaryContainer,
      border: colorScheme.brightness == Brightness.light ? lightInputBorder : darkInputBorder,
      focusedBorder: colorScheme.brightness == Brightness.light ? lightInputBorder : darkInputBorder,
      enabledBorder: colorScheme.brightness == Brightness.light ? lightInputBorder : darkInputBorder,
      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: colorScheme.brightness == Brightness.dark ? Colors.white : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
  );
}
