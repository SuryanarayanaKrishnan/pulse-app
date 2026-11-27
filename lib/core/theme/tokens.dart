import 'package:material_ui/material_ui.dart';

/// The five root tabs. Each owns one accent hue from a single harmonious
/// palette (see [PulseColors.tabAccent]).
enum PulseTab { home, budget, cards, splits, wealth }

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
  /// soft sage-white (dark) instead of flat black. Contrast stays above 12:1.
  Color get ink => Color.lerp(textPrimary, accent, isDark ? 0.14 : 0.38)!;

  /// The accent hue that belongs to [t]: Home teal-green, Budget slate blue,
  /// Cards terracotta, Splits indigo, Wealth bronze, all muted. Light values are all >= 4.5:1 on
  /// the page background; dark values are bright and >= 8:1.
  Color tabAccent(PulseTab t) => (isDark ? _tabDark : _tabLight)[t.index];

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
      tabAccent(t).withValues(alpha: isDark ? 0.10 : 0.09);

  static const _tabLight = [
    Color(0xFF1F6F5C), // home: deep teal-green
    Color(0xFF1B6F85), // budget: slate teal-blue
    Color(0xFFA9482F), // cards: terracotta
    Color(0xFF4A52B0), // splits: indigo
    Color(0xFF8F5A12), // wealth: bronze
  ];
  static const _tabDark = [
    Color(0xFF7DBBA8),
    Color(0xFF7DB8D4),
    Color(0xFFE8998A),
    Color(0xFFA9AEEB),
    Color(0xFFE0BC6A),
  ];

  /// Dark: warm graphite, not black; a soft teal accent.
  static const dark = PulseColors(
    bg: Color(0xFF0F1211),
    surface: Color(0xFF181C1B),
    surfaceElevated: Color(0xFF232927),
    border: Color(0xFF2F3633),
    textPrimary: Color(0xFFEDEFEC),
    textSecondary: Color(0xFF9DA59F),
    textTertiary: Color(0xFF68716C),
    accent: Color(0xFF7DBBA8),
    onAccent: Color(0xFF0C241E),
    positive: Color(0xFF7FBE98),
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
    accent: Color(0xFF1F6F5C),
    onAccent: Color(0xFFFFFFFF),
    positive: Color(0xFF357F58),
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
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 340,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      c.tabWash(tab),
                      c.tabWash(tab).withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
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
