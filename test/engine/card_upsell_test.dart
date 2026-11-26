import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/card_upsell.dart';
import 'package:pulse/core/engine/catalog.dart';

CatalogCard card(
  String id, {
  String issuer = 'Bank',
  double base = 0.01,
  Map<String, double> cats = const {},
  int fee = 0,
  int? minSalary,
  int minSpend = 0,
  double? cap,
}) => CatalogCard(
  id: id,
  issuer: issuer,
  name: id,
  network: 'visa',
  annualFeeMinor: fee,
  minSalaryMinor: minSalary,
  rewardStructure: {
    'unit': 'cashback',
    'point_value_aed': 1,
    'base_rate': base,
    'min_monthly_spend_minor': minSpend,
    'rules': [
      for (final e in cats.entries)
        {
          'name': e.key,
          'categories': [e.key],
          'rate': e.value,
          'monthly_cap_units': ?cap,
        },
    ],
  },
  perks: const {},
);

void main() {
  // Dining, AED 900 a month.
  const spend = 90000;
  final mine = card('mine', base: 0.01, cats: {'dining': 0.02}); // 18.00
  CardUpsell? run(
    List<CatalogCard> catalog, {
    List<CatalogCard>? owned,
    Set<String> dismissed = const {},
    Set<String> unavailable = const {},
    int? salary,
    int spendMinor = spend,
    int? total,
    UpsellPolicy policy = const UpsellPolicy(),
  }) => suggestUnownedCard(
    catalog: catalog,
    owned: owned ?? [mine],
    dismissedIds: dismissed,
    unavailableIssuers: unavailable,
    category: 'dining',
    monthlySpendMinor: spendMinor,
    totalMonthlySpendMinor: total,
    salaryMinor: salary,
    policy: policy,
  );

  group('maths', () {
    test('monthly reward uses the matching rule, caps and base rate', () {
      final c = card('c', cats: {'dining': 0.05}, cap: 20);
      expect(
        monthlyRewardMinor(
          c,
          spendMinor: spend,
          totalMonthlySpendMinor: spend,
          category: 'dining',
        ),
        2000,
      );
      expect(
        monthlyRewardMinor(
          c,
          spendMinor: spend,
          totalMonthlySpendMinor: spend,
          category: 'travel',
        ),
        900,
      );
    });

    test('unmet minimum monthly spend earns nothing', () {
      final c = card('c', cats: {'dining': 0.05}, minSpend: 500000);
      expect(
        monthlyRewardMinor(
          c,
          spendMinor: spend,
          totalMonthlySpendMinor: spend,
          category: 'dining',
        ),
        0,
      );
      expect(
        monthlyRewardMinor(
          c,
          spendMinor: spend,
          totalMonthlySpendMinor: 500000,
          category: 'dining',
        ),
        4500,
      );
    });

    test('figures: gross, net of fee per year and per month', () {
      // 5% of 900 = 45.00 vs 18.00: +27.00 a month, 324.00 a year, less 120 fee.
      final s = run([
        card('c', cats: {'dining': 0.05}, fee: 12000),
      ])!;
      expect(s.ownedMonthlyMinor, 1800);
      expect(s.candidateMonthlyMinor, 4500);
      expect(s.grossMonthlyMinor, 2700);
      expect(s.netYearlyMinor, 2700 * 12 - 12000);
      expect(s.netMonthlyMinor, 1700);
      expect(s.ruleName, 'dining');
      expect(s.ownedBest!.id, 'mine');
    });
  });

  group('thresholds', () {
    test('AED 25 a month net qualifies on its own', () {
      // 6% -> 54.00; gross 36.00.
      expect(
        run([
          card('c', cats: {'dining': 0.06}),
        ]),
        isNotNull,
      );
    });

    test('just under AED 25 and under 15% does not qualify', () {
      final big = card(
        'big',
        base: 0.01,
        cats: {'dining': 0.10},
      ); // owned 90.00
      // candidate 11% -> 99.00: +9.00 (10%), under both limits.
      expect(
        run(
          [
            card('c', cats: {'dining': 0.11}),
          ],
          owned: [big],
        ),
        isNull,
      );
    });

    test('15% better qualifies even under AED 25', () {
      final big = card('big', cats: {'dining': 0.10}); // 90.00
      // 11.5% -> 103.50: +13.50 = 15%.
      final s = run(
        [
          card('c', cats: {'dining': 0.115}),
        ],
        owned: [big],
      );
      expect(s, isNotNull);
      expect(s!.netMonthlyMinor, 1350);
      expect(s.gainRatio, closeTo(0.15, 1e-9));
    });

    test('a big percentage on a tiny base needs the AED 5 floor', () {
      final tiny = card('tiny', base: 0.0, cats: {'dining': 0.001}); // 0.90
      // +1.80 a month: 200% better but under AED 5.
      expect(
        run(
          [
            card('c', cats: {'dining': 0.003}),
          ],
          owned: [tiny],
        ),
        isNull,
      );
      // +5.40: over the floor.
      expect(
        run(
          [
            card('c', cats: {'dining': 0.007}),
          ],
          owned: [tiny],
        ),
        isNotNull,
      );
    });

    test('a fee can erase the gain', () {
      // +27.00 a month gross, 324 a year; fee 300 leaves 2.00 a month.
      expect(
        run([
          card('c', cats: {'dining': 0.05}, fee: 30000),
        ]),
        isNull,
      );
    });

    test('policy thresholds can be tuned', () {
      final c = card('c', cats: {'dining': 0.05});
      expect(
        run(
          [c],
          policy: const UpsellPolicy(
            minMonthlyGainMinor: 5000,
            minGainRatio: 9,
          ),
        ),
        isNull,
      );
    });

    test('nothing for zero spend or an empty wallet', () {
      final c = card('c', cats: {'dining': 0.05});
      expect(run([c], spendMinor: 0), isNull);
      expect(run([c], owned: const []), isNull);
    });

    test('a card that earns no more is never suggested', () {
      expect(
        run([
          card('c', cats: {'dining': 0.02}),
        ]),
        isNull,
      );
      expect(
        run([
          card('c', cats: {'dining': 0.01}),
        ]),
        isNull,
      );
    });
  });

  group('ranking', () {
    test('highest net yearly gain wins, fee counted', () {
      final a = card('a', cats: {'dining': 0.06}); // +36/mo = 432/yr
      final b = card(
        'b',
        cats: {'dining': 0.08},
        fee: 30000,
      ); // +54/mo = 648 - 300 = 348
      final c = card('c', cats: {'dining': 0.07}); // +45/mo = 540/yr
      expect(
        run([a, b]),
        isA<CardUpsell>().having((s) => s.card.id, 'id', 'a'),
      );
      expect(run([a, b, c])!.card.id, 'c');
    });

    test('ties go to the lower fee, then the id', () {
      final x = card('x', cats: {'dining': 0.06});
      final w = card('w', cats: {'dining': 0.06});
      expect(run([x, w])!.card.id, 'w');
      // Same net yearly (432.00): z earns 64.00 a month but pays a 120 fee.
      final y = card('y', cats: {'dining': 0.06});
      final z = card('z', cats: {'dining': 64 / 900}, fee: 12000);
      expect(run([z, y])!.netYearlyMinor, run([z])!.netYearlyMinor);
      expect(run([z, y])!.card.id, 'y');
    });

    test('returns exactly one suggestion', () {
      final r = run([
        for (var i = 0; i < 5; i++)
          card('c$i', cats: {'dining': 0.06 + i / 100}),
      ]);
      expect(r!.card.id, 'c4');
    });

    test('best owned card is the benchmark, not the first', () {
      final weak = card('weak', base: 0.005);
      final r = run(
        [
          card('c', cats: {'dining': 0.03}),
        ],
        owned: [weak, mine],
      );
      // 27.00 vs mine 18.00: +9.00 and 50%: qualifies by ratio.
      expect(r!.ownedBest!.id, 'mine');
      expect(r.grossMonthlyMinor, 900);
    });
  });

  group('eligibility', () {
    final rich = card('rich', cats: {'dining': 0.06}, minSalary: 2000000);
    final mid = card('mid', cats: {'dining': 0.05}, minSalary: 800000);

    test('known salary: min salary must be at or under it', () {
      expect(run([rich], salary: 1999999), isNull);
      expect(run([rich], salary: 2000000)!.card.id, 'rich');
      expect(run([rich, mid], salary: 1000000)!.card.id, 'mid');
    });

    test('unknown salary skips high minimums only', () {
      expect(run([rich]), isNull);
      expect(run([rich, mid])!.card.id, 'mid');
      expect(
        run([
          card('edge', cats: {'dining': 0.06}, minSalary: 1500000),
        ]),
        isNotNull,
      );
    });

    test('no stated minimum is always attainable', () {
      expect(isAttainable(card('c'), salaryMinor: 1), isTrue);
      expect(isAttainable(card('c')), isTrue);
    });

    test('unavailable issuers are excluded, however spelled', () {
      final c = card('c', issuer: 'Emirates NBD', cats: {'dining': 0.06});
      expect(run([c], unavailable: {'emirates-nbd'}), isNull);
      expect(run([c], unavailable: {'ADCB'}), isNotNull);
    });
  });

  group('exclusions', () {
    final c = card('c', cats: {'dining': 0.06});
    test('never suggests a card already held', () {
      expect(run([c], owned: [mine, c]), isNull);
    });
    test('never suggests a held card the catalog entry for is missing', () {
      expect(
        suggestUnownedCard(
          catalog: [c],
          owned: [mine],
          ownedIds: {'c'},
          category: 'dining',
          monthlySpendMinor: spend,
        ),
        isNull,
      );
    });
    test('never suggests a dismissed card, falls to the next one', () {
      final d = card('d', cats: {'dining': 0.05});
      expect(run([c], dismissed: {'c'}), isNull);
      expect(run([c, d], dismissed: {'c'})!.card.id, 'd');
    });
    test('a malformed candidate never breaks the pick', () {
      final bad = CatalogCard(
        id: 'bad',
        issuer: 'x',
        name: 'y',
        network: null,
        annualFeeMinor: 0,
        minSalaryMinor: null,
        rewardStructure: const {'unit': 'miles'},
        perks: const {},
      );
      expect(run([bad, c])!.card.id, 'c');
    });
  });

  test('typical spend falls back for unknown categories', () {
    expect(typicalMonthlySpendMinor('dining'), 90000);
    expect(typicalMonthlySpendMinor('rent'), 50000);
    expect(typicalMonthlySpendMinor(null), 50000);
  });
}
