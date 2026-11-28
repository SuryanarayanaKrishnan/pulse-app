import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/recategorise.dart';
import 'package:pulse/core/engine/rule_engine.dart';
import 'package:pulse/core/engine/types.dart';

const _dining = 'cat-dining';
const _shopping = 'cat-shopping';

RecatRow _row(String id, String raw, {String? cat = _dining, String? norm}) =>
    RecatRow(
      id: id,
      categoryId: cat,
      merchantRaw: raw,
      merchantNormalized: norm,
      direction: Direction.debit,
    );

void main() {
  group('recategoriseKey', () {
    test('prefers the stored normalised name and ignores case and spacing', () {
      expect(recategoriseKey(normalized: ' Carrefour  '), 'carrefour');
    });
    test('normalises the raw descriptor when nothing is stored', () {
      expect(
        recategoriseKey(raw: 'CARREFOUR MOE DUBAI AE 0123'),
        recategoriseKey(raw: 'Carrefour'),
      );
    });
    test('no merchant means no key', () {
      expect(recategoriseKey(raw: '  '), isNull);
      expect(recategoriseKey(), isNull);
    });
  });

  group('planRecategorise', () {
    final rows = [
      _row('edited', 'CARREFOUR MOE DUBAI AE 0123'),
      _row('a', 'CARREFOUR MOE DUBAI AE 0123'),
      _row('b', 'Carrefour', norm: 'Carrefour'),
      _row('c', 'POS PURCHASE CARREFOUR CITY CENTRE DUBAI'),
      _row('same', 'Carrefour', cat: _shopping),
      _row('other', 'Starbucks'),
      _row('blank', ''),
    ];

    test('matches spelling variants, skips edited, unchanged and others', () {
      final plan = planRecategorise(
        key: recategoriseKey(raw: 'Carrefour'),
        targetCategoryId: _shopping,
        rows: rows,
        excludeId: 'edited',
      );
      expect(plan.pastIds, unorderedEquals(['a', 'b', 'c']));
      expect(plan.pastCount, 3);
      expect(plan.key, 'carrefour');
    });

    test('the rule it builds categorises variants and nothing else', () {
      final plan = planRecategorise(
        key: 'carrefour',
        targetCategoryId: _shopping,
        rows: rows,
      );
      final out = evaluate([
        plan.rule!,
      ], const TxnFacts(merchantNormalized: 'Carrefour'));
      expect(out?.categoryId, _shopping);
      expect(
        evaluate([plan.rule!], const TxnFacts(merchantNormalized: 'Starbucks')),
        isNull,
      );
    });

    test('without a key nothing is planned', () {
      final plan = planRecategorise(
        key: null,
        targetCategoryId: _shopping,
        rows: rows,
      );
      expect(plan.rule, isNull);
      expect(plan.pastIds, isEmpty);
    });

    test('analytics values are the three scopes', () {
      expect(RecategoriseScope.values.map((s) => s.analyticsValue), [
        'once',
        'future',
        'all',
      ]);
    });
  });
}
