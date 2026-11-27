import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/budget_overrun.dart';
import 'package:pulse/data/budget_plan_service.dart';
import 'package:pulse/data/local/budget_plan_store.dart';
import 'package:pulse/data/models.dart';

Transaction tx(
  String id,
  SpendCategory cat,
  double amount,
  DateTime date, {
  String? merchant,
  bool excluded = false,
}) => Transaction(
  id: id,
  merchant: merchant ?? 'M$id',
  amount: amount,
  category: cat,
  date: date,
  source: TxSource.manual,
  cardId: '',
  accountLabel: 'Main',
  excluded: excluded,
);

void main() {
  final nov = DateTime(2026, 11, 20);
  late List<Transaction> txs;

  BudgetPlanService svc() => BudgetPlanService(
    store: MemoryBudgetPlanStore(
      limits: const [
        LimitRow('dining', '2026-05-01', 50000),
        LimitRow('groceries', '2026-05-01', 150000),
        LimitRow('shopping', '2026-05-01', 40000),
      ],
    ),
    transactions: () async => txs,
    clock: () => nov,
  );

  setUp(() => txs = []);

  test('three months over in dining is a recurring overrun, funded from groceries slack', () async {
    txs = [
      tx('a', SpendCategory.dining, 700, DateTime(2026, 9, 5)),
      tx('b', SpendCategory.dining, 640, DateTime(2026, 10, 9)),
      tx('c', SpendCategory.dining, 380, DateTime(2026, 8, 9)),
      tx('d', SpendCategory.dining, 380, DateTime(2026, 7, 9)),
      tx(
        'e',
        SpendCategory.dining,
        300,
        DateTime(2026, 11, 2),
        merchant: 'Cafe A',
      ),
      tx(
        'f',
        SpendCategory.dining,
        330,
        DateTime(2026, 11, 8),
        merchant: 'Cafe B',
      ),
      tx('g', SpendCategory.groceries, 900, DateTime(2026, 11, 4)),
      tx('h', SpendCategory.dining, 55, DateTime(2026, 11, 9), excluded: true),
    ];
    final r = await svc().overruns();
    expect(r.items, hasLength(1));
    final i = r.items.single;
    expect(i.category.id, 'dining');
    expect(i.overrun.kind, OverrunKind.pattern);
    expect(i.overrun.monthsOver, 3);
    expect(
      i.overrun.spentMinor,
      63000,
      reason: 'the excluded payment is not counted',
    );
    expect(i.overrun.suggestedCeilingMinor, greaterThan(50000));
    expect(i.funding, isNotNull);
    expect(i.funding!.sources.first.categoryId, 'groceries');
    expect(i.funding!.sources.first.unusedMinor, 60000);
    expect(r.labelOf('groceries'), 'Groceries');
  });

  test(
    'marked months are left out and a marked current month disappears',
    () async {
      txs = [
        tx('a', SpendCategory.dining, 700, DateTime(2026, 9, 5)),
        tx('b', SpendCategory.dining, 640, DateTime(2026, 10, 9)),
        tx('c', SpendCategory.dining, 380, DateTime(2026, 8, 9)),
        tx('d', SpendCategory.dining, 630, DateTime(2026, 11, 2)),
      ];
      expect(
        (await svc().overruns()).items.single.overrun.kind,
        OverrunKind.pattern,
      );
      final marked = await svc().overruns(
        marked: {
          'dining': {'2026-09-01'},
        },
      );
      expect(marked.items.single.overrun.kind, isNot(OverrunKind.pattern));
      expect(
        (await svc().overruns(
          marked: {
            'dining': {'2026-11-01'},
          },
        )).items,
        isEmpty,
      );
    },
  );

  test('a fresh install is honest: too early', () async {
    txs = [tx('a', SpendCategory.dining, 800, DateTime(2026, 11, 2))];
    final r = await svc().overruns();
    expect(r.items.single.overrun.kind, OverrunKind.tooEarly);
    expect(r.items.single.funding, isNull);
  });

  test('nothing over, nothing reported; no payments at all is fine', () async {
    expect((await svc().overruns()).items, isEmpty);
    txs = [tx('a', SpendCategory.dining, 100, DateTime(2026, 11, 2))];
    expect((await svc().overruns()).items, isEmpty);
  });

  test('income and transfers never count', () async {
    txs = [
      Transaction(
        id: 'i',
        merchant: 'Employer',
        amount: 99999,
        category: SpendCategory.salary,
        date: DateTime(2026, 11, 1),
        source: TxSource.manual,
        cardId: '',
        accountLabel: 'Main',
        isIncome: true,
      ),
    ];
    expect((await svc().overruns()).items, isEmpty);
  });
}
