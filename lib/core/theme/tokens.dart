import 'package:material_ui/material_ui.dart';

/// Semantic colour tokens exposed as a [ThemeExtension].
///
/// One accent for interaction. Positive / negative / warning describe money
/// states only and are never decoration.
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
    required this.onAccent,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.isDark,
  });

  /// Page background.
  final Color bg;

  /// Grouped surfaces (sheets, the few remaining cards).
  final Color surface;

  /// Control fills: inputs, chips, icon wells, tracks.
  final Color surfaceElevated;

  /// Hairline separators.
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color onAccent;
  final Color positive;
  final Color negative;
  final Color warning;
  final bool isDark;

  /// Ink for titles and section headers: the primary text colour pulled a
  /// little toward the accent so headers read as deep green-black (light) or
  /// soft mint-white (dark) instead of flat black. Contrast stays above 12:1.
  Color get ink => Color.lerp(textPrimary, accent, isDark ? 0.14 : 0.38)!;

  /// Dark: warm graphite, not black; a soft teal accent.
  static const dark = PulseColors(
    bg: Color(0xFF0F1211),
    surface: Color(0xFF181C1B),
    surfaceElevated: Color(0xFF232927),
    border: Color(0xFF2F3633),
    textPrimary: Color(0xFFEDEFEC),
    textSecondary: Color(0xFF9DA59F),
    textTertiary: Color(0xFF68716C),
    accent: Color(0xFF5BC2A8),
    onAccent: Color(0xFF052A21),
    positive: Color(0xFF72C990),
    negative: Color(0xFFE5846F),
    warning: Color(0xFFE6B450),
    isDark: true,
  );

  /// Light: warm paper neutrals; the accent darkens to keep 4.5:1 on white.
  static const light = PulseColors(
    bg: Color(0xFFF6F5F1),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFECEAE4),
    border: Color(0xFFDDDAD2),
    textPrimary: Color(0xFF1A1E1C),
    textSecondary: Color(0xFF5C645F),
    textTertiary: Color(0xFF959B96),
    accent: Color(0xFF1C826B),
    onAccent: Color(0xFFFFFFFF),
    positive: Color(0xFF2E8452),
    negative: Color(0xFFC0533D),
    warning: Color(0xFFA86F0C),
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
        onAccent: onAccent,
        positive: positive,
        negative: negative,
        warning: warning,
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
      onAccent: l(onAccent, other.onAccent),
      positive: l(positive, other.positive),
      negative: l(negative, other.negative),
      warning: l(warning, other.warning),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }

  /// Status colour for a budget-style ratio: on track (accent), nearing the
  /// limit (amber, from 85%), over (coral).
  Color forProgress(double p) =>
      p > 1 ? negative : (p >= 0.85 ? warning : accent);

  /// The words that go with [forProgress].
  static String statusLabel(double p) =>
      p > 1 ? 'Over' : (p >= 0.85 ? 'Nearing limit' : 'On track');
}

/// Spacing scale: a strict 4/8pt grid.
class Space {
  const Space._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Screen side margin.
  static const double gutter = 20;

  /// Vertical gap between screen sections.
  static const double section = 32;
}

/// Corner radii: three values plus pill.
class Radii {
  const Radii._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double pill = 999;
}

/// Motion tokens. Springs for anything the finger drives (interruptible),
/// short ease-outs for state changes.
class Motion {
  const Motion._();
  static const fast = Duration(milliseconds: 160);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 400);
  static const curve = Curves.easeOutCubic;
}

extension PulseThemeX on BuildContext {
  PulseColors get pc => Theme.of(this).extension<PulseColors>()!;
  TextTheme get tt => Theme.of(this).textTheme;
}
