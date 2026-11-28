import '../core/engine/budget_moves.dart';
import '../core/engine/budget_overrun.dart';
import '../core/engine/flex_budget.dart';
import 'local/budget_plan_store.dart';
import 'local/ids.dart';
import 'models.dart';

/// One category's line in the flex budget for one month.
class PlanRow {
  const PlanRow({
    required this.id,
    required this.config,
    required this.line,
    required this.movedMinor,
    this.fund,
  });
  final String id;
  final CategoryPlan config;
  final PlanLine line;

  /// Net amount moved in (+) or out (-) this month.
  final int movedMinor;

  /// Set for Non-monthly categories.
  final SinkingFund? fund;

  BudgetGroup get group => config.group;
  int get plannedMinor => line.plannedMinor;
  int get spentMinor => line.spentMinor;

  /// Balance carried in from earlier months; null when the category does not
  /// roll over or has nothing carried.
  int? get carryMinor => config.rolls ? line.rolloverInMinor : null;
  int get remainingMinor => line.remainingMinor;
}

class BudgetPlanView {
  const BudgetPlanView({
    required this.month,
    required this.mode,
    required this.rows,
    required this.flex,
    required this.fixed,
    required this.nonMonthly,
    required this.moves,
  });
  final String month;
  final BudgetMode mode;
  final List<PlanRow> rows;
  final FlexSummary flex;
  final FixedSummary fixed;
  final NonMonthlySummary nonMonthly;

  /// This month's moves in Mine scope, newest first (for undo).
  final List<BudgetMove> moves;

  Iterable<PlanRow> inGroup(BudgetGroup g) => rows.where((r) => r.group == g);
  PlanRow? row(String id) => rows.where((r) => r.id == id).firstOrNull;
  int get plannedMinor => rows.fold(0, (a, r) => a + r.plannedMinor);
  int get spentMinor => rows.fold(0, (a, r) => a + r.spentMinor);
}

/// One category that is over plan now, with everything the screen needs.
class OverrunItem {
  const OverrunItem(this.overrun, this.category, this.funding);
  final CategoryOverrun overrun;
  final SpendCategory category;

  /// Where a suggested raise could come from. Null unless a raise is suggested.
  final FundingHint? funding;
}

class OverrunReport {
  const OverrunReport(this.items);
  static const empty = OverrunReport([]);
  final List<OverrunItem> items;

  /// Names for the funding sentence.
  String labelOf(String id) {
    for (final i in items) {
      if (i.category.id == id) return i.category.label;
    }
    return SpendCategory.byId(id)?.label ?? 'another category';
  }
}

