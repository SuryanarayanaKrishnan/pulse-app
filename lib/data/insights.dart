import 'dart:math' as math;

import 'models.dart';

/// One month of cashflow.
class CashflowMonth {
  const CashflowMonth(this.label, this.income, this.spend);
  final String label;
  final double income;
  final double spend;
  double get saved => income - spend;
  double get savingsRate => income <= 0 ? 0 : saved / income;
}

class Cashflow {
  const Cashflow({
    required this.months,
    required this.balanceNow,
    required this.projectedEndBalance,
    required this.committed,
  });

  /// Oldest first; the last month is the current one (partial).
  final List<CashflowMonth> months;

  /// Cash across current and savings accounts today.
  final double balanceNow;

  /// Expected balance on the last day of the month after remaining typical
  /// spend and known commitments.
  final double projectedEndBalance;

  /// Known outflows still to come this month (bills, card dues).
  final double committed;
}

/// Month-by-month spend for one category.
class CategoryTrend {
  const CategoryTrend(this.category, this.values);
  final SpendCategory category;
  final List<double> values;
  double get average =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
}

class CategoryTrends {
  const CategoryTrends(this.labels, this.series);
  final List<String> labels;
  final List<CategoryTrend> series;
}

/// Money you can spend today without touching what is already promised.
class SafeToSpend {
  const SafeToSpend({
    required this.today,
    required this.available,
    required this.bills,
    required this.cardDues,
    required this.goals,
    required this.daysLeft,
    this.goalLines = const [],
    this.cash = double.infinity,
    this.budgetLeft = double.infinity,
    this.basis = SafeBasis.categories,
  });

  /// Cash in the bank, used for the cash limit.
  final double cash;

  /// What the budget has left before bills and goals come off
  /// (infinity when no budget is set).
  final double budgetLeft;

  /// Which budget [budgetLeft] was read from.
  final SafeBasis basis;

  /// Per-day allowance for the rest of the month.
  final double today;

  /// What is free for discretionary spending until month end.
  final double available;
  final double bills;
  final double cardDues;
  final double goals;
  final int daysLeft;

  /// What each active goal sets aside (they add up to [goals]).
  final List<GoalLine> goalLines;

  /// The same figures, with the budget left taken from [left] (for example
  /// the Flex pool). This is the one place the maths lives.
  SafeToSpend withBudget(double left, SafeBasis b) => computeSafeToSpend(
    cash: cash,
    budgetLeft: left,
    bills: bills,
    cardDues: cardDues,
    goals: goals,
    daysLeft: daysLeft,
    goalLines: goalLines,
    basis: b,
  );
}

/// Where the budget figure behind safe-to-spend comes from.
enum SafeBasis { flex, categories }

/// One goal's share of the money set aside this month.
class GoalLine {
  const GoalLine(this.id, this.name, this.amount);
  final String id, name;
  final double amount;
}

/// Safe-to-spend today, spread over the remaining days (today included).
///
/// Two limits apply and the lower wins:
///  * the budget: what is left this month (in Flex mode, the Flexible left on
///    the Budget tab), less bills that are still to come and goal
///    contributions;
///  * the cash: what is in the bank, less those bills, goals and the card
///    dues that fall before month end.
SafeToSpend computeSafeToSpend({
  required double cash,
  required double budgetLeft,
  required double bills,
  required double cardDues,
  required double goals,
  required int daysLeft,
  List<GoalLine> goalLines = const [],
  SafeBasis basis = SafeBasis.categories,
}) {
  final byBudget = budgetLeft - bills - goals;
  final byCash = cash - bills - cardDues - goals;
  final available = math.max(0.0, math.min(byBudget, byCash));
  final days = math.max(1, daysLeft);
  return SafeToSpend(
    today: available / days,
    available: available,
    bills: bills,
    cardDues: cardDues,
    goals: goals,
    daysLeft: days,
    goalLines: goalLines,
    cash: cash,
    budgetLeft: budgetLeft,
    basis: basis,
  );
}

/// One input to the health score, 0..1, with a plain-language reading.
class HealthFactor {
  const HealthFactor(this.name, this.score, this.reading);
  final String name;
  final double score;
  final String reading;
}

class HealthScore {
  const HealthScore(
    this.score,
    this.factors,
    this.readiness, {
    this.insufficient = false,
  });

  /// Not enough data to score yet (an empty on-device ledger).
  final bool insufficient;

  /// 0..100.
  final int score;
  final List<HealthFactor> factors;

  /// One calm line for today.
  final String readiness;

  String get band => score >= 80
      ? 'Strong'
      : score >= 60
      ? 'Steady'
      : score >= 40
      ? 'Needs care'
      : 'Under strain';
}

double _clamp01(double v) => v.isNaN ? 0 : v.clamp(0.0, 1.0);

