import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/engine/rule_engine.dart';
import 'package:pulse/core/engine/types.dart';
import 'package:pulse/core/learning/global_merchant_map.dart';
import 'package:pulse/core/learning/merchant_memory.dart';
import 'package:pulse/data/learning_hooks.dart';
import 'package:pulse/data/models.dart';

Transaction _tx(String merchant, {bool income = false}) => Transaction(
  id: 't1',
  merchant: merchant,
  amount: 40,
  category: SpendCategory.other,
  date: DateTime(2026, 11, 1),
  source: TxSource.manual,
  cardId: 'c',
  accountLabel: 'Card',
  isIncome: income,
);

void main() {
  late MemoryKvStore kv;
  late MerchantMemory m;
  setUp(() {
    kv = MemoryKvStore();
    m = MerchantMemory(kv);
  });

  test('one plain confirmation is not enough, two agreeing ones are', () async {
    await m.confirm('Zed Corner Shop', 'groceries');
    expect(m.lookup('Zed Corner Shop'), isNull);
    await m.confirm('Zed Corner Shop', 'groceries');
    expect(m.lookup('Zed Corner Shop')?.category, 'groceries');
    expect(
      m.lookup('Zed Corner Shop')!.confidence,
      greaterThanOrEqualTo(memoryApplyAt),
    );
  });

  test('one deliberate fix is enough', () async {
    await m.confirm('Zed Corner Shop', 'groceries', weight: fixWeight);
    expect(m.lookup('Zed Corner Shop')?.category, 'groceries');
  });

  test('spelling variants share one memory (normalised key)', () async {
    await m.confirm('Zed Corner Shop', 'groceries', weight: fixWeight);
    expect(m.lookup('Zed Corner Shop'), isNotNull);
    expect(
      MerchantMemory.keyFor('ZED CORNER SHOP DUBAI AE 0123'),
      MerchantMemory.keyFor('Zed Corner Shop'),
    );
    expect(
      MerchantMemory.keyFor('POS PURCHASE ZED CORNER SHOP DXB 99887'),
      MerchantMemory.keyFor('zed  corner shop'),
    );
  });

  test(
    'contradicting yourself lowers confidence until you settle again',
    () async {
      for (var i = 0; i < 3; i++) {
        await m.confirm('Big Bazaar Mart', 'groceries');
      }
      expect(m.lookup('Big Bazaar Mart')?.category, 'groceries');
      await m.confirm('Big Bazaar Mart', 'shopping', weight: fixWeight);
      expect(
        m.lookup('Big Bazaar Mart'),
        isNull,
        reason: 'mixed signals: do not guess',
      );
      await m.confirm('Big Bazaar Mart', 'shopping');
      expect(m.lookup('Big Bazaar Mart')?.category, 'shopping');
    },
  );

  test(
    'a near-identical spelling matches, a different merchant does not',
    () async {
      await m.confirm(
        'Blue Orchid Supermarket',
        'groceries',
        weight: fixWeight,
      );
      final near = m.lookup('Blue Orchid Supermarkt');
      expect(near?.category, 'groceries');
      expect(near!.exact, isFalse);
      expect(m.lookup('Blue Orchard Bakery Cafe'), isNull);
      expect(m.lookup('Gold Orchid Pharmacy'), isNull);
    },
  );

  test('two close neighbours are ambiguous: no fuzzy guess', () async {
    await m.confirm('Blue Orchid Supermarkt', 'groceries', weight: fixWeight);
    await m.confirm('Blue Orchid Supermarkit', 'shopping', weight: fixWeight);
    expect(m.lookup('Blue Orchid Supermarket'), isNull);
  });

  test('persists, survives a restart, and forgets on request', () async {
    await m.confirm('Zed Corner Shop', 'groceries', weight: fixWeight);
    final again = MerchantMemory(kv);
    await again.load();
    expect(again.lookup('Zed Corner Shop')?.category, 'groceries');
    await again.forget('ZED CORNER SHOP DUBAI AE 123');
    expect(again.lookup('Zed Corner Shop'), isNull);
    final third = MerchantMemory(kv);
    await third.load();
    expect(third.length, 0);
  });

  test('snapshot and restore put things back (undo)', () async {
    await m.confirm('Zed Corner Shop', 'groceries', weight: fixWeight);
    final before = m.snapshot('Zed Corner Shop');
    await m.confirm('Zed Corner Shop', 'dining', weight: fixWeight);
    await m.restore('Zed Corner Shop', before);
    expect(m.lookup('Zed Corner Shop')?.category, 'groceries');
    await m.restore('Zed Corner Shop', null);
    expect(m.knows('Zed Corner Shop'), isFalse);
  });

  test('damaged storage starts empty instead of throwing', () async {
    kv.data['learning.merchant_memory'] = '{not json';
    await m.load();
    expect(m.length, 0);
    kv.data['learning.merchant_memory'] =
        '{"a":{"v":"x"},"b":{"v":{"dining":2},"t":"bad"}}';
    await m.load();
    expect(m.lookup('b')?.category, 'dining');
    expect(m.lookup('a'), isNull);
  });

  test('blank merchants and zero weight are ignored', () async {
    await m.confirm(null, 'groceries');
    await m.confirm('   ', 'groceries');
    await m.confirm('Zed Corner Shop', 'groceries', weight: 0);
    expect(m.length, 0);
  });

  test('hook skips Other and income, remembers real choices', () async {
    await rememberCategoryChoice(
      m,
      _tx('Zed Corner Shop'),
      SpendCategory.other,
      fix: true,
    );
    await rememberCategoryChoice(
      m,
      _tx('Employer LLC', income: true),
      SpendCategory.salary,
      fix: true,
    );
    expect(m.length, 0);
    await rememberCategoryChoice(
      m,
      _tx('Zed Corner Shop'),
      SpendCategory.groceries,
      fix: true,
    );
    expect(m.lookup('Zed Corner Shop')?.category, 'groceries');
  });

  group('resolver order: rule, memory, dictionary, global map', () {
    final cats = {
      'groceries': 'groceries',
      'dining': 'dining',
      'shopping': 'shopping',
    };

    test(
      'memory beats the dictionary and the shared map, and is tagged',
      () async {
        await m.confirm('Carrefour', 'dining', weight: fixWeight);
        final r = CategoryResolver(
          [],
          cats,
          memory: m,
          globalMap: GlobalMerchantMap.empty,
        );
        final e = r.enrich('CARREFOUR MOE DUBAI AE 0123', Direction.debit);
        expect(e.categoryId, 'dining');
        expect(e.source, 'memory');
        expect(e.tags, contains(learnedTag));
      },
    );

    test('an explicit rule beats memory', () async {
      await m.confirm('Carrefour', 'dining', weight: fixWeight);
      final rule = merchantEqualsRule('carrefour', 'shopping');
      final r = CategoryResolver([rule], cats, memory: m);
      final e = r.enrich('Carrefour', Direction.debit);
      expect(e.categoryId, 'shopping');
      expect(e.source, 'rule');
      expect(e.tags, isNot(contains(learnedTag)));
    });

    test('unsure memory falls through to the dictionary', () async {
      await m.confirm('Carrefour', 'dining');
      final r = CategoryResolver([], cats, memory: m);
      final e = r.enrich('Carrefour', Direction.debit);
      expect(e.categoryId, 'groceries');
      expect(e.source, 'dictionary');
    });

    test('a category that no longer exists is ignored', () async {
      await m.confirm('Zed Corner Shop', 'gone', weight: fixWeight);
      final r = CategoryResolver([], cats, memory: m);
      expect(r.enrich('Zed Corner Shop', Direction.debit).categoryId, isNull);
    });
  });
}
