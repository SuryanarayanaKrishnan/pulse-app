import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/budget_suggest.dart';

int aed(int v) => v * 100;

void main() {
  test('single renter on a mid salary: sane lines, fits, keeps the savings target', () {
    final s = suggestBudget(SuggestInput(incomeMinor: aed(15000)));
    expect(s.line('rent')!.amountMinor, aed(4500));
    expect(s.line('groceries')!.amountMinor, aed(600));
    expect(s.line('education'), isNull);
    expect(s.savingsMinor, aed(2250));
    expect(s.leftoverMinor, greaterThanOrEqualTo(0));
    expect(s.spendMinor + s.savingsMinor, lessThanOrEqualTo(aed(15000)));
  });

  test('family size raises groceries, utilities and adds school fees', () {
    final solo = suggestBudget(SuggestInput(incomeMinor: aed(30000)));
    final fam = suggestBudget(SuggestInput(incomeMinor: aed(30000), adults: 2, children: 2));
    expect(fam.line('groceries')!.amountMinor, greaterThan(solo.line('groceries')!.amountMinor));
    expect(fam.line('utilities')!.amountMinor, greaterThan(solo.line('utilities')!.amountMinor));
    expect(fam.line('education')!.amountMinor, greaterThan(0));
    expect(fam.savingsMinor, aed(3000)); // 10% with children
  });

  test('car and housing choices', () {
    final car = suggestBudget(SuggestInput(incomeMinor: aed(20000), hasCar: true));
    final noCar = suggestBudget(SuggestInput(incomeMinor: aed(20000)));
    expect(car.line('transport')!.amountMinor, greaterThan(noCar.line('transport')!.amountMinor));
    final free = suggestBudget(SuggestInput(incomeMinor: aed(20000), housing: Housing.free));
    expect(free.line('rent'), isNull);
    expect(free.line('home_loan'), isNull);
    final own = suggestBudget(SuggestInput(incomeMinor: aed(20000), housing: Housing.owned));
    expect(own.line('home_loan'), isNotNull);
    expect(own.line('rent'), isNull);
  });

  test('history wins over norms; known amounts win over history', () {
    final s = suggestBudget(SuggestInput(
      incomeMinor: aed(20000),
      history: {'groceries': aed(1000), 'rent': aed(5000), 'dining': aed(700)},
      known: {'rent': aed(5200)},
    ));
    expect(s.line('groceries')!.basis, SuggestBasis.history);
    expect(s.line('groceries')!.amountMinor, aed(1050)); // 5% room on flexible lines
    expect(s.line('rent')!.basis, SuggestBasis.known);
    expect(s.line('rent')!.amountMinor, aed(5200));
  });

  test('low income: trims discretionary norms to fit, never fixed or known lines', () {
    final s = suggestBudget(SuggestInput(
      incomeMinor: aed(5000),
      adults: 2,
      children: 2,
      known: {'rent': aed(2500)},
    ));
    expect(s.line('rent')!.amountMinor, aed(2500));
    expect(s.line('dining')!.basis, SuggestBasis.trimmed);
    expect(s.line('dining')!.amountMinor, lessThan(aed(300)));
  });

  test('no income gives no savings and still a list', () {
    final s = suggestBudget(const SuggestInput(incomeMinor: 0));
    expect(s.savingsMinor, 0);
    expect(s.lines, isNotEmpty);
  });

  test('typical month is the median of the recent months that had spend', () {
    final t = typicalMonthly({
      'groceries': {'2026-01-01': 100, '2026-02-01': 900, '2026-03-01': 300, '2026-04-01': 0},
      'dining': {'2026-02-01': 0},
    });
    expect(t['groceries'], 300);
    expect(t.containsKey('dining'), isFalse);
  });
}
