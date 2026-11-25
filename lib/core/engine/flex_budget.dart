/// Flex budgeting: pure logic over whole minor units (fils), no floats.
///
/// Three groups. *Fixed* bills are tracked at their set amounts. *Flexible*
/// categories are pooled into one remaining number. *Non-monthly* costs
/// (annual fees, insurance, school terms, trips) are spread over the months
/// as sinking funds, and what is not spent rolls into the next month.
library;

enum BudgetGroup {
  fixed('fixed', 'Fixed'),
  flexible('flexible', 'Flexible'),
  nonMonthly('nonmonthly', 'Non-monthly');

  const BudgetGroup(this.key, this.label);
  final String key;
  final String label;

  static BudgetGroup? fromKey(String? k) {
    for (final g in values) {
      if (g.key == k) return g;
    }
    return null;
  }

  /// The group a category falls in when the user has not chosen one.
  static BudgetGroup resolve(String? stored, {required bool isFixed}) =>
      fromKey(stored) ?? (isFixed ? fixed : flexible);
}

// ---- months -----------------------------------------------------------------

/// `YYYY-MM-01` to a running month number (year * 12 + month - 1).
int monthIndex(String month) {
  final y = int.parse(month.substring(0, 4));
  final m = int.parse(month.substring(5, 7));
  return y * 12 + m - 1;
}

String monthKeyOf(int index) {
  final y = index ~/ 12, m = index % 12 + 1;
  return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-01';
}

String monthKeyFor(DateTime d) => monthKeyOf(d.year * 12 + d.month - 1);

// ---- spreading a cost over months ------------------------------------------------

/// [total] split into [months] whole-minor-unit parts that add up to exactly
/// [total]; the first `total % months` parts carry the extra unit.
List<int> spreadMinor(int total, int months) {
  if (months <= 0)
    throw ArgumentError.value(months, 'months', 'must be positive');
  if (total < 0)
    throw ArgumentError.value(total, 'total', 'must not be negative');
  final base = total ~/ months, extra = total % months;
  return [for (var i = 0; i < months; i++) i < extra ? base + 1 : base];
}

/// What to set aside in [month] for a cost of [costMinor] due every
/// [cycleMonths] months, counting cycle months from [anchor].
int sinkingContribution({
  required int costMinor,
  required int cycleMonths,
  required String anchor,
  required String month,
}) {
  final parts = spreadMinor(costMinor, cycleMonths);
  final offset = (monthIndex(month) - monthIndex(anchor)) % cycleMonths;
  return parts[offset < 0 ? offset + cycleMonths : offset];
}

// ---- rollover -------------------------------------------------------------------

class MonthPlan {
  const MonthPlan(this.month, this.plannedMinor, this.spentMinor);
  final String month;
  final int plannedMinor;
  final int spentMinor;
}

class RolloverMonth {
  const RolloverMonth({
    required this.month,
    required this.openingMinor,
    required this.plannedMinor,
    required this.spentMinor,
  });
  final String month;
  final int openingMinor;
  final int plannedMinor;
  final int spentMinor;

  /// What this month could spend: the carry plus this month's plan.
  int get availableMinor => openingMinor + plannedMinor;

  /// Carry into next month: last carry + planned - spent. Negative when
  /// overspent (the debt carries too).
  int get closingMinor => availableMinor - spentMinor;
}

/// Month-by-month balances: `closing = opening + planned - spent`, each
/// month opening with the previous closing. [months] must be consecutive and
/// ascending. [openingMinor] is the balance before the first month.
List<RolloverMonth> rolloverChain(
  List<MonthPlan> months, {
  int openingMinor = 0,
}) {
  final out = <RolloverMonth>[];
  var carry = openingMinor;
  int? prev;
  for (final m in months) {
    final i = monthIndex(m.month);
    if (prev != null && i != prev + 1) {
      throw ArgumentError('months must be consecutive: ${m.month}');
    }
    prev = i;
    final r = RolloverMonth(
      month: m.month,
      openingMinor: carry,
      plannedMinor: m.plannedMinor,
      spentMinor: m.spentMinor,
    );
    out.add(r);
    carry = r.closingMinor;
  }
  return out;
}

// ---- the three groups ------------------------------------------------------------

/// One category for one month, as the group maths sees it. [plannedMinor]
/// already includes any money moved in or out; [rolloverInMinor] is the
/// carry that opened the month (0 when the category does not roll over).
class PlanLine {
  const PlanLine({
    required this.id,
    required this.group,
    required this.plannedMinor,
    required this.spentMinor,
    this.rolloverInMinor = 0,
  });
  final String id;
  final BudgetGroup group;
  final int plannedMinor;
  final int spentMinor;
  final int rolloverInMinor;

