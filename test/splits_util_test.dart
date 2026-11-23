import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/splits_util.dart';

void main() {
  const a = Member('a', 'A', Color(0xFF000000));
  const b = Member('b', 'B', Color(0xFF000000));
  const c = Member('c', 'C', Color(0xFF000000));
  final d = DateTime(2026);

  test('equal split balances sum to zero', () {
    final e = [
      SplitExpense(
        id: '1',
        title: 'x',
        paidBy: 'a',
        amount: 90,
        participants: const ['a', 'b', 'c'],
        date: d,
      ),
      SplitExpense(
        id: '2',
        title: 'y',
        paidBy: 'b',
        amount: 30,
        participants: const ['a', 'b'],
        date: d,
      ),
    ];
    final bal = computeBalances(e, const [a, b, c]);
    expect(bal['a'], 45.0); // +90 -30 -15
    expect(bal['b'], -15.0); // +30 -30 -15
    expect(bal['c'], -30.0);
    expect(bal.values.fold<double>(0, (x, y) => x + y).abs() < 0.01, isTrue);
  });

  test('simplifyDebts settles everyone', () {
    final plan = simplifyDebts({'a': 45, 'b': -15, 'c': -30});
    expect(plan.length, 2);
    expect(plan.fold<double>(0, (s, p) => s + p.amount), 45);
    expect(plan.every((p) => p.to == 'a'), isTrue);
  });
}
