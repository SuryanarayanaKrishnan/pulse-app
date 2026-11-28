import '../core/engine/dates.dart';
import '../core/engine/goals.dart';
import 'goal_models.dart';
import 'local/goal_store.dart';
import 'models.dart';

/// Turns stored goals into worked-out views and makes the changes. Pure
/// logic lives in `core/engine/goals.dart`; this only gathers inputs.
class GoalService {
  GoalService({
    required this.store,
    required this.assets,
    DateTime Function()? clock,
    this.onCompleted,
  }) : _clock = clock ?? DateTime.now;

  final GoalStore store;

  /// The Wealth list, to read what a linked goal is linked to.
  final Future<List<Asset>> Function() assets;
  final DateTime Function() _clock;

  /// Called once when a goal newly reaches its target.
  final void Function()? onCompleted;

  CalDate get today {
    final n = _clock();
    return CalDate(n.year, n.month, n.day);
  }

  /// Engine inputs for every goal (also what safe-to-spend reads).
  static List<GoalInput> inputs(
    List<GoalRecord> goals,
    List<GoalContribution> contribs,
    Map<String, Asset> linked,
  ) => [
    for (final g in goals)
      GoalInput(
        id: g.id,
        name: g.name,
        kind: g.kind,
        targetMinor: g.targetMinor,
        startMinor: g.startMinor,
        linkedMinor: switch (linked[g.linkedRef]) {
          final a? => (a.value * 100).round(),
          null => null,
        },
        targetDate: g.targetDate,
        plannedMonthlyMinor: g.monthlyMinor,
        paused: g.paused,
        createdOn: CalDate(
          g.createdAt.year,
          g.createdAt.month,
          g.createdAt.day,
        ),
        contributions: [
          for (final c in contribs)
            if (c.goalId == g.id) ContributionPoint(c.date, c.amountMinor),
        ],
      ),
  ];

  Future<List<GoalView>> views() async {
    final (goals, contribs) = (
      await store.goals(),
      await store.contributions(),
    );
    // Only read the Wealth list when a goal follows something in it.
    final needsAssets = goals.any((g) => g.linkedRef != null);
    final byId = needsAssets
        ? {for (final a in await assets()) a.id: a}
        : <String, Asset>{};
    final ins = inputs(goals, contribs, byId);
    final now = today;
    final reserved = {
      for (final r in goalReservations(ins, now)) r.goalId: r.amountMinor,
    };
    final out = <GoalView>[];
    for (var i = 0; i < goals.length; i++) {
      var g = goals[i];
      final input = ins[i];
      final state = goalState(input);
      if (state.done && g.completedAt == null) {
        g = await store.saveGoal(g.copyWith(completedAt: _clock().toUtc()));
        onCompleted?.call();
      } else if (!state.done && g.completedAt != null) {
        g = await store.saveGoal(g.copyWith(clearCompleted: true));
      }
      out.add(
        GoalView(
          record: g,
          input: input,
          state: state,
          pace: goalPace(input, now),
          plannedMinor: plannedMonthly(input, now),
          suggestedMinor: suggestedMonthly(input, now),
          reservedMinor: reserved[g.id] ?? 0,
          projected: projectedCompletion(input, now),
          linkedName: byId[g.linkedRef]?.name,
          contributions: [
            for (final c in contribs.reversed)
              if (c.goalId == g.id) c,
          ],
        ),
      );
    }
    // Active first, finished last; otherwise the order they were made in.
    out.sort((a, b) => (a.state.done ? 1 : 0).compareTo(b.state.done ? 1 : 0));
    return out;
  }

  Future<GoalView?> view(String id) async =>
      (await views()).where((v) => v.id == id).firstOrNull;

  Future<GoalRecord> save(GoalRecord g) => store.saveGoal(g);

  Future<void> delete(String id) => store.deleteGoal(id);

  Future<void> setPaused(String id, bool paused) async {
    final g = (await store.goals()).where((e) => e.id == id).firstOrNull;
    if (g != null) await store.saveGoal(g.copyWith(paused: paused));
  }

  /// Adds money (or, with a negative amount, takes it back). A pay down
  /// goal's positive amount is a payment.
  Future<void> contribute(
    String goalId,
    int amountMinor, {
    CalDate? on,
    String? note,
  }) async {
    await store.saveContribution(
      GoalContribution(
        id: newGoalId(),
        goalId: goalId,
        amountMinor: amountMinor,
        date: on ?? today,
        note: (note == null || note.trim().isEmpty) ? null : note.trim(),
      ),
    );
    await views(); // settles completion
  }

  Future<void> removeContribution(String id) async {
    await store.deleteContribution(id);
    await views();
  }
}
