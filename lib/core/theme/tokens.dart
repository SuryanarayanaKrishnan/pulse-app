import 'package:material_ui/material_ui.dart';

/// Semantic colour tokens exposed as a [ThemeExtension].
@immutable
class PulseColors extends ThemeExtension<PulseColors> {
  const PulseColors({
    required this.bg,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentAlt,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.glass,
    required this.glassBorder,
    required this.heroGradient,
    required this.isDark,
  });

  final Color bg;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentAlt;
  final Color positive;
  final Color negative;
  final Color warning;
  final Color glass;
  final Color glassBorder;
  final List<Color> heroGradient;
  final bool isDark;

  static const dark = PulseColors(
    bg: Color(0xFF07080C),
    surface: Color(0xFF11131A),
    surfaceElevated: Color(0xFF1A1D27),
    border: Color(0xFF262A37),
    textPrimary: Color(0xFFF5F6FA),
    textSecondary: Color(0xFFA3A8BA),
    textTertiary: Color(0xFF6B7083),
    accent: Color(0xFF7C5CFF),
    accentAlt: Color(0xFF2DD4BF),
    positive: Color(0xFF34D399),
    negative: Color(0xFFFB7185),
    warning: Color(0xFFFBBF24),
    glass: Color(0x14FFFFFF),
    glassBorder: Color(0x1FFFFFFF),
    heroGradient: [Color(0xFF3B2A8F), Color(0xFF7C5CFF), Color(0xFF2DD4BF)],
    isDark: true,
  );

  static const light = PulseColors(
    bg: Color(0xFFF5F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEEF0F6),
    border: Color(0xFFE1E4EE),
    textPrimary: Color(0xFF0B0D14),
    textSecondary: Color(0xFF52576B),
    textTertiary: Color(0xFF8D92A6),
    accent: Color(0xFF6445F0),
    accentAlt: Color(0xFF0FB5A2),
    positive: Color(0xFF0E9F6E),
    negative: Color(0xFFE11D48),
    warning: Color(0xFFD97706),
    glass: Color(0xB3FFFFFF),
    glassBorder: Color(0x14000000),
    heroGradient: [Color(0xFF5B3FE0), Color(0xFF8B6FFF), Color(0xFF2BC4B0)],
    isDark: false,
  );

  @override
  PulseColors copyWith({Color? bg, Color? surface, Color? accent}) =>
      PulseColors(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        surfaceElevated: surfaceElevated,
        border: border,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        textTertiary: textTertiary,
        accent: accent ?? this.accent,
        accentAlt: accentAlt,
        positive: positive,
        negative: negative,
        warning: warning,
        glass: glass,
        glassBorder: glassBorder,
        heroGradient: heroGradient,
        isDark: isDark,
      );

  @override
  PulseColors lerp(ThemeExtension<PulseColors>? other, double t) {
    if (other is! PulseColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return PulseColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceElevated: l(surfaceElevated, other.surfaceElevated),
      border: l(border, other.border),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      accent: l(accent, other.accent),
      accentAlt: l(accentAlt, other.accentAlt),
      positive: l(positive, other.positive),
      negative: l(negative, other.negative),
      warning: l(warning, other.warning),
      glass: l(glass, other.glass),
      glassBorder: l(glassBorder, other.glassBorder),
      heroGradient: [
        for (var i = 0; i < heroGradient.length; i++)
          l(heroGradient[i], other.heroGradient[i]),
      ],
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Spacing scale.
class Space {
  const Space._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double gutter = 20;
}

/// Corner radii.
class Radii {
  const Radii._();
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double pill = 999;
}

/// Elevation / shadow tokens.
class Elevations {
  const Elevations._();
  static List<BoxShadow> soft(PulseColors c) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: c.isDark ? 0.45 : 0.08),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.35),
      blurRadius: 30,
      spreadRadius: -4,
    ),
  ];
}

extension PulseThemeX on BuildContext {
  PulseColors get pc => Theme.of(this).extension<PulseColors>()!;
  TextTheme get tt => Theme.of(this).textTheme;
}