/// Works out the flex budget from the stored plan and the ledger. The maths
/// is in `core/engine`; this gathers inputs and applies changes.
class BudgetPlanService {
  BudgetPlanService({
    required this.store,
    required this.transactions,
    this.onModeChanged,
    this.onMoved,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final BudgetPlanStore store;
  final Future<List<Transaction>> Function() transactions;
  final void Function(BudgetMode mode)? onModeChanged;
  final void Function()? onMoved;
  final DateTime Function() _clock;

  String get thisMonth => monthKeyFor(_clock());

  Future<BudgetMode> mode() => store.mode();

  Future<void> setMode(BudgetMode m) async {
    if (await store.mode() == m) return;
    await store.setMode(m);
    onModeChanged?.call(m);
  }

  /// The limit in force for [cat] in [month]: the latest set at or before it.
  static int effectiveLimit(List<LimitRow> limits, String cat, String month) {
    LimitRow? best;
    for (final l in limits) {
      if (l.categoryId != cat || l.month.compareTo(month) > 0) continue;
      if (best == null || l.month.compareTo(best.month) > 0) best = l;
    }
    return best?.limitMinor ?? 0;
  }

  /// What [c] plans for [month], before moves.
  static int basePlanned(
    CategoryPlan c,
    List<LimitRow> limits,
    String month,
    String anchor,
  ) {
    if (c.group == BudgetGroup.nonMonthly && c.cycleCostMinor > 0) {
      return sinkingContribution(
        costMinor: c.cycleCostMinor,
        cycleMonths: c.cycleMonths < 1 ? 1 : c.cycleMonths,
        anchor: anchor,
        month: month,
      );
    }
    return effectiveLimit(limits, c.id, month);
  }

  /// Spend per category per month. Income, transfers and excluded payments
  /// do not count.
  static Map<String, Map<String, int>> spendByMonth(Iterable<Transaction> txs) {
    final out = <String, Map<String, int>>{};
    for (final t in txs) {
      if (t.isIncome ||
          t.excluded ||
          t.category.isTransfer ||
          t.category.isIncome)
        continue;
      final m = monthKeyFor(t.date);
      final byMonth = out.putIfAbsent(t.category.id, () => {});
      byMonth[m] = (byMonth[m] ?? 0) + (t.amount * 100).round();
    }
    return out;
  }

  Future<BudgetPlanView> view(DateTime month) async {
    final key = monthKeyFor(month);
    final (mode, cats, limits, moves, txs) = await (
      store.mode(),
      store.categories(),
      store.limits(),
      store.moves(),
      transactions(),
    ).wait;
    final spend = spendByMonth(txs);
    final firstLimit = <String, String>{};
    for (final l in limits) {
      final cur = firstLimit[l.categoryId];
      if (cur == null || l.month.compareTo(cur) < 0)
        firstLimit[l.categoryId] = l.month;
    }
    final here = monthIndex(key);

    // Planned per category in a month, moves applied (Mine scope).
    Map<String, int> plannedIn(String m) {
      final base = <String, int>{
        for (final c in cats)
          if (c.isExpense && !c.hidden)
            c.id: basePlanned(
              c,
              limits,
              m,
              c.rolloverStart ?? firstLimit[c.id] ?? key,
            ),
      };
      return applyMoves(base, moves, month: m, scope: MoveScope.mine);
    }

    final plannedHere = plannedIn(key);
    final rows = <PlanRow>[];
    for (final c in cats) {
      if (!c.isExpense || c.hidden) continue;
      final anchor = c.rolloverStart ?? firstLimit[c.id] ?? key;
      var carry = 0;
      if (c.rolls) {
        final start = monthIndex(anchor);
        // Bounded so a very old start cannot make a view slow.
        final from = start < here - 120 ? here - 120 : start;
        if (from < here) {
          final plans = [
            for (var i = from; i < here; i++)
              MonthPlan(
                monthKeyOf(i),
                plannedIn(monthKeyOf(i))[c.id] ?? 0,
                spend[c.id]?[monthKeyOf(i)] ?? 0,
              ),
          ];
          carry = rolloverChain(
            plans,
            openingMinor: from == start ? c.rolloverStartMinor : 0,
          ).last.closingMinor;
        } else if (start == here) {
          carry = c.rolloverStartMinor;
        }
      }
      final planned = plannedHere[c.id] ?? 0;
      final spent = spend[c.id]?[key] ?? 0;
      final moved =
          moveDeltas(moves, month: key, scope: MoveScope.mine)[c.id] ?? 0;
      if (planned == 0 && spent == 0 && carry == 0 && moved == 0) continue;
      final line = PlanLine(
        id: c.id,
        group: c.group,
        plannedMinor: planned,
        spentMinor: spent,
        rolloverInMinor: carry,
      );
      rows.add(
        PlanRow(
          id: c.id,
          config: c,
          line: line,
          movedMinor: moved,
          fund: c.group == BudgetGroup.nonMonthly
              ? SinkingFund(
                  id: c.id,
                  balanceMinor: carry,
                  contributionMinor: planned,
                  spentMinor: spent,
                  costMinor: c.cycleCostMinor,
                  cycleMonths: c.cycleMonths,
                )
              : null,
        ),
      );
    }
    rows.sort((a, b) {
      final c = b.plannedMinor.compareTo(a.plannedMinor);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    final lines = [for (final r in rows) r.line];
    return BudgetPlanView(
      month: key,
      mode: mode,
      rows: rows,
      flex: flexPool(lines),
      fixed: fixedBills(lines),
      nonMonthly: NonMonthlySummary([for (final r in rows) ?r.fund]),
      moves: [
        for (final m in moves.reversed)
          if (m.month == key && m.scope == MoveScope.mine) m,
      ],
    );
  }

  /// Which categories are over plan this month, one-off or recurring, from
  /// the last six months of plan against spend. [marked] holds the months the
  /// person called a one-off, by category id. Non-monthly (sinking fund)
  /// categories are left out: they are meant to swing.
  Future<OverrunReport> overruns({
    Map<String, Set<String>> marked = const {},
  }) async {
    final key = monthKeyFor(_clock());
    final (cats, limits, moves, txs) = await (
      store.categories(),
      store.limits(),
      store.moves(),
      transactions(),
    ).wait;
    final spend = spendByMonth(txs);
    final firstLimit = <String, String>{};
    for (final l in limits) {
      final cur = firstLimit[l.categoryId];
      if (cur == null || l.month.compareTo(cur) < 0)
        firstLimit[l.categoryId] = l.month;
    }
    final here = monthIndex(key);
    final keys = [
      for (var i = overrunLookback; i >= 0; i--) monthKeyOf(here - i),
    ];
    final planned = {
      for (final m in keys)
        m: applyMoves(
          {
            for (final c in cats)
              if (c.isExpense && !c.hidden && c.group != BudgetGroup.nonMonthly)
                c.id: basePlanned(
                  c,
                  limits,
                  m,
                  c.rolloverStart ?? firstLimit[c.id] ?? key,
                ),
          },
          moves,
          month: m,
          scope: MoveScope.mine,
        ),
    };
    final window = keys.toSet();
    // Months before the first payment on record say nothing: a budget set long
    // ago with no ledger behind it is not "normal months".
    String? firstSeen;
    for (final t in txs) {
      final tm = monthKeyFor(t.date);
      if (firstSeen == null || tm.compareTo(firstSeen) < 0) firstSeen = tm;
    }
    final catOf = <String, SpendCategory>{};
    final txsBy = <String, List<OverrunTx>>{};
    for (final t in txs) {
      if (t.isIncome ||
          t.excluded ||
          t.pendingHold ||
          t.category.isTransfer ||
          t.category.isIncome)
        continue;
      final m = monthKeyFor(t.date);
      if (!window.contains(m)) continue;
      catOf[t.category.id] = t.category;
      txsBy
          .putIfAbsent(t.category.id, () => [])
          .add(
            OverrunTx(
              id: t.id,
              month: m,
              merchant: t.merchant,
              amountMinor: (t.amount * 100).round(),
            ),
          );
    }
    final inputs = <OverrunInput>[];
    final slack = <Slack>[];
    for (final c in cats) {
      if (!c.isExpense || c.hidden || c.group == BudgetGroup.nonMonthly)
        continue;
      final months = [
        for (final m in keys)
          if (firstSeen != null && m.compareTo(firstSeen) >= 0)
            MonthAmount(m, planned[m]?[c.id] ?? 0, spend[c.id]?[m] ?? 0),
      ];
      inputs.add(
        OverrunInput(
          categoryId: c.id,
          months: months,
          txs: txsBy[c.id] ?? const [],
          markedOneOff: marked[c.id] ?? const {},
        ),
      );
      if (months.isEmpty || months.last.month != key) continue;
      final now = months.last;
      if (c.group == BudgetGroup.flexible &&
          now.plannedMinor > now.spentMinor) {
        slack.add(Slack(c.id, now.plannedMinor - now.spentMinor));
      }
    }
    final found = analyseOverruns(inputs, currentMonth: key);
    final report = OverrunReport([
      for (final o in found)
        if (catOf[o.categoryId] != null)
          OverrunItem(
            o,
            catOf[o.categoryId]!,
            o.suggestedCeilingMinor == null
                ? null
                : fundingHint(
                    extraMinor: o.suggestedCeilingMinor! - o.plannedMinor,
                    slack: slack,
                    exceptId: o.categoryId,
                  ),
          ),
    ]);
    return report;
  }

  /// Moves [amountMinor] of [month]'s plan from one category to another.
  /// Returns the move, or the reason it was refused. In Joint scope the
  /// caller passes the joint limit it is moving from as [sourcePlannedMinor].
  Future<(BudgetMove?, MoveProblem?)> move({
    required DateTime month,
    required String fromId,
    required String toId,
    required int amountMinor,
    MoveScope scope = MoveScope.mine,
    int? sourcePlannedMinor,
  }) async {
    final key = monthKeyFor(month);
    final source =
        sourcePlannedMinor ??
        (await view(month)).row(fromId)?.plannedMinor ??
        0;
    final problem = checkMove(
      fromId: fromId,
      toId: toId,
      amountMinor: amountMinor,
      sourcePlannedMinor: source,
    );
    if (problem != null) return (null, problem);
    final m = BudgetMove(
      id: newId('mv_'),
      month: key,
      fromId: fromId,
      toId: toId,
      amountMinor: amountMinor,
      scope: scope,
    );
    await store.addMove(m);
    onMoved?.call();
    return (m, null);
  }

  Future<void> undoMove(String id) => store.undoMove(id);

  Future<List<BudgetMove>> allMoves() => store.moves();

  Future<void> saveCategoryPlan(CategoryPlan c) => store.saveCategoryPlan(c);

  /// Sets the monthly amount from [month] on (a limit row for that month).
  Future<void> setMonthly(String categoryId, DateTime month, int minor) =>
      store.saveLimit(categoryId, monthKeyFor(month), minor < 0 ? 0 : minor);
}
