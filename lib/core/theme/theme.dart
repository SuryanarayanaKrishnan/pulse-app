import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Builds Material themes wired with [PulseColors].
///
/// Type: SF Pro (the system font) on iOS, Inter elsewhere. One scale on a 4pt
/// rhythm: 40 / 32 / 24 / 20 / 17 / 15 / 13, plus 11 for the tab bar only.
/// Every style uses tabular figures so numbers align and never jitter.
class PulseTheme {
  const PulseTheme._();

  /// Disabled in tests so no network font fetch is attempted.
  static bool useGoogleFonts = true;

  /// Test hook: a font family to use when Google Fonts is off (screenshots
  /// register a real font under this name; unit tests leave it null).
  static String? testFontFamily;

  /// Test hook for the bundled display face (screenshots and tests register
  /// the real file under this name; when null the family from pubspec is used).
  static String? testDisplayFamily;

  /// Bundled display face: Fraunces (SIL OFL 1.1, see assets/fonts/OFL.txt).
  /// Used for screen titles, section headers and hero figures only; every
  /// other style stays on the UI face.
  static const displayFamily = 'PulseDisplay';

  static const _tabular = [FontFeature.tabularFigures()];

  static bool get _iosSystemFont =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static TextStyle _font(TextStyle base) {
    final s = base.copyWith(fontFeatures: _tabular);
    if (!useGoogleFonts && testFontFamily != null) {
      return s.copyWith(fontFamily: testFontFamily);
    }
    if (_iosSystemFont || !useGoogleFonts) return s;
    return GoogleFonts.inter(textStyle: s);
  }

  /// Display style: a warm serif with real weight contrast. Weight is
  /// clamped to the two bundled cuts (500 and 600).
  static TextStyle display(
    Color color, {
    required double size,
    FontWeight weight = FontWeight.w600,
    double? height,
  }) => TextStyle(
    fontFamily: testDisplayFamily ?? displayFamily,
    color: color,
    fontSize: size,
    fontWeight: weight.value >= 600 ? FontWeight.w600 : FontWeight.w500,
    letterSpacing: -size * 0.012,
    height: height ?? 1.15,
  );

  /// Largest figures (a balance, a total due) use the display face; the
  /// rest keep tabular UI figures so lists align.
  static const heroFigureSize = 32.0;

  /// Numeric style. Use for every amount.
  static TextStyle amount(
    Color color, {
    double size = 17,
    FontWeight weight = FontWeight.w600,
  }) => size >= heroFigureSize
      ? display(color, size: size, weight: weight, height: 1.1)
      : _font(
          TextStyle(
            color: color,
            fontSize: size,
            fontWeight: weight,
            letterSpacing: _tracking(size),
            height: 1.25,
          ),
        );

  /// Optical tracking: tighter as type gets larger.
  static double _tracking(double size) => size >= 32
      ? -size * 0.025
      : size >= 20
      ? -size * 0.015
      : size >= 15
      ? -0.2
      : 0;

  static TextTheme _textTheme(PulseColors c) {
    TextStyle s(double size, FontWeight w, Color col, {double? height}) =>
        _font(
          TextStyle(
            fontSize: size,
            fontWeight: w,
            color: col,
            letterSpacing: _tracking(size),
            height: height ?? (size >= 24 ? 1.15 : 1.35),
          ),
        );
    return TextTheme(
      displayLarge: display(c.ink, size: 40),
      displayMedium: display(c.ink, size: 32),
      headlineMedium: display(c.ink, size: 26),
      headlineSmall: display(c.ink, size: 24, weight: FontWeight.w500),
      titleLarge: display(c.ink, size: 21, height: 1.25),
      titleMedium: s(17, FontWeight.w600, c.textPrimary),
      titleSmall: s(15, FontWeight.w600, c.textPrimary),
      bodyLarge: s(17, FontWeight.w400, c.textPrimary),
      bodyMedium: s(15, FontWeight.w400, c.textSecondary),
      bodySmall: s(13, FontWeight.w400, c.textSecondary),
      labelLarge: s(17, FontWeight.w600, c.textPrimary),
      labelMedium: s(13, FontWeight.w500, c.textSecondary),
      labelSmall: s(11, FontWeight.w500, c.textTertiary),
    );
  }

  static ThemeData build(PulseColors c) {
    final base = c.isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: c.isDark ? Brightness.dark : Brightness.light,
    ).copyWith(primary: c.accent, surface: c.surface, error: c.negative);
    final text = _textTheme(c);
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      textTheme: text,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      dividerColor: c.border,
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 0.5,
        space: 0.5,
      ),
      extensions: [c],
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.3),
        selectionHandleColor: c.accent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: text.titleMedium,
        iconTheme: IconThemeData(color: c.accent),
        actionsIconTheme: IconThemeData(color: c.accent),
        systemOverlayStyle: c.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.isDark ? c.surfaceElevated : c.textPrimary,
        contentTextStyle: text.bodyMedium!.copyWith(
          color: c.isDark ? c.textPrimary : c.bg,
        ),
        actionTextColor: c.accent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? c.positive : c.surfaceElevated,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: c.border, width: 0.5),
        ),
        textStyle: text.bodyLarge,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceElevated,
        hintStyle: text.bodyLarge!.copyWith(color: c.textTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  static ThemeData get dark => build(PulseColors.dark);
  static ThemeData get light => build(PulseColors.light);
}
