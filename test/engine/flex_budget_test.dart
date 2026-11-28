import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/budget_moves.dart';
import 'package:pulse/core/engine/flex_budget.dart';

PlanLine line(
  String id,
  BudgetGroup g,
  int planned,
  int spent, {
  int carry = 0,
}) => PlanLine(
  id: id,
  group: g,
  plannedMinor: planned,
  spentMinor: spent,
  rolloverInMinor: carry,
);

void main() {
  group('groups', () {
    test('a stored group wins, otherwise fixed categories are Fixed and the rest Flexible', () {
      expect(BudgetGroup.resolve(null, isFixed: true), BudgetGroup.fixed);
      expect(BudgetGroup.resolve(null, isFixed: false), BudgetGroup.flexible);
      expect(
        BudgetGroup.resolve('nonmonthly', isFixed: true),
        BudgetGroup.nonMonthly,
      );
      expect(BudgetGroup.resolve('junk', isFixed: false), BudgetGroup.flexible);
    });
  });

  group('flex pooling', () {
    test('one overspent category is absorbed by an underspent one', () {
      final s = flexPool([
        line('dining', BudgetGroup.flexible, 100000, 125000),
        line('groceries', BudgetGroup.flexible, 200000, 150000),
        line('rent', BudgetGroup.fixed, 900000, 900000),
      ]);
      expect(s.availableMinor, 300000);
      expect(s.spentMinor, 275000);
      expect(s.remainingMinor, 25000);
      expect(s.overspentMinor, 25000);
      expect(s.categories, 2);
    });

    test('carry-in joins the pool and an overspent pool goes negative', () {
      final s = flexPool([
        line('a', BudgetGroup.flexible, 10000, 30000, carry: 5000),
        line('b', BudgetGroup.flexible, 10000, 0),
      ]);
      expect(s.availableMinor, 25000);
      expect(s.remainingMinor, -5000);
      expect(s.progress, greaterThan(1));
    });

    test('empty pool is zero, not NaN', () {
      final s = flexPool(const []);
      expect(s.remainingMinor, 0);
      expect(s.progress, 0);
    });

    test('Fixed and Non-monthly never enter the pool', () {
      final s = flexPool([
        line('rent', BudgetGroup.fixed, 100, 100),
        line('fee', BudgetGroup.nonMonthly, 100, 0),
      ]);
      expect(s.availableMinor, 0);
    });
  });

  group('fixed bills', () {
    test('status follows the set amount', () {
      expect(const FixedBill('a', 5000, 0).status, BillStatus.upcoming);
      expect(const FixedBill('a', 5000, 2000).status, BillStatus.partial);
      expect(const FixedBill('a', 5000, 5000).status, BillStatus.paid);
      expect(const FixedBill('a', 5000, 5100).status, BillStatus.over);
      expect(const FixedBill('a', 0, 100).status, BillStatus.over);
    });

    test('summary adds due and paid exactly', () {
      final s = fixedBills([
        line('rent', BudgetGroup.fixed, 900000, 900000),
        line('wifi', BudgetGroup.fixed, 35000, 0),
        line('car', BudgetGroup.fixed, 120000, 150000),
        line('dining', BudgetGroup.flexible, 1, 1),
      ]);
      expect(s.bills.length, 3);
      expect(s.plannedMinor, 1055000);
      expect(s.dueMinor, 35000);
      expect(s.paidCount, 1);
    });
  });

  group('spreading and sinking funds', () {
    test('spread adds up exactly and the extra minor units go first', () {
      expect(spreadMinor(1000, 3), [334, 333, 333]);
      expect(spreadMinor(1, 12).fold(0, (a, b) => a + b), 1);
      expect(spreadMinor(0, 4), [0, 0, 0, 0]);
      for (final total in [1, 7, 99999, 123457, 3600000]) {
        for (final m in [1, 2, 3, 6, 12]) {
          final p = spreadMinor(total, m);
          expect(p.fold(0, (a, b) => a + b), total, reason: '$total/$m');
          expect(
            p.reduce((a, b) => a > b ? a : b) -
                p.reduce((a, b) => a < b ? a : b),
            lessThanOrEqualTo(1),
          );
        }
      }
      expect(() => spreadMinor(10, 0), throwsArgumentError);
    });

    test('a 12 month annual fee collects its full cost over one cycle', () {
      var sum = 0;
      for (var i = 0; i < 12; i++) {
        sum += sinkingContribution(
          costMinor: 36500,
          cycleMonths: 12,
          anchor: '2026-01-01',
          month: monthKeyOf(monthIndex('2026-01-01') + i),
        );
      }
      expect(sum, 36500);
    });

    test(
      'the cycle repeats and months before the anchor still map into it',
      () {
        int c(String m) => sinkingContribution(
          costMinor: 1000,
          cycleMonths: 3,
          anchor: '2026-03-01',
          month: m,
        );
        expect(c('2026-03-01'), 334);
        expect(c('2026-06-01'), 334);
        expect(c('2026-02-01'), 333);
        expect(c('2026-01-01'), 333);
      },
    );

    test('month keys round trip across a year end', () {
      expect(monthKeyOf(monthIndex('2026-12-01') + 1), '2027-01-01');
      expect(monthKeyFor(DateTime(2026, 2, 17)), '2026-02-01');
    });
  });

  group('rollover math', () {
    test('closing = opening + planned - spent, carried forward', () {
      final r = rolloverChain(const [
        MonthPlan('2026-01-01', 10000, 4000),
        MonthPlan('2026-02-01', 10000, 12000),
        MonthPlan('2026-03-01', 10000, 0),
      ]);
      expect(r.map((e) => e.openingMinor), [0, 6000, 4000]);
      expect(r.map((e) => e.closingMinor), [6000, 4000, 14000]);
      expect(r[1].availableMinor, 16000);
    });

    test('overspending carries as a negative balance', () {
      final r = rolloverChain(const [
        MonthPlan('2026-01-01', 5000, 9000),
        MonthPlan('2026-02-01', 5000, 0),
      ]);
      expect(r[0].closingMinor, -4000);
      expect(r[1].closingMinor, 1000);
    });

    test('opening balance seeds the chain and gaps are refused', () {
      final r = rolloverChain(const [
        MonthPlan('2026-01-01', 100, 0),
      ], openingMinor: 250);
      expect(r.single.closingMinor, 350);
      expect(
        () => rolloverChain(const [
          MonthPlan('2026-01-01', 1, 0),
          MonthPlan('2026-03-01', 1, 0),
        ]),
        throwsArgumentError,
      );
    });

    test(
      'total in minus total out equals the final balance (no minor unit lost)',
      () {
        final plans = [
          for (var i = 0; i < 24; i++)
            MonthPlan(
              monthKeyOf(monthIndex('2025-01-01') + i),
              33333 + i,
              12345 * (i % 5),
            ),
        ];
        final r = rolloverChain(plans, openingMinor: 7);
        final planned = plans.fold(0, (a, p) => a + p.plannedMinor);
        final spent = plans.fold(0, (a, p) => a + p.spentMinor);
        expect(r.last.closingMinor, 7 + planned - spent);
      },
    );

    test('sinking fund: funded over the cycle, the bill lands, the fund resets near zero', () {
      final costs = spreadMinor(120000, 12);
      final plans = [
        for (var i = 0; i < 12; i++)
          MonthPlan(
            monthKeyOf(monthIndex('2026-01-01') + i),
            costs[i],
            i == 11 ? 120000 : 0,
          ),
      ];
      final r = rolloverChain(plans);
      expect(r[10].closingMinor, 110000);
      expect(r.last.closingMinor, 0);
    });

    test('badge shows only a real carry', () {
      expect(rolloverBadge(line('a', BudgetGroup.flexible, 1, 1)), isNull);
      expect(
        rolloverBadge(line('a', BudgetGroup.flexible, 1, 1, carry: -300)),
        -300,
      );
    });

    test('sinking fund and summary maths', () {
      const f = SinkingFund(
        id: 'ins',
        balanceMinor: 20000,
        contributionMinor: 10000,
        spentMinor: 5000,
        costMinor: 120000,
        cycleMonths: 12,
      );
      expect(f.availableMinor, 30000);
      expect(f.closingMinor, 25000);
      expect(const NonMonthlySummary([f, f]).balanceMinor, 50000);
    });
  });

  group('move money', () {
    BudgetMove mv(
      String id,
      String from,
      String to,
      int a, {
      String month = '2026-05-01',
      MoveScope scope = MoveScope.mine,
      bool undone = false,
    }) => BudgetMove(
      id: id,
      month: month,
      fromId: from,
      toId: to,
      amountMinor: a,
      scope: scope,
      undone: undone,
    );

    test('conservation: total planned never changes, however many moves', () {
      final planned = {'a': 100000, 'b': 50000, 'c': 0};
      final moves = [
        mv('1', 'a', 'b', 12345),
        mv('2', 'b', 'c', 3333),
        mv('3', 'c', 'a', 1),
        mv('4', 'a', 'c', 99),
      ];
      final after = applyMoves(
        planned,
        moves,
        month: '2026-05-01',
        scope: MoveScope.mine,
      );
      expect(after.values.fold(0, (a, b) => a + b), 150000);
      expect(after['a'], 100000 - 12345 + 1 - 99);
      expect(after['c'], 3333 - 1 + 99);
      expect(
        moveDeltas(
          moves,
          month: '2026-05-01',
          scope: MoveScope.mine,
        ).values.fold(0, (a, b) => a + b),
        0,
      );
    });

    test('a move is scoped to its month and to Mine or Joint', () {
      final planned = {'a': 1000, 'b': 0};
      final moves = [
        mv('1', 'a', 'b', 400),
        mv('2', 'a', 'b', 100, month: '2026-06-01'),
        mv('3', 'a', 'b', 50, scope: MoveScope.joint),
      ];
      expect(
        applyMoves(planned, moves, month: '2026-05-01', scope: MoveScope.mine),
        {'a': 600, 'b': 400},
      );
      expect(
        applyMoves(planned, moves, month: '2026-06-01', scope: MoveScope.mine),
        {'a': 900, 'b': 100},
      );
      expect(
        applyMoves(planned, moves, month: '2026-05-01', scope: MoveScope.joint),
        {'a': 950, 'b': 50},
      );
      expect(
        applyMoves(planned, moves, month: '2026-07-01', scope: MoveScope.mine),
        planned,
      );
    });

    test('undo restores the original exactly', () {
      final planned = {'a': 777, 'b': 1};
      final one = mv('1', 'a', 'b', 77);
      final done = applyMoves(
        planned,
        [one],
        month: '2026-05-01',
        scope: MoveScope.mine,
      );
      expect(done, {'a': 700, 'b': 78});
      final undone = applyMoves(
        planned,
        [mv('1', 'a', 'b', 77, undone: true)],
        month: '2026-05-01',
        scope: MoveScope.mine,
      );
      expect(undone, planned);
    });

    test('a move into a category that has no plan yet creates its plan', () {
      expect(
        applyMoves(
          {'a': 500},
          [mv('1', 'a', 'z', 200)],
          month: '2026-05-01',
          scope: MoveScope.mine,
        ),
        {'a': 300, 'z': 200},
      );
    });

    test('checks', () {
      expect(
        checkMove(
          fromId: 'a',
          toId: 'a',
          amountMinor: 1,
          sourcePlannedMinor: 10,
        ),
        MoveProblem.sameCategory,
      );
      expect(
        checkMove(
          fromId: 'a',
          toId: 'b',
          amountMinor: 0,
          sourcePlannedMinor: 10,
        ),
        MoveProblem.notPositive,
      );
      expect(
        checkMove(
          fromId: 'a',
          toId: 'b',
          amountMinor: 11,
          sourcePlannedMinor: 10,
        ),
        MoveProblem.exceedsSource,
      );
      expect(
        checkMove(
          fromId: 'a',
          toId: 'b',
          amountMinor: 10,
          sourcePlannedMinor: 10,
        ),
        isNull,
      );
    });

    test('spare money lists the roomiest category first and skips the overspent one', () {
      final s = spareMoney(
        {'a': 1000, 'b': 5000, 'c': 100},
        {'a': 200, 'b': 1000, 'c': 900},
        except: 'a',
      );
      expect(s, [('b', 4000)]);
    });
  });
}
