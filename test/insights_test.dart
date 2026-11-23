import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/insights.dart';
import 'package:pulse/data/models.dart';

void main() {
  test('safe to spend takes the lower of budget and cash limits', () {
    final byBudget = computeSafeToSpend(
      cash: 50000,
      budgetLeft: 3000,
      bills: 500,
      cardDues: 4000,
      goals: 500,
      daysLeft: 10,
    );
    expect(byBudget.available, 2000);
    expect(byBudget.today, 200);

    final byCash = computeSafeToSpend(
      cash: 5000,
      budgetLeft: 9000,
      bills: 500,
      cardDues: 4000,
      goals: 0,
      daysLeft: 5,
    );
    expect(byCash.available, 500);
    expect(byCash.today, 100);
  });

  test('safe to spend never goes negative and divides by at least a day', () {
    final s = computeSafeToSpend(
      cash: 100,
      budgetLeft: -50,
      bills: 0,
      cardDues: 0,
      goals: 0,
      daysLeft: 0,
    );
    expect(s.available, 0);
    expect(s.daysLeft, 1);
  });

  test('health score weights its four factors', () {
    final perfect = computeHealthScore(
      savingsRate: 0.25,
      utilisation: 0.05,
      onTimeRate: 1,
      runwayMonths: 8,
    );
    expect(perfect.score, 100);
    expect(perfect.band, 'Strong');

    final weak = computeHealthScore(
      savingsRate: 0.2,
      utilisation: 0.5,
      onTimeRate: 1,
      runwayMonths: 6,
    );
    expect(weak.score, 75);
    expect(weak.readiness, contains('Card balances'));
  });

  test('cashflow by month skips transfers and excluded spend', () {
    Transaction tx(double a, DateTime d, {bool income = false, SpendCategory? cat, bool excluded = false}) =>
        Transaction(
          id: '$a$d',
          merchant: 'm',
          amount: a,
          category: cat ?? (income ? SpendCategory.salary : SpendCategory.groceries),
          date: d,
          source: TxSource.sms,
          cardId: 'c',
          accountLabel: 'x',
          isIncome: income,
          excluded: excluded,
        );
    final months = cashflowFromTransactions([
      tx(20000, DateTime(2026, 11, 1), income: true),
      tx(300, DateTime(2026, 11, 3)),
      tx(5000, DateTime(2026, 11, 4), cat: SpendCategory.savings),
      tx(900, DateTime(2026, 11, 5), excluded: true),
      tx(400, DateTime(2026, 10, 12)),
    ], now: DateTime(2026, 11, 23), months: 2);
    expect(months.map((m) => m.label), ['Oct', 'Nov']);
    expect(months[0].spend, 400);
    expect(months[1].income, 20000);
    expect(months[1].saved, 20000 - 300 - (SpendCategory.savings.isTransfer ? 0 : 5000));
  });

  test('projected balance extends the daily pace to month end', () {
    final p = projectEndBalance(
      balanceNow: 10000,
      spentSoFar: 3000,
      dayOfMonth: 10,
      daysInMonth: 30,
      committed: 1000,
    );
    expect(p, 10000 - 300 * 20 - 1000);
  });
}
