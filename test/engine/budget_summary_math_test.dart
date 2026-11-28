import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/budget_suggest.dart';

SuggestedLine _l(String id, int aed) =>
    SuggestedLine(id, aed * 100, SuggestBasis.known, fixed: false);

void main() {
  group('budget setup summary math', () {
    test('Planned = sum of lines, Left over = take-home - planned - saved', () {
      final b = SuggestedBudget(
        lines: [_l('rent', 4500), _l('groceries', 1500), _l('dining', 925)],
        savingsMinor: 225000,
        incomeMinor: 1500000,
      );
      expect(b.spendMinor, 692500);
      expect(b.savingsMinor, 225000);
      expect(b.leftoverMinor, 582500);
      expect(b.spendMinor + b.savingsMinor + b.leftoverMinor, b.incomeMinor);
      expect(b.isOverBudget, isFalse);
    });

    test('over-budget gives a negative leftover and the flag', () {
      final b = SuggestedBudget(
        lines: [_l('rent', 14000)],
        savingsMinor: 225000,
        incomeMinor: 1500000,
      );
      expect(b.leftoverMinor, -125000);
      expect(b.isOverBudget, isTrue);
    });

    test('exactly spent is not over budget', () {
      final b = SuggestedBudget(
        lines: [_l('rent', 12750)],
        savingsMinor: 225000,
        incomeMinor: 1500000,
      );
      expect(b.leftoverMinor, 0);
      expect(b.isOverBudget, isFalse);
    });

    test('suggestBudget(15,000) reconciles to take-home and never starts over budget', () {
      final b = suggestBudget(
        const SuggestInput(
          incomeMinor: 1500000,
          adults: 1,
          children: 0,
          housing: Housing.rent,
          hasCar: false,
          sendsMoneyHome: false,
        ),
      );
      expect(b.savingsMinor, 225000);
      expect(b.spendMinor + b.savingsMinor + b.leftoverMinor, 1500000);
      expect(b.isOverBudget, isFalse);
    });

    test('no income: nothing planned, nothing saved, no false over-budget', () {
      final b = suggestBudget(
        const SuggestInput(
          incomeMinor: 0,
          adults: 1,
          children: 0,
          housing: Housing.rent,
          hasCar: false,
          sendsMoneyHome: false,
        ),
      );
      expect(b.savingsMinor, 0);
      expect(b.leftoverMinor, -b.spendMinor);
    });

    test('very large incomes stay exact in integer minor units', () {
      final b = suggestBudget(
        const SuggestInput(
          incomeMinor: 100000000,
          adults: 2,
          children: 2,
          housing: Housing.owned,
          hasCar: true,
          sendsMoneyHome: true,
        ),
      );
      expect(b.spendMinor + b.savingsMinor + b.leftoverMinor, 100000000);
    });
  });
}
