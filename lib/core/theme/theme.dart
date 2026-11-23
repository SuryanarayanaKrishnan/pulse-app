import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Builds Material themes wired with [PulseColors].
class PulseTheme {
  const PulseTheme._();

  /// Disabled in tests so no network font fetch is attempted.
  static bool useGoogleFonts = true;

  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle _manrope(TextStyle base) =>
      useGoogleFonts ? GoogleFonts.manrope(textStyle: base) : base;
  static TextStyle _inter(TextStyle base) =>
      useGoogleFonts ? GoogleFonts.inter(textStyle: base) : base;

  /// Big numeric style with tabular figures.
  static TextStyle amount(
    Color color, {
    double size = 28,
    FontWeight weight = FontWeight.w800,
  }) => _manrope(
    TextStyle(
      color: color,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -0.5,
      fontFeatures: _tabular,
      height: 1.1,
    ),
  );

  static TextTheme _textTheme(PulseColors c) {
    TextStyle m(double s, FontWeight w, Color col, {double ls = 0}) => _manrope(
      TextStyle(
        fontSize: s,
        fontWeight: w,
        color: col,
        letterSpacing: ls,
        height: 1.2,
      ),
    );
    TextStyle i(double s, FontWeight w, Color col) =>
        _inter(TextStyle(fontSize: s, fontWeight: w, color: col, height: 1.35));
    return TextTheme(
      displayLarge: m(44, FontWeight.w800, c.textPrimary, ls: -1.2),
      displayMedium: m(34, FontWeight.w800, c.textPrimary, ls: -0.8),
      headlineMedium: m(26, FontWeight.w800, c.textPrimary, ls: -0.5),
      titleLarge: m(20, FontWeight.w700, c.textPrimary, ls: -0.3),
      titleMedium: m(16, FontWeight.w700, c.textPrimary),
      titleSmall: m(14, FontWeight.w600, c.textPrimary),
      bodyLarge: i(16, FontWeight.w500, c.textPrimary),
      bodyMedium: i(14, FontWeight.w400, c.textSecondary),
      bodySmall: i(12, FontWeight.w400, c.textTertiary),
      labelLarge: m(15, FontWeight.w700, c.textPrimary),
      labelMedium: m(12, FontWeight.w600, c.textSecondary, ls: 0.2),
      labelSmall: m(11, FontWeight.w700, c.textTertiary, ls: 0.8),
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
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      textTheme: _textTheme(c),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: c.border,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: c.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
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
        hintStyle: TextStyle(color: c.textTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
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
