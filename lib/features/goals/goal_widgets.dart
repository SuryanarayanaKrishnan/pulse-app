import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/dates.dart';
import '../../core/engine/goals.dart';
import '../../core/icons/glyphs.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/goal_models.dart';
import '../../data/models.dart' show SpendCategory;

/// The glyphs a goal can wear, from the category icon family.
const goalIconKeys = <String>[
  'savings', 'car', 'travel', 'home_loan', 'education', 'family', //
  'gifts', 'health', 'laptop', 'phone', 'palette', 'umbrella',
  'coins', 'landmark', 'star', 'sun', 'leaf', 'fees',
];

String defaultGoalIcon(GoalKind k) =>
    k == GoalKind.paydown ? 'fees' : 'savings';

String aedMinor(int minor) => Money.aed(minor / 100, decimals: false);

String monthYear(CalDate d) {
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${m[d.month - 1]} ${d.year}';
}

/// The glyph a goal wears, on a quiet tile.
class GoalIcon extends StatelessWidget {
  const GoalIcon(
    this.iconKey, {
    super.key,
    this.kind = GoalKind.save,
    this.size = 40,
  });
  final String? iconKey;
  final GoalKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final key = iconKey ?? defaultGoalIcon(kind);
    return CategoryIcon.well(
      SpendCategory.custom('goal_$key', 'Goal', iconKey: key),
      size: size,
    );
  }
}

/// Short, calm label for where a goal stands.
String paceLabel(GoalPace p) => switch (p) {
  GoalPace.done => 'Reached',
  GoalPace.paused => 'Paused',
  GoalPace.onTrack => 'On track',
  GoalPace.behind => 'A little behind',
  GoalPace.noDeadline => 'No date set',
  GoalPace.noPace => 'Not started yet',
};

Color paceColor(PulseColors c, GoalPace p) => switch (p) {
  GoalPace.onTrack || GoalPace.done => c.positive,
  GoalPace.behind => c.warning,
  _ => c.textSecondary,
};

/// One or two plain sentences under the label.
String paceDetail(GoalView v) {
  final proj = v.projected;
  final when = proj == null ? null : monthYear(proj);
  return switch (v.pace) {
    GoalPace.done =>
      v.isPaydown
          ? 'Paid off. That is a real weight off.'
          : 'You got there. Nicely done.',
    GoalPace.paused => 'Nothing is set aside for this while it is paused. Your progress is kept.',
    GoalPace.onTrack =>
      when == null
          ? 'You are keeping pace.'
          : 'At this pace you finish around $when.',
    GoalPace.behind =>
      '${when == null ? 'Progress has slowed.' : 'At this pace you finish around $when, a little after your date.'} '
              '${v.suggestedMinor == null ? '' : 'About ${aedMinor(v.suggestedMinor!)} a month would close the gap.'}'
          .trim(),
    GoalPace.noDeadline =>
      when == null
          ? 'Add a date and Pulse will suggest a monthly amount.'
          : 'At this pace you finish around $when.',
    GoalPace.noPace => 'Add a first contribution, or a monthly amount, to see when you could finish.',
  };
}

/// A goal as a list row: glyph, name, how far, and a small ring.
class GoalRow extends StatelessWidget {
  const GoalRow(this.v, {super.key, this.onTap});
  final GoalView v;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final s = v.state;
    final line = v.isPaydown
        ? '${aedMinor(s.currentMinor)} left of ${aedMinor(v.record.startMinor)}'
        : '${aedMinor(s.currentMinor)} of ${aedMinor(v.record.targetMinor)}';
    return ListRow(
      leading: GoalIcon(v.record.iconKey, kind: v.record.kind, size: 36),
      title: v.record.name,
      subtitle: '$line · ${paceLabel(v.pace)}',
      subtitleColor: v.pace == GoalPace.behind ? c.warning : null,
      chevron: true,
      onTap: onTap ?? () => context.push('${Routes.goals}/${v.id}'),
      trailing: ProgressRing(
        progress: s.progress,
        size: 34,
        stroke: 3.5,
        color: s.done ? c.positive : c.accent,
      ),
    );
  }
}

/// A glyph by key for the picker.
class GlyphKeyIcon extends StatelessWidget {
  const GlyphKeyIcon(this.glyphKey, {super.key, this.selected = false});
  final String glyphKey;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final g = glyphsByKey[glyphKey] ?? genericGlyph;
    return GlyphIcon(
      g,
      size: 26,
      filled: selected,
      color: selected ? c.accent : c.textSecondary,
    );
  }
}

String glyphsByKeyLabel(String key) => (glyphsByKey[key] ?? genericGlyph).label;
