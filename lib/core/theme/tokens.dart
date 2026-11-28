import 'package:material_ui/material_ui.dart';

/// The five root tabs. Each owns one accent hue from a single harmonious
/// palette (see [PulseColors.tabAccent]).
enum PulseTab { home, budget, cards, splits, wealth }

/// The two palettes. Sage when cash flow is comfortable, Stone when it is
/// tight (see `moodProvider`).
enum PulseMood { sage, stone }

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
    required this.tabs,
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

  /// One hue per [PulseTab], in tab order. Muted and close to the accent
  /// family so the five tabs read as one calm palette.
  final List<Color> tabs;
  final bool isDark;

  /// Ink for titles and section headers: the primary text colour pulled a
  /// little toward the accent so headers read as deep green-black (light) or
  /// soft sage-white (dark) instead of flat black. Contrast stays above 12:1.
  Color get ink => Color.lerp(textPrimary, accent, isDark ? 0.14 : 0.38)!;

  /// The accent hue that belongs to [t]: Home teal-green, Budget slate blue,
  /// Cards terracotta, Splits indigo, Wealth bronze, all muted. Light values are all >= 4.5:1 on
  /// the page background; dark values are bright and >= 8:1.
  Color tabAccent(PulseTab t) => tabs[t.index];

  /// Header and hero ink for [t]: the tab hue pulled slightly toward the
  /// primary text colour so large type stays rich but never neon.
  /// [strength] 0 is plain text colour, 1 is the pure hue.
  Color tabInk(PulseTab? t, {double strength = 0.9}) => t == null
      ? ink
      : Color.lerp(
          textPrimary,
          tabAccent(t),
          isDark ? strength * 0.9 : strength,
        )!;

  /// Low-saturation wash for hero areas of [t].
  Color tabWash(PulseTab t) =>
      tabAccent(t).withValues(alpha: isDark ? 0.06 : 0.05);

  /// Sage, dark: warm graphite with a muted green-grey accent.
  static const sageDark = PulseColors(
    bg: Color(0xFF121211),
    surface: Color(0xFF1B1B19),
    surfaceElevated: Color(0xFF262624),
    border: Color(0xFF34342F),
    textPrimary: Color(0xFFECEBE7),
    textSecondary: Color(0xFF9A9B95),
    textTertiary: Color(0xFF6B6C67),
    accent: Color(0xFF8FB0A3),
    onAccent: Color(0xFF10201B),
    positive: Color(0xFF86B596),
    negative: Color(0xFFE0907C),
    warning: Color(0xFFDDB867),
    tabs: [
      Color(0xFF8FB0A3),
      Color(0xFF92AABB),
      Color(0xFFC69E92),
      Color(0xFFA3A6C9),
      Color(0xFFC8B48A),
    ],
    isDark: true,
  );

  /// Sage, light: warm paper with a deep green-grey accent.
  static const sageLight = PulseColors(
    bg: Color(0xFFF4F3F0),
    surface: Color(0xFFFBFBF9),
    surfaceElevated: Color(0xFFE8E6E1),
    border: Color(0xFFD9D6CF),
    textPrimary: Color(0xFF1C1D1B),
    textSecondary: Color(0xFF5F625D),
    textTertiary: Color(0xFF8F918B),
    accent: Color(0xFF3E6A5D),
    onAccent: Color(0xFFFFFFFF),
    positive: Color(0xFF3B7A55),
    negative: Color(0xFFB5503B),
    warning: Color(0xFF8F600B),
    tabs: [
      Color(0xFF3E6A5D),
      Color(0xFF3D5F73),
      Color(0xFF8A5646),
      Color(0xFF4F5380),
      Color(0xFF7A5C20),
    ],
    isDark: false,
  );

  /// Stone, dark: the same surfaces; the accent is warm stone, near
  /// monochrome. Used when cash flow is tight.
  static const stoneDark = PulseColors(
    bg: Color(0xFF121211),
    surface: Color(0xFF1B1B19),
    surfaceElevated: Color(0xFF262624),
    border: Color(0xFF34342F),
    textPrimary: Color(0xFFECEBE7),
    textSecondary: Color(0xFF9A9B95),
    textTertiary: Color(0xFF6B6C67),
    accent: Color(0xFFD9D4C7),
    onAccent: Color(0xFF1A1A17),
    positive: Color(0xFF86B596),
    negative: Color(0xFFE0907C),
    warning: Color(0xFFDDB867),
    tabs: [
      Color(0xFFD9D4C7),
      Color(0xFFC9CFD4),
      Color(0xFFD8C3B8),
      Color(0xFFC8C8DC),
      Color(0xFFDACBA3),
    ],
    isDark: true,
  );

  /// Stone, light: the accent is ink.
  static const stoneLight = PulseColors(
    bg: Color(0xFFF4F3F0),
    surface: Color(0xFFFBFBF9),
    surfaceElevated: Color(0xFFE8E6E1),
    border: Color(0xFFD9D6CF),
    textPrimary: Color(0xFF1C1D1B),
    textSecondary: Color(0xFF5F625D),
    textTertiary: Color(0xFF8F918B),
    accent: Color(0xFF2A2C29),
    onAccent: Color(0xFFFFFFFF),
    positive: Color(0xFF3B7A55),
    negative: Color(0xFFB5503B),
    warning: Color(0xFF8F600B),
    tabs: [
      Color(0xFF4A4D48),
      Color(0xFF46535C),
      Color(0xFF6B4E43),
      Color(0xFF4D4F66),
      Color(0xFF6B5B38),
    ],
    isDark: false,
  );

  /// Default palettes (Sage).
  static const dark = sageDark;
  static const light = sageLight;

  /// The palette for a [mood] in the given brightness.
  static PulseColors of(PulseMood mood, {required bool dark}) =>
      switch ((mood, dark)) {
        (PulseMood.sage, true) => sageDark,
        (PulseMood.sage, false) => sageLight,
        (PulseMood.stone, true) => stoneDark,
        (PulseMood.stone, false) => stoneLight,
      };

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
        tabs: tabs,
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
      tabs: [for (var i = 0; i < tabs.length; i++) l(tabs[i], other.tabs[i])],
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }

  /// Quiet fill for things that are fine: on-track bars and rings. Sits
  /// between the tertiary text and the accent so it never shouts.
  Color get calm => Color.lerp(textTertiary, accent, 0.45)!;

  /// Status colour for a budget-style ratio: on track (accent), nearing the
  /// limit (amber, from 85%), over (coral).
  Color forProgress(double p) =>
      p > 1 ? negative : (p >= 0.85 ? warning : calm);

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

  /// The accent of the tab this widget sits in (brand accent elsewhere).
  Color get tabAccent {
    final t = TabScope.maybeOf(this);
    final c = pc;
    return t == null ? c.accent : c.tabAccent(t);
  }

  /// Header/hero ink for the current tab.
  Color tabInk({double strength = 0.9}) =>
      pc.tabInk(TabScope.maybeOf(this), strength: strength);
}

/// Tells everything beneath a tab root which tab it belongs to, so headers,
/// hero figures, chips and washes pick up that tab's hue from the theme.
class TabScope extends InheritedWidget {
  const TabScope({super.key, required this.tab, required super.child});
  final PulseTab tab;

  static PulseTab? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabScope>()?.tab;

  @override
  bool updateShouldNotify(TabScope old) => old.tab != tab;
}

/// Wraps a tab root: sets the [TabScope] and paints a soft wash of the tab
/// hue fading out behind the header and hero area. The wrapped Scaffold is
/// made transparent so the wash shows through.
class TabBackdrop extends StatelessWidget {
  const TabBackdrop({super.key, required this.tab, required this.child});
  final PulseTab tab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final theme = Theme.of(context);
    return TabScope(
      tab: tab,
      child: ColoredBox(
        color: c.bg,
        child: Stack(
          children: [
            Theme(
              data: theme.copyWith(scaffoldBackgroundColor: Colors.transparent),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