/// Weighted score from four inputs:
///  * savings rate (target 20%): 30%
///  * card utilisation (best under 10%, poor above 50%): 25%
///  * bills paid on time, last 12 months: 25%
///  * emergency runway in months of spend (target 6): 20%
HealthScore computeHealthScore({
  required double savingsRate,
  required double utilisation,
  required double onTimeRate,
  required double runwayMonths,
}) {
  final s = _clamp01(savingsRate / 0.2);
  final u = _clamp01(1 - (utilisation - 0.1) / 0.4);
  final o = _clamp01(onTimeRate);
  final r = _clamp01(runwayMonths / 6);
  final score = (100 * (0.3 * s + 0.25 * u + 0.25 * o + 0.2 * r)).round();
  String pct(double v) => '${(v * 100).round()}%';
  final factors = [
    HealthFactor('Savings rate', s, '${pct(savingsRate)} of income saved'),
    HealthFactor('Card utilisation', u, '${pct(utilisation)} of limits used'),
    HealthFactor('Bills on time', o, '${pct(onTimeRate)} paid on time'),
    HealthFactor(
      'Emergency runway',
      r,
      '${runwayMonths.toStringAsFixed(1)} months of spending',
    ),
  ];
  final weakest = factors.reduce((a, b) => a.score <= b.score ? a : b);
  final String readiness;
  if (weakest.score >= 0.8) {
    readiness = 'All four signals are healthy. A good day to leave things be.';
  } else if (weakest.score >= 0.5) {
    readiness = switch (weakest.name) {
      'Savings rate' => 'Saving a little more would lift you most.',
      'Card utilisation' =>
        'Paying cards down before statements would lift you most.',
      'Bills on time' => 'Keep every bill on time this month.',
      _ => 'A bigger cash cushion would lift you most.',
    };
  } else {
    readiness = switch (weakest.name) {
      'Savings rate' => 'Saving is the one to watch: aim for 20% this month.',
      'Card utilisation' =>
        'Card balances are high. Paying down before statements helps most.',
      'Bills on time' => 'A bill slipped recently. Due dates are below.',
      _ => 'Runway is short. Even a small automatic transfer helps.',
    };
  }
  return HealthScore(score, factors, readiness);
}

/// Cashflow by month from transactions (income = credits not marked as
/// transfers; spend = debits that count towards budgets).
List<CashflowMonth> cashflowFromTransactions(
  List<Transaction> txs, {
  required DateTime now,
  int months = 6,
}) {
  const names = [
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
  return [
    for (var i = months - 1; i >= 0; i--)
      () {
        final m = DateTime(now.year, now.month - i);
        var income = 0.0, spend = 0.0;
        for (final t in txs) {
          if (t.date.year != m.year || t.date.month != m.month) continue;
          if (t.excluded || t.category.isTransfer) continue;
          if (t.isIncome) {
            income += t.amount;
          } else {
            spend += t.amount;
          }
        }
        return CashflowMonth(names[m.month - 1], income, spend);
      }(),
  ];
}

/// Projected month-end balance: today's cash, less typical daily spend for
/// the remaining days and known commitments, plus expected income.
double projectEndBalance({
  required double balanceNow,
  required double spentSoFar,
  required int dayOfMonth,
  required int daysInMonth,
  required double committed,
  double expectedIncome = 0,
}) {
  final daily = dayOfMonth <= 0 ? 0 : spentSoFar / dayOfMonth;
  final remainingDays = math.max(0, daysInMonth - dayOfMonth);
  return balanceNow - daily * remainingDays - committed + expectedIncome;
}

// ---- Family ------------------------------------------------------------------

/// What a household member shares with the others.
enum SharingLevel {
  nothing('Nothing', 'Only that they are in the household'),
  totals('Totals only', 'Monthly spend and budget, no detail'),
  categories('Categories', 'Spend by category, no merchants'),
  full('Everything', 'Transactions, merchants and accounts');

  const SharingLevel(this.label, this.description);
  final String label;
  final String description;
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.relation,
    required this.sharing,
    this.phone,
    this.isYou = false,
    this.invited = false,
    this.spent = 0,
    this.budget = 0,
    this.byCategory = const {},
  });
  final String id;
  final String name;
  final String relation;
  final SharingLevel sharing;
  final String? phone;
  final bool isYou;

  /// Invitation sent, not accepted yet.
  final bool invited;
  final double spent;
  final double budget;
  final Map<SpendCategory, double> byCategory;

  FamilyMember copyWith({SharingLevel? sharing}) => FamilyMember(
    id: id,
    name: name,
    relation: relation,
    sharing: sharing ?? this.sharing,
    phone: phone,
    isYou: isYou,
    invited: invited,
    spent: spent,
    budget: budget,
    byCategory: byCategory,
  );
}

class Household {
  const Household(this.name, this.members);
  final String name;
  final List<FamilyMember> members;
}
