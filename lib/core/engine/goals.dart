/// Goals: progress, pace, projected completion and the monthly amount a goal
/// reserves from safe-to-spend (pure Dart, no storage, no Flutter).
///
/// Two kinds. `save` grows towards a target (a car, a trip, an emergency
/// fund). `paydown` is a liability going to the target (usually zero).
library;

import 'dart:math' as math;

import 'cashflow.dart' show goalMonthsLeft, monthlyReserve, requiredMonthly;
import 'dates.dart';

enum GoalKind {
  save('save'),
  paydown('paydown');

  const GoalKind(this.key);
  final String key;
  static GoalKind fromKey(Object? k) => k == 'paydown' ? paydown : save;
}

/// Money added (positive) or taken back (negative) on a day. For a pay down
/// goal a positive amount is a payment towards the balance.
class ContributionPoint {
  const ContributionPoint(this.date, this.amountMinor);
  final CalDate date;
  final int amountMinor;
}

class GoalInput {
  const GoalInput({
    required this.id,
    this.name = '',
    required this.kind,
    required this.targetMinor,
    this.startMinor = 0,
    this.linkedMinor,
    this.targetDate,
    this.plannedMonthlyMinor,
    this.paused = false,
    required this.createdOn,
    this.contributions = const [],
  });
  final String id;
  final String name;
  final GoalKind kind;

  /// Save: the amount to reach. Pay down: the balance to reach (0 = cleared).
  final int targetMinor;

  /// Save: what you already had. Pay down: the balance owed when you began.
  final int startMinor;

  /// Current value of the linked account, asset or liability, when linked.
  /// A linked goal reads its progress from there, not from contributions.
  final int? linkedMinor;
  final CalDate? targetDate;
  final int? plannedMonthlyMinor;
  final bool paused;
  final CalDate createdOn;
  final List<ContributionPoint> contributions;
}

class GoalState {
  const GoalState({
    required this.currentMinor,
    required this.remainingMinor,
    required this.progress,
    required this.done,
  });

  /// Save: what you have. Pay down: what is still owed.
  final int currentMinor;
  final int remainingMinor;

  /// 0..1.
  final double progress;
  final bool done;
}

int netContributed(GoalInput g) =>
    g.contributions.fold(0, (a, c) => a + c.amountMinor);

GoalState goalState(GoalInput g) {
  if (g.kind == GoalKind.save) {
    final current = g.linkedMinor ?? g.startMinor + netContributed(g);
    final remaining = math.max(0, g.targetMinor - current);
    final p = g.targetMinor <= 0
        ? 1.0
        : (current / g.targetMinor).clamp(0.0, 1.0);
    return GoalState(
      currentMinor: current,
      remainingMinor: remaining,
      progress: p,
      done: g.targetMinor > 0 && remaining == 0,
    );
  }
  final owed = g.linkedMinor ?? g.startMinor - netContributed(g);
  final remaining = math.max(0, owed - g.targetMinor);
  final span = g.startMinor - g.targetMinor;
  final p = span <= 0
      ? (remaining == 0 ? 1.0 : 0.0)
      : ((g.startMinor - owed) / span).clamp(0.0, 1.0);
  return GoalState(
    currentMinor: owed,
    remainingMinor: remaining,
    progress: p,
    done: remaining == 0,
  );
}

/// What the deadline asks for each month, or null with no deadline.
int? suggestedMonthly(GoalInput g, CalDate today) =>
    requiredMonthly(goalState(g).remainingMinor, today, g.targetDate);

/// The monthly amount the goal plans: your own figure, else the suggestion,
/// never more than what is left. Zero when done.
int plannedMonthly(GoalInput g, CalDate today) => monthlyReserve(
  goalState(g).remainingMinor,
  g.plannedMonthlyMinor,
  today,
  g.targetDate,
);

CalDate addMonths(CalDate d, int months) {
  final idx = d.year * 12 + d.month - 1 + months;
  final y = idx ~/ 12, m = idx % 12 + 1;
  final dim = DateTime.utc(y, m + 1, 0).day;
  return CalDate(y, m, math.min(d.day, dim));
}

/// Net money per month over the last three months (fewer if the goal is
/// younger). Null when nothing was added in that window.
int? recentPaceMinor(GoalInput g, CalDate today) {
  final from = today.addDays(-90);
  final inWindow = [
    for (final c in g.contributions)
      if (c.date > from && c.date <= today) c,
  ];
  if (inWindow.isEmpty) return null;
  final net = inWindow.fold<int>(0, (a, c) => a + c.amountMinor);
  final age = today.daysSince(g.createdOn);
  final months = (math.min(90, math.max(30, age)) / 30).clamp(1.0, 3.0);
  return (net / months).round();
}

/// The pace the projection uses: what you have really been adding, else the
/// plan (unless paused). Null when neither says anything.
int? effectivePaceMinor(GoalInput g, CalDate today) {
  final recent = recentPaceMinor(g, today);
  if (recent != null && recent > 0) return recent;
  if (!g.paused) {
    final plan = plannedMonthly(g, today);
    if (plan > 0 && recent == null) return plan;
  }
  return null;
}

/// When the goal finishes at the current pace. Null when done or unknowable.
CalDate? projectedCompletion(GoalInput g, CalDate today) {
  final s = goalState(g);
  if (s.done) return null;
  final pace = effectivePaceMinor(g, today);
  if (pace == null || pace <= 0) return null;
  return addMonths(today, (s.remainingMinor / pace).ceil());
}

enum GoalPace { done, paused, onTrack, behind, noDeadline, noPace }

GoalPace goalPace(GoalInput g, CalDate today) {
  final s = goalState(g);
  if (s.done) return GoalPace.done;
  if (g.paused) return GoalPace.paused;
  final pace = effectivePaceMinor(g, today);
  if (g.targetDate == null)
    return pace == null ? GoalPace.noPace : GoalPace.noDeadline;
  if (pace == null || pace <= 0) return GoalPace.noPace;
  final left = goalMonthsLeft(today, g.targetDate) ?? 0;
  final need = (s.remainingMinor / pace).ceil();
  return need <= left ? GoalPace.onTrack : GoalPace.behind;
}

// ---- safe to spend -------------------------------------------------------

class GoalReservation {
  const GoalReservation(this.goalId, this.name, this.amountMinor);
  final String goalId;
  final String name;
  final int amountMinor;
}

/// What each active goal sets aside from this month's safe-to-spend.
///
/// The planned monthly amount, less what you already put in this calendar
/// month (that money has moved, so it is no longer waiting in your cash).
/// Paused and finished goals reserve nothing.
List<GoalReservation> goalReservations(List<GoalInput> goals, CalDate today) {
  final out = <GoalReservation>[];
  for (final g in goals) {
    if (g.paused || goalState(g).done) continue;
    final plan = plannedMonthly(g, today);
    final thisMonth = g.contributions
        .where((c) => c.date.year == today.year && c.date.month == today.month)
        .fold<int>(0, (a, c) => a + c.amountMinor);
    final int amount = math.max<int>(0, plan - math.max<int>(0, thisMonth));
    if (amount > 0) out.add(GoalReservation(g.id, g.name, amount));
  }
  return out;
}

int totalReserved(List<GoalReservation> r) =>
    r.fold(0, (a, e) => a + e.amountMinor);
