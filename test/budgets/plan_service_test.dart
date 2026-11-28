import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/budget_moves.dart';
import 'package:pulse/core/engine/flex_budget.dart';
import 'package:pulse/data/budget_plan_service.dart';
import 'package:pulse/data/local/budget_plan_store.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/models.dart';

import '../backup/support.dart' show memoryDb;

Transaction tx(
  String id,
  SpendCategory cat,
  double amount,
  DateTime date, {
  bool income = false,
  bool excluded = false,
}) => Transaction(
  id: id,
  merchant: 'M$id',
  amount: amount,
  category: cat,
  date: date,
  source: TxSource.manual,
  cardId: '',
  accountLabel: 'Main',
  isIncome: income,
  excluded: excluded,
);

void main() {
  final nov = DateTime(2026, 11, 10);
  late List<Transaction> txs;

  BudgetPlanService svc(BudgetPlanStore store, {List<String>? log}) =>
      BudgetPlanService(
        store: store,
        transactions: () async => txs,
        onModeChanged: (m) => log?.add('mode:${m.key}'),
        onMoved: () => log?.add('moved'),
        clock: () => nov,
      );

  MemoryBudgetPlanStore store() => MemoryBudgetPlanStore(
    limits: const [
      LimitRow('rent', '2026-09-01', 600000),
      LimitRow('groceries', '2026-09-01', 100000),
      LimitRow('dining', '2026-09-01', 50000),
      LimitRow('travel', '2026-09-01', 25000),
    ],
  );

  setUp(() => txs = []);

  test(
    'groups default from the category and carry the three summaries',
    () async {
      txs = [
        tx('1', SpendCategory.rent, 6000, DateTime(2026, 11, 1)),
        tx('2', SpendCategory.groceries, 700.50, DateTime(2026, 11, 3)),
        tx('3', SpendCategory.dining, 620, DateTime(2026, 11, 4)),
        tx(
          '4',
          SpendCategory.salary,
          20000,
          DateTime(2026, 11, 1),
          income: true,
        ),
        tx(
          '5',
          SpendCategory.dining,
          99,
          DateTime(2026, 11, 5),
          excluded: true,
        ),
      ];
      final v = await svc(store()).view(nov);
      expect(v.row('rent')!.group, BudgetGroup.fixed);
      expect(v.row('groceries')!.group, BudgetGroup.flexible);
      expect(v.fixed.paidCount, 1);
      // Flexible pool: groceries 1000 + dining 500 + travel 250 (flexible by default), 700.50 + 620 spent.
      expect(v.flex.availableMinor, 175000);
      expect(v.flex.spentMinor, 132050);
      expect(v.flex.remainingMinor, 42950);
      expect(v.row('salary'), isNull);
    },
  );

  test(
    'rollover carries unspent and overspent amounts month to month',
    () async {
      final s = store();
      await s.saveCategoryPlan(
        (await s.categories())
            .firstWhere((c) => c.id == 'groceries')
            .copyWith(rollover: true, rolloverStart: '2026-09-01'),
      );
      txs = [
        tx(
          '1',
          SpendCategory.groceries,
          400,
          DateTime(2026, 9, 12),
        ), // +600 left
        tx(
          '2',
          SpendCategory.groceries,
          1500,
          DateTime(2026, 10, 12),
        ), // -500 overspent
        tx('3', SpendCategory.groceries, 250.25, DateTime(2026, 11, 2)),
      ];
      final v = await svc(s).view(nov);
      final g = v.row('groceries')!;
      // Sep: 1000-400 = 600; Oct: 600 + 1000 - 1500 = 100 carried into Nov.
      expect(g.carryMinor, 10000);
      expect(g.remainingMinor, 10000 + 100000 - 25025);
      // Without rollover the carry is not shown.
      expect(v.row('dining')!.carryMinor, isNull);
    },
  );

  test('a rollover chain loses no minor unit', () async {
    final s = store();
    await s.saveCategoryPlan(
      (await s.categories())
          .firstWhere((c) => c.id == 'dining')
          .copyWith(
            rollover: true,
            rolloverStart: '2026-09-01',
            rolloverStartMinor: 77,
          ),
    );
    txs = [
      tx('1', SpendCategory.dining, 123.45, DateTime(2026, 9, 3)),
      tx('2', SpendCategory.dining, 0.07, DateTime(2026, 10, 3)),
    ];
    final r = (await svc(s).view(nov)).row('dining')!;
    expect(r.carryMinor, 77 + 50000 - 12345 + 50000 - 7);
  });

  test('a yearly cost becomes a sinking fund that spreads exactly and rolls forward', () async {
    final s = store();
    await s.saveCategoryPlan(
      (await s.categories())
          .firstWhere((c) => c.id == 'travel')
          .copyWith(
            group: BudgetGroup.nonMonthly,
            cycleCostMinor: 100000,
            cycleMonths: 12,
            rolloverStart: '2026-09-01',
          ),
    );
    final v = await svc(s).view(nov);
    final f = v.row('travel')!.fund!;
    // 100000 / 12 = 8333 r 4: the first four months carry 8334 (Sep, Oct, Nov, Dec).
    expect(f.contributionMinor, 8334);
    expect(f.balanceMinor, 8334 * 2);
    expect(f.closingMinor, 8334 * 3);
    expect(v.nonMonthly.balanceMinor, 8334 * 3);
    expect(v.row('travel')!.config.rolls, isTrue);
    // The bill lands: the fund drops, and can go negative.
    txs = [tx('1', SpendCategory.travel, 1000, DateTime(2026, 11, 20))];
    final after = (await svc(s).view(nov)).row('travel')!.fund!;
    expect(after.closingMinor, 8334 * 3 - 100000);
  });

  test('moving money keeps the total, is limited to its month, and undo restores it', () async {
    final s = store();
    final log = <String>[];
    final svc0 = svc(s, log: log);
    final before = await svc0.view(nov);
    final (m, problem) = await svc0.move(
      month: nov,
      fromId: 'groceries',
      toId: 'dining',
      amountMinor: 30000,
    );
    expect(problem, isNull);
    expect(log, ['moved']);
    final after = await svc0.view(nov);
    expect(after.row('groceries')!.plannedMinor, 70000);
    expect(after.row('dining')!.plannedMinor, 80000);
    expect(after.row('dining')!.movedMinor, 30000);
    expect(after.plannedMinor, before.plannedMinor);
    expect(after.flex.availableMinor, before.flex.availableMinor);
    expect(after.moves.single.id, m!.id);
    // October is untouched.
    final oct = await svc0.view(DateTime(2026, 10, 1));
    expect(oct.row('groceries')!.plannedMinor, 100000);
    await svc0.undoMove(m.id);
    final undone = await svc0.view(nov);
    expect(undone.row('groceries')!.plannedMinor, 100000);
    expect(undone.moves, isEmpty);
  });

  test('a move that would take more than the source has, or between one category, is refused and recorded nowhere', () async {
    final s = store();
    final log = <String>[];
    final x = svc(s, log: log);
    expect(
      (await x.move(
        month: nov,
        fromId: 'dining',
        toId: 'groceries',
        amountMinor: 50001,
      )).$2,
      MoveProblem.exceedsSource,
    );
    expect(
      (await x.move(
        month: nov,
        fromId: 'dining',
        toId: 'dining',
        amountMinor: 1,
      )).$2,
      MoveProblem.sameCategory,
    );
    expect(
      (await x.move(
        month: nov,
        fromId: 'dining',
        toId: 'groceries',
        amountMinor: 0,
      )).$2,
      MoveProblem.notPositive,
    );
    expect(await s.moves(), isEmpty);
    expect(log, isEmpty);
  });

  test('Mine and Joint moves never mix', () async {
    final s = store();
    final x = svc(s);
    await x.move(
      month: nov,
      fromId: 'a',
      toId: 'b',
      amountMinor: 500,
      scope: MoveScope.joint,
      sourcePlannedMinor: 1000,
    );
    expect((await x.view(nov)).moves, isEmpty);
    expect(
      moveDeltas(
        await x.allMoves(),
        month: '2026-11-01',
        scope: MoveScope.joint,
      ),
      {'a': -500, 'b': 500},
    );
    expect(
      moveDeltas(
        await x.allMoves(),
        month: '2026-11-01',
        scope: MoveScope.mine,
      ),
      isEmpty,
    );
  });

  test(
    'a move into a rolling category flows into its next-month carry',
    () async {
      final s = store();
      await s.saveCategoryPlan(
        (await s.categories())
            .firstWhere((c) => c.id == 'dining')
            .copyWith(rollover: true, rolloverStart: '2026-10-01'),
      );
      final x = svc(s);
      await x.move(
        month: DateTime(2026, 10, 1),
        fromId: 'groceries',
        toId: 'dining',
        amountMinor: 20000,
      );
      final d = (await x.view(nov)).row('dining')!;
      // Oct plan 500 + 200 moved, nothing spent -> 700 carried into Nov.
      expect(d.carryMinor, 70000);
    },
  );

  test(
    'changing the mode is reported once per change, not on a repeat',
    () async {
      final log = <String>[];
      final x = svc(store(), log: log);
      await x.setMode(BudgetMode.category);
      await x.setMode(BudgetMode.category);
      await x.setMode(BudgetMode.flex);
      expect(log, ['mode:category', 'mode:flex']);
    },
  );

  test('income, transfers and excluded payments never count as spending', () {
    final by = BudgetPlanService.spendByMonth([
      tx('1', SpendCategory.dining, 10, nov),
      tx('2', SpendCategory.dining, 99, nov, excluded: true),
      tx('3', SpendCategory.salary, 500, nov, income: true),
    ]);
    expect(by, {
      'dining': {'2026-11-01': 1000},
    });
  });

  group('the drift store behaves like the memory one', () {
    late PulseDatabase db;
    setUp(() => db = memoryDb());
    tearDown(() => db.close());

    test(
      'mode, category plan, limits and moves round trip; undo hides a move',
      () async {
        final s = LocalBudgetPlanStore(db);
        expect(await s.mode(), BudgetMode.flex);
        await s.setMode(BudgetMode.category);
        expect(await s.mode(), BudgetMode.category);

        final dining = (await s.categories()).firstWhere(
          (c) => c.id == 'dining',
        );
        expect(dining.group, BudgetGroup.flexible);
        expect(
          (await s.categories()).firstWhere((c) => c.id == 'rent').group,
          BudgetGroup.fixed,
        );
        await s.saveCategoryPlan(
          dining.copyWith(
            group: BudgetGroup.nonMonthly,
            cycleCostMinor: 90000,
            cycleMonths: 6,
            rollover: true,
          ),
        );
        final saved = (await s.categories()).firstWhere(
          (c) => c.id == 'dining',
        );
        expect(saved.group, BudgetGroup.nonMonthly);
        expect(
          (saved.cycleCostMinor, saved.cycleMonths, saved.rollover),
          (90000, 6, true),
        );

        await s.saveLimit('dining', '2026-11-01', 5000);
        await s.saveLimit('dining', '2026-11-01', 7000);
        expect(
          (await s.limits())
              .where((l) => l.categoryId == 'dining')
              .map((l) => l.limitMinor),
          [7000],
        );

        await s.addMove(
          const BudgetMove(
            id: 'm1',
            month: '2026-11-01',
            fromId: 'a',
            toId: 'b',
            amountMinor: 5,
            scope: MoveScope.joint,
          ),
        );
        final m = (await s.moves()).single;
        expect((m.scope, m.amountMinor), (MoveScope.joint, 5));
        await s.undoMove('m1');
        expect(await s.moves(), isEmpty);
        // Soft delete: the row stays, so the undo can sync.
        expect(
          (await db.select(db.budgetMoves).get()).single.deletedAt,
          isNotNull,
        );
      },
    );

    test('the service works against the real database end to end', () async {
      await db
          .into(db.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: 'b1',
              categoryId: 'groceries',
              month: '2026-11-01',
              limitMinor: 100000,
            ),
          );
      await db
          .into(db.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: 'b2',
              categoryId: 'dining',
              month: '2026-11-01',
              limitMinor: 40000,
              rollover: const Value(false),
            ),
          );
      final x = BudgetPlanService(
        store: LocalBudgetPlanStore(db),
        transactions: () async => [],
        clock: () => nov,
      );
      final (m, p) = await x.move(
        month: nov,
        fromId: 'groceries',
        toId: 'dining',
        amountMinor: 1,
      );
      expect(p, isNull);
      final v = await x.view(nov);
      expect(v.row('dining')!.plannedMinor, 40001);
      expect(v.row('groceries')!.plannedMinor, 99999);
      await x.undoMove(m!.id);
      expect((await x.view(nov)).row('dining')!.plannedMinor, 40000);
    });
  });
}