  int get availableMinor => plannedMinor + rolloverInMinor;
  int get remainingMinor => availableMinor - spentMinor;
}

class FlexSummary {
  const FlexSummary({
    required this.availableMinor,
    required this.spentMinor,
    required this.overspentMinor,
    required this.categories,
  });

  /// Planned plus carried-in, summed over the flexible categories.
  final int availableMinor;
  final int spentMinor;

  /// How much of [spentMinor] sits above single-category limits. Shown for
  /// context only; the pool absorbs it.
  final int overspentMinor;
  final int categories;

  /// The one number: flexible left. Negative when the pool is overspent.
  int get remainingMinor => availableMinor - spentMinor;
  double get progress => availableMinor <= 0
      ? (spentMinor > 0 ? 1.5 : 0)
      : spentMinor / availableMinor;
}

/// Pools the flexible categories into one remaining amount: a category
/// overspent by 50 and another underspent by 50 leave the pool whole.
FlexSummary flexPool(Iterable<PlanLine> lines) {
  var avail = 0, spent = 0, over = 0, n = 0;
  for (final l in lines) {
    if (l.group != BudgetGroup.flexible) continue;
    n++;
    avail += l.availableMinor;
    spent += l.spentMinor;
    if (l.remainingMinor < 0) over += -l.remainingMinor;
  }
  return FlexSummary(
    availableMinor: avail,
    spentMinor: spent,
    overspentMinor: over,
    categories: n,
  );
}

enum BillStatus { upcoming, partial, paid, over }

class FixedBill {
  const FixedBill(this.id, this.plannedMinor, this.paidMinor);
  final String id;
  final int plannedMinor;
  final int paidMinor;

  BillStatus get status {
    if (paidMinor > plannedMinor && plannedMinor > 0) return BillStatus.over;
    if (plannedMinor > 0 && paidMinor >= plannedMinor) return BillStatus.paid;
    if (paidMinor > 0)
      return plannedMinor == 0 ? BillStatus.over : BillStatus.partial;
    return BillStatus.upcoming;
  }

  /// Still to pay at the set amount (never negative).
  int get dueMinor => plannedMinor > paidMinor ? plannedMinor - paidMinor : 0;
}

class FixedSummary {
  const FixedSummary(this.bills);
  final List<FixedBill> bills;
  int get plannedMinor => bills.fold(0, (a, b) => a + b.plannedMinor);
  int get paidMinor => bills.fold(0, (a, b) => a + b.paidMinor);
  int get dueMinor => bills.fold(0, (a, b) => a + b.dueMinor);
  int get paidCount => bills.where((b) => b.status == BillStatus.paid).length;
}

FixedSummary fixedBills(Iterable<PlanLine> lines) => FixedSummary([
  for (final l in lines)
    if (l.group == BudgetGroup.fixed)
      FixedBill(l.id, l.plannedMinor, l.spentMinor),
]);

/// A non-monthly category's sinking fund this month.
class SinkingFund {
  const SinkingFund({
    required this.id,
    required this.balanceMinor,
    required this.contributionMinor,
    required this.spentMinor,
    required this.costMinor,
    required this.cycleMonths,
  });
  final String id;

  /// Rolled-in balance that opened the month.
  final int balanceMinor;
  final int contributionMinor;
  final int spentMinor;

  /// The full cost per cycle (0 when the user only set a monthly amount).
  final int costMinor;
  final int cycleMonths;

  int get availableMinor => balanceMinor + contributionMinor;

  /// Carries into next month; negative if the bill came before it was funded.
  int get closingMinor => availableMinor - spentMinor;
  double get funded => costMinor <= 0
      ? 0
      : (closingMinor + spentMinor).clamp(0, costMinor) / costMinor;
}

class NonMonthlySummary {
  const NonMonthlySummary(this.funds);
  final List<SinkingFund> funds;
  int get contributionMinor => funds.fold(0, (a, f) => a + f.contributionMinor);
  int get balanceMinor =>
      funds.fold(0, (a, f) => a + f.availableMinor - f.spentMinor);
}

/// A flexible or fixed category that rolls over shows its carry on the row:
/// signed minor units, or null when there is none to show.
int? rolloverBadge(PlanLine l) =>
    l.rolloverInMinor == 0 ? null : l.rolloverInMinor;
