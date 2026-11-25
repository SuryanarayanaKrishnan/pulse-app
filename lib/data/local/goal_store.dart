import 'package:drift/drift.dart';

import '../../core/engine/dates.dart';
import '../../core/engine/goals.dart';
import '../goal_models.dart';
import 'database.dart';
import 'ids.dart';

String newGoalId() => newId();

/// Storage for goals and their contributions: the drift database, or memory
/// (demo data, web builds, tests).
abstract class GoalStore {
  Future<List<GoalRecord>> goals();
  Future<GoalRecord> saveGoal(GoalRecord g);

  /// Soft-deletes the goal and its contributions.
  Future<void> deleteGoal(String id);

  /// Every contribution, oldest first.
  Future<List<GoalContribution>> contributions();
  Future<GoalContribution> saveContribution(GoalContribution c);
  Future<void> deleteContribution(String id);
}

CalDate? _date(String? iso) {
  if (iso == null) return null;
  try {
    return CalDate.parse(iso);
  } catch (_) {
    return null;
  }
}

class LocalGoalStore implements GoalStore {
  LocalGoalStore(this.db);
  final PulseDatabase db;

  @override
  Future<List<GoalRecord>> goals() async => [
    for (final r in await (db.select(db.savingsGoals)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get())
      GoalRecord(
        id: r.id,
        name: r.name,
        kind: GoalKind.fromKey(r.kind),
        iconKey: r.iconKey,
        targetMinor: r.targetMinor,
        startMinor: r.savedMinor,
        targetDate: _date(r.targetDate),
        monthlyMinor: r.monthlyContributionMinor,
        linkedRef: r.linkedRef,
        paused: r.paused,
        completedAt: r.completedAt,
        createdAt: r.createdAt,
      ),
  ];

  @override
  Future<GoalRecord> saveGoal(GoalRecord g) async {
    await db.into(db.savingsGoals).insertOnConflictUpdate(
      SavingsGoalsCompanion(
        id: Value(g.id),
        name: Value(g.name),
        kind: Value(g.kind.key),
        iconKey: Value(g.iconKey),
        targetMinor: Value(g.targetMinor),
        savedMinor: Value(g.startMinor),
        targetDate: Value(g.targetDate?.toIso()),
        monthlyContributionMinor: Value(g.monthlyMinor),
        linkedRef: Value(g.linkedRef),
        paused: Value(g.paused),
        completedAt: Value(g.completedAt),
        createdAt: Value(g.createdAt),
        deletedAt: const Value(null),
      ),
    );
    return g;
  }

  @override
  Future<void> deleteGoal(String id) async {
    final now = Value(DateTime.now().toUtc());
    await (db.update(db.savingsGoals)..where((t) => t.id.equals(id))).write(SavingsGoalsCompanion(deletedAt: now));
    await (db.update(db.goalContributions)..where((t) => t.goalId.equals(id))).write(GoalContributionsCompanion(deletedAt: now));
  }

  @override
  Future<List<GoalContribution>> contributions() async => [
    for (final r in await (db.select(db.goalContributions)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.onDate), (t) => OrderingTerm.asc(t.createdAt)]))
        .get())
      if (_date(r.onDate) case final d?)
        GoalContribution(id: r.id, goalId: r.goalId, amountMinor: r.amountMinor, date: d, note: r.note),
  ];

  @override
  Future<GoalContribution> saveContribution(GoalContribution c) async {
    await db.into(db.goalContributions).insertOnConflictUpdate(
      GoalContributionsCompanion(
        id: Value(c.id),
        goalId: Value(c.goalId),
        amountMinor: Value(c.amountMinor),
        onDate: Value(c.date.toIso()),
        note: Value(c.note),
        deletedAt: const Value(null),
      ),
    );
    return c;
  }

  @override
  Future<void> deleteContribution(String id) => (db.update(db.goalContributions)..where((t) => t.id.equals(id))).write(
    GoalContributionsCompanion(deletedAt: Value(DateTime.now().toUtc())),
  );
}

class MemoryGoalStore implements GoalStore {
  MemoryGoalStore({List<GoalRecord> goals = const [], List<GoalContribution> contributions = const []})
    : _goals = [...goals],
      _contribs = [...contributions];
  final List<GoalRecord> _goals;
  final List<GoalContribution> _contribs;

  @override
  Future<List<GoalRecord>> goals() async => List.of(_goals);

  @override
  Future<GoalRecord> saveGoal(GoalRecord g) async {
    final i = _goals.indexWhere((e) => e.id == g.id);
    i < 0 ? _goals.add(g) : _goals[i] = g;
    return g;
  }

  @override
  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((e) => e.id == id);
    _contribs.removeWhere((e) => e.goalId == id);
  }

  @override
  Future<List<GoalContribution>> contributions() async => List.of(_contribs);

  @override
  Future<GoalContribution> saveContribution(GoalContribution c) async {
    final i = _contribs.indexWhere((e) => e.id == c.id);
    i < 0 ? _contribs.add(c) : _contribs[i] = c;
    return c;
  }

  @override
  Future<void> deleteContribution(String id) async => _contribs.removeWhere((e) => e.id == id);
}

/// A few believable goals for demo builds and screenshots.
MemoryGoalStore demoGoalStore({DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = CalDate(n.year, n.month, n.day);
  CalDate monthsAhead(int m) => addMonths(today, m);
  final goals = [
    GoalRecord(
      id: 'g_car', name: 'Save for a car', kind: GoalKind.save, iconKey: 'car',
      targetMinor: 6000000, startMinor: 1200000, targetDate: monthsAhead(14), monthlyMinor: 300000,
      createdAt: n.subtract(const Duration(days: 150)),
    ),
    GoalRecord(
      id: 'g_japan', name: 'Trip to Japan', kind: GoalKind.save, iconKey: 'travel',
      targetMinor: 2000000, startMinor: 300000, targetDate: monthsAhead(6), monthlyMinor: 150000,
      createdAt: n.subtract(const Duration(days: 100)),
    ),
    GoalRecord(
      id: 'g_card', name: 'Clear the card', kind: GoalKind.paydown, iconKey: 'fees',
      targetMinor: 0, startMinor: 900000, targetDate: monthsAhead(8), monthlyMinor: 100000,
      createdAt: n.subtract(const Duration(days: 80)),
    ),
  ];
  GoalContribution c(String id, String goal, int amount, int daysAgo) {
    final d = today.addDays(-daysAgo);
    return GoalContribution(id: id, goalId: goal, amountMinor: amount, date: d);
  }

  return MemoryGoalStore(goals: goals, contributions: [
    c('c1', 'g_car', 300000, 75), c('c2', 'g_car', 300000, 45), c('c3', 'g_car', 250000, 14),
    c('c4', 'g_japan', 100000, 60), c('c5', 'g_japan', 80000, 30), c('c6', 'g_japan', 60000, 5),
    c('c7', 'g_card', 100000, 50), c('c8', 'g_card', 120000, 20),
  ]);
}
