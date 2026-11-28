import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/merchants.dart';
import 'package:pulse/core/engine/rule_engine.dart';
import 'package:pulse/core/engine/types.dart';

import 'fixtures.dart';

Direction? _d(String? s) => Direction.tryParse(s);

TxnFacts _facts(Map<String, Object?> f) => TxnFacts(
  merchantRaw: f['merchant_raw'] as String?,
  merchantNormalized: f['merchant_normalized'] as String?,
  notes: f['notes'] as String?,
  amountMinor: f['amount_minor'] as int?,
  direction: _d(f['direction'] as String?),
  accountId: f['account_id'] as String?,
  source: TxnSource.tryParse(f['source'] as String?),
);

void main() {
  group('merchants (Python parity)', () {
    final rows = loadFixtureList('merchants.json');
    test('fixture is large', () => expect(rows.length, greaterThan(150)));
    test('normalisation, category, key and descriptor cleaning match', () {
      for (final r in rows) {
        final raw = r['raw']! as String;
        final d = _d(r['direction'] as String?);
        expect(cleanDescriptor(raw), r['clean'], reason: 'clean "$raw"');
        final n = normalizeMerchant(raw, d);
        expect(n, r['normalized'], reason: 'normalize "$raw" $d');
        expect(
          guessCategorySlug(raw, d),
          r['category'],
          reason: 'category "$raw" $d',
        );
        expect(merchantKey(n), r['key'], reason: 'key "$raw" $d');
      }
    });
  });

  group('merchants (behaviour)', () {
    test('known UAE merchants resolve', () {
      expect(normalizeMerchant('CARREFOUR MOE DUBAI AE'), 'Carrefour');
      expect(guessCategorySlug('TALABAT DUBAI ARE'), 'dining');
      expect(guessCategorySlug('SALIK RECHARGE'), 'transport');
    });
    test('unknown merchant falls back to cleaned title case', () {
      expect(normalizeMerchant('JOES CAFE DUBAI AE 12345'), 'Joes Cafe');
      expect(guessCategorySlug('JOES CAFE'), isNull);
      expect(normalizeMerchant(''), isNull);
      expect(normalizeMerchant(null), isNull);
    });
    test('no false positives on substrings', () {
      expect(guessCategorySlug('EMIRATES NBD'), isNull);
      expect(guessCategorySlug('DUBAI COFFEE ROASTERS'), isNull);
      expect(guessCategorySlug("MAXIM'S CAFE"), isNull);
    });
    test('direction sensitive entries', () {
      expect(guessCategorySlug('SALARY JAN', Direction.credit), 'salary');
      expect(guessCategorySlug('ANNUAL FEE', Direction.debit), 'fees');
      expect(guessCategorySlug('ANNUAL FEE', Direction.credit), isNull);
    });
    test('every dictionary slug is a default category', () {
      const defaults = {
        'salary',
        'other_income',
        'groceries',
        'dining',
        'transport',
        'car_loan',
        'home_loan',
        'rent',
        'utilities',
        'telecom',
        'fixed_expenses',
        'education',
        'health',
        'shopping',
        'travel',
        'entertainment',
        'family',
        'savings',
        'cc_payment',
        'transfer',
        'fees',
        'other',
      };
      expect(
        merchantDictionary.map((e) => e.category).toSet().difference(defaults),
        isEmpty,
      );
    });
  });

  group('rule engine (Python parity)', () {
    final fx = loadFixture('rules.json')! as Map;
    test('conditions', () {
      for (final c in fx['conditions'] as List) {
        final m = Map<String, Object?>.from(c as Map);
        final conds = [
          for (final x in m['conditions']! as List)
            Map<String, Object?>.from(x as Map),
        ];
        final rule = compileRule(conds);
        expect(
          rule.matches(_facts(Map<String, Object?>.from(m['facts']! as Map))),
          m['matches'],
          reason: '$conds',
        );
      }
    });
    test('priority: first rule wins per field, tags accumulate', () {
      for (final e in fx['evaluations'] as List) {
        final m = Map<String, Object?>.from(e as Map);
        final rules = [
          for (final s in m['rules']! as List)
            () {
              final r = Map<String, Object?>.from(s as Map);
              return compileRule(
                [
                  for (final x in r['conditions']! as List)
                    Map<String, Object?>.from(x as Map),
                ],
                id: r['id'] as String?,
                priority: r['priority']! as int,
                categoryId: r['category_id'] as String?,
                renameMerchant: r['rename_merchant'] as String?,
                markTransfer: (r['mark_transfer'] as bool?) ?? false,
                excludeFromBudget: (r['exclude_from_budget'] as bool?) ?? false,
                tags: [...((r['tags'] as List?) ?? const []).cast<String>()],
              );
            }(),
        ];
        final out = evaluate(
          rules,
          _facts(Map<String, Object?>.from(m['facts']! as Map)),
        );
        final exp = m['outcome'] as Map<String, Object?>?;
        if (exp == null) {
          expect(out, isNull);
          continue;
        }
        expect(out!.categoryId, exp['category_id']);
        expect(out.renameMerchant, exp['rename_merchant']);
        expect(out.markTransfer, exp['mark_transfer']);
        expect(out.excludeFromBudget, exp['exclude_from_budget']);
        expect(out.tags, exp['tags']);
        expect(out.ruleIds, exp['rule_ids']);
        expect(out.firstRuleId, exp['first_rule_id']);
      }
    });
  });

  group('categoriser', () {
    final system = {
      'groceries': 'g',
      'dining': 'd',
      'shopping': 's',
      'transfer': 't',
    };
    test('rules beat the dictionary', () {
      final plain = CategoryResolver([], system);
      expect(plain.enrich('CARREFOUR MOE', Direction.debit).categoryId, 'g');
      expect(
        plain.enrich('CARREFOUR MOE', Direction.debit).source,
        'dictionary',
      );
      final ruled = CategoryResolver([
        merchantEqualsRule('carrefour', 's'),
      ], system);
      final e = ruled.enrich('CARREFOUR MOE', Direction.debit);
      expect(
        (e.merchantNormalized, e.categoryId, e.source),
        ('Carrefour', 's', 'rule'),
      );
      final unknown = ruled.enrich('JOES CAFE', Direction.debit);
      expect(unknown.categoryId, isNull);
      expect(unknown.source, isNull);
      expect(
        CategoryResolver([
          merchantEqualsRule('joes cafe', 'd'),
        ], system).enrich('JOES CAFE', Direction.debit).categoryId,
        'd',
      );
    });
    test('mark transfer resolves to the transfer category and excludes', () {
      final r = CategoryResolver([
        compileRule(
          [
            {'field': 'merchant', 'op': 'contains', 'value': 'wise'},
          ],
          id: 'x',
          markTransfer: true,
        ),
      ], system);
      final e = r.enrich('WISE PAYMENTS LTD', Direction.debit);
      expect(e.categoryId, 't');
      expect(e.excludeFromBudget, isTrue);
      expect(e.source, 'rule');
    });
    test('a rule without category keeps the dictionary category and applies tags and rename', () {
      final r = CategoryResolver([
        compileRule(
          [
            {'field': 'merchant', 'op': 'contains', 'value': 'carrefour'},
          ],
          id: 'x',
          tags: ['home'],
          renameMerchant: 'Weekly shop',
        ),
      ], system);
      final e = r.enrich('CARREFOUR MOE', Direction.debit);
      expect(
        (e.categoryId, e.source, e.merchantNormalized),
        ('g', 'dictionary', 'Weekly shop'),
      );
      expect(e.tags, ['home']);
    });
    test('amount condition sees the amount', () {
      final r = CategoryResolver([
        compileRule([
          {'field': 'amount', 'op': 'gte', 'value_minor': 100000},
        ], categoryId: 'big'),
      ], system);
      expect(
        r.enrich('JOES CAFE', Direction.debit, amountMinor: 150000).categoryId,
        'big',
      );
      expect(
        r.enrich('JOES CAFE', Direction.debit, amountMinor: 1000).categoryId,
        isNull,
      );
    });
    test(
      'priority numbers decide evaluation order regardless of list order',
      () {
        final r = CategoryResolver([
          compileRule(
            [
              {'field': 'merchant', 'op': 'contains', 'value': 'carrefour'},
            ],
            priority: 200,
            categoryId: 'late',
          ),
          compileRule(
            [
              {'field': 'merchant', 'op': 'contains', 'value': 'carrefour'},
            ],
            priority: 10,
            categoryId: 'early',
          ),
        ], system);
        expect(r.enrich('CARREFOUR', Direction.debit).categoryId, 'early');
      },
    );
  });

  group('regex safety', () {
    for (final p in [
      '(a+)+\$',
      '(.*)*x',
      r'(\d+)*',
      'x' * 201,
      '(unclosed',
      '[z-a]',
    ]) {
      test('rejects ${p.length > 20 ? 'long pattern' : p}', () {
        expect(() => checkRegex(p), throwsFormatException);
      });
    }
    test('accepts reasonable patterns', () {
      checkRegex(r'^(?:salik|darb)\b.*\d{3}$');
      checkRegex(r'(?:carrefour|lulu)\s+(?:hyper)?market');
    });
  });

  group('preview and retroactive apply', () {
    test('counts matches and category changes, honours only-uncategorised', () {
      final rule = compileRule([
        {'field': 'merchant', 'op': 'contains', 'value': 'carrefour'},
      ], categoryId: 'g');
      final rows = [
        (
          id: '1',
          facts: const TxnFacts(
            merchantRaw: 'CARREFOUR',
            merchantNormalized: 'Carrefour',
          ),
          categoryId: null as String?,
        ),
        (
          id: '2',
          facts: const TxnFacts(
            merchantRaw: 'CARREFOUR',
            merchantNormalized: 'Carrefour',
          ),
          categoryId: 'g' as String?,
        ),
        (
          id: '3',
          facts: const TxnFacts(
            merchantRaw: 'LULU',
            merchantNormalized: 'Lulu',
          ),
          categoryId: null as String?,
        ),
        (
          id: '4',
          facts: const TxnFacts(
            merchantRaw: 'CARREFOUR',
            merchantNormalized: 'Carrefour',
          ),
          categoryId: 'x' as String?,
        ),
      ];
      final p = previewRule(rule, rows);
      expect((p.matchedCount, p.scannedCount), (3, 4));
      expect(p.wouldChangeIds, ['1', '4']);
      final only = previewRule(rule, rows, onlyUncategorised: true);
      expect((only.matchedCount, only.scannedCount), (1, 2));
    });
  });
}
