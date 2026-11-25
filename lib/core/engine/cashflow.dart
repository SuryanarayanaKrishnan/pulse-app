/// Monthly cashflow, the daily balance projection, safe-to-spend and goal
/// arithmetic (pure). Port of `cashflow.py`, `safe_to_spend.py`, `goals.py`.
library;

import 'dart:math' as math;

import 'dates.dart';
import 'types.dart';

const notIncome = {'transfer', 'cc_payment'};
const notSpend = {'transfer', 'cc_payment', 'savings'};

class Flow {
  const Flow(
    this.day,
    this.amountMinor, {
    required this.isCredit,
    this.slug,
    this.excluded = false,
  });
  final CalDate day;
  final int amountMinor;
  final bool isCredit;
  final String? slug;

  /// exclude_from_budget.
  final bool excluded;
}

class MonthFlow {
  MonthFlow(this.month);
  final CalDate month;
  int incomeMinor = 0, spendMinor = 0, savedMinor = 0;
  int get netMinor => incomeMinor - spendMinor;
  double? get savingsRate =>
      incomeMinor > 0 ? roundTo(netMinor / incomeMinor, 4) : null;
}

CalDate monthStart(CalDate d) => CalDate(d.year, d.month, 1);

/// First days of the [n] months ending with the current month, oldest first.
List<CalDate> monthsBack(CalDate today, int n) {
  final idx = today.year * 12 + today.month - 1;
  return [
    for (var i = n - 1; i >= 0; i--)
      CalDate((idx - i) ~/ 12, (idx - i) % 12 + 1, 1),
  ];
}

bool isIncome(Flow f) =>
    f.isCredit && !notIncome.contains(f.slug) && !f.excluded;
bool isSpend(Flow f) =>
    !f.isCredit && !notSpend.contains(f.slug) && !f.excluded;

List<MonthFlow> monthlyCashflow(List<Flow> flows, CalDate today, [int n = 12]) {
  final rows = {for (final m in monthsBack(today, n)) m: MonthFlow(m)};
  for (final f in flows) {
    final row = rows[monthStart(f.day)];
    if (row == null) continue;
    if (isIncome(f)) {
      row.incomeMinor += f.amountMinor;
    } else if (isSpend(f)) {
      row.spendMinor += f.amountMinor;
    } else if (!f.isCredit && f.slug == 'savings' && !f.excluded) {
      row.savedMinor += f.amountMinor;
    }
  }
  return rows.values.toList();
}

class FlowEvent {
  const FlowEvent(this.day, this.label, this.amountMinor, this.kind);
  final CalDate day;
  final String label;

  /// Negative = money out.
  final int amountMinor;

  /// bill | loan | card_due | salary
  final String kind;
}

class ProjectedDay {
  ProjectedDay(this.day, this.balanceMinor, this.events);
  final CalDate day;
  final int balanceMinor;
  final List<FlowEvent> events;
}

/// Day-by-day balance: each day spends the average variable amount, then
/// scheduled events land.
List<ProjectedDay> projectBalance(
  int startBalanceMinor,
  CalDate today,
  int days,
  List<FlowEvent> events,
  int dailyVariableMinor,
) {
  final byDay = <CalDate, List<FlowEvent>>{};
  for (final e in events) {
    byDay.putIfAbsent(e.day, () => []).add(e);
  }
  final out = <ProjectedDay>[];
  var bal = startBalanceMinor;
  for (var i = 0; i <= days; i++) {
    final d = today.addDays(i);
    if (i > 0) bal -= dailyVariableMinor;
    final evs = byDay[d] ?? const <FlowEvent>[];
    bal += evs.fold<int>(0, (a, e) => a + e.amountMinor);
    out.add(ProjectedDay(d, bal, List.of(evs)));
  }
  return out;
}

// ---- safe to spend ---------------------------------------------------------

class Commitment {
  const Commitment(this.kind, this.label, this.amountMinor, [this.dueOn]);

  /// bill | loan | card_due | goal
  final String kind;
  final String label;
  final int amountMinor;
  final CalDate? dueOn;
}

class SafeToSpendResult {
  const SafeToSpendResult({
    required this.liquidMinor,
    required this.committedMinor,
    required this.safeMinor,
    required this.perDayMinor,
    required this.daysLeft,
    required this.status,
    required this.byKind,
  });
  final int? liquidMinor;
  final int committedMinor;
  final int? safeMinor;
  final int? perDayMinor;
  final int daysLeft;

  /// ok | shortfall | unknown
  final String status;
  final Map<String, int> byKind;
}

SafeToSpendResult computeSafeToSpend(
  int? liquidMinor,
  List<Commitment> commitments,
  CalDate today,
  CalDate horizonEnd,
) {
  final daysLeft = math.max(1, horizonEnd.daysSince(today));
  final byKind = <String, int>{};
  for (final c in commitments) {
    byKind[c.kind] = (byKind[c.kind] ?? 0) + c.amountMinor;
  }
  final total = byKind.values.fold<int>(0, (a, b) => a + b);
  if (liquidMinor == null) {
    return SafeToSpendResult(
      liquidMinor: null,
      committedMinor: total,
      safeMinor: null,
      perDayMinor: null,
      daysLeft: daysLeft,
      status: 'unknown',
      byKind: byKind,
    );
  }
  final safe = liquidMinor - total;
  return SafeToSpendResult(
    liquidMinor: liquidMinor,
    committedMinor: total,
    safeMinor: safe,
    perDayMinor: math.max(0, safe) ~/ daysLeft,
    daysLeft: daysLeft,
    status: safe >= 0 ? 'ok' : 'shortfall',
    byKind: byKind,
  );
}

// ---- goals -------------------------------------------------------------------

/// Whole months from today to the target date, at least 1 while the goal is in
/// the future.
int? goalMonthsLeft(CalDate today, CalDate? target) {
  if (target == null || target <= today) return null;
  var months = (target.year - today.year) * 12 + target.month - today.month;
  if (target.day < today.day) months -= 1;
  return math.max(1, months);
}

int? requiredMonthly(int remainingMinor, CalDate today, CalDate? target) {
  if (remainingMinor <= 0) return 0;
  final m = goalMonthsLeft(today, target);
  return m == null ? null : (remainingMinor / m).ceil();
}

/// Monthly amount to set aside: the plan if set, else what the deadline
/// needs, capped at what is left.
int monthlyReserve(
  int remainingMinor,
  int? planned,
  CalDate today,
  CalDate? target,
) {
  if (remainingMinor <= 0) return 0;
  final amount =
      planned ?? (requiredMonthly(remainingMinor, today, target) ?? 0);
  return math.min(amount, remainingMinor);
}
