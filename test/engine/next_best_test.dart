import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/catalog.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/next_best.dart';
import 'package:pulse/core/engine/rewards.dart';

CatalogCard card(
  String id, {
  String issuer = 'Bank',
  double base = 0,
  Map<String, double> cats = const {},
  double? cap,
  int fee = 0,
  int minSpend = 0,
  int? minSalary,
  Map<String, Object?> perks = const {},
  bool verified = true,
}) => CatalogCard(
  id: id,
  issuer: issuer,
  name: id,
  network: 'visa',
  annualFeeMinor: fee,
  minSalaryMinor: minSalary,
  verifiedOn: verified ? DateTime(2026, 11, 1) : null,
  rewardStructure: {
    'unit': 'cashback',
    'point_value_aed': 1,
    'base_rate': base,
    if (minSpend > 0) 'min_monthly_spend_minor': minSpend,
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
  perks: perks,
);

RankableCard held(CatalogCard c, {List<Spend> spends = const []}) =>
    RankableCard(
      id: c.id,
      title: c.name,
      spec: c.spec,
      state: computeCycle(c.spec, spends),
    );

/// One spend on [day] of each full month ending October 2026 (oldest first),
/// plus an early one in the month before, which counts as the partial first
/// month.
List<LedgerSpend> monthly(
  List<int> perMonthMinor, {
  String cat = 'groceries',
  int day = 25,
}) {
  final first = 10 - perMonthMinor.length + 1;
  return [
    LedgerSpend(CalDate(2026, first - 1, 2), 10000, cat),
    for (var i = 0; i < perMonthMinor.length; i++)
      LedgerSpend(CalDate(2026, first + i, day), perMonthMinor[i], cat),
  ];
}

const today = CalDate(2026, 11, 20);

void main() {
  group('forecast', () {
    test('trimmed mean of full months after the cap day', () {
      final f = forecastRemainingSpend(
        history: monthly([50000, 50000, 50000, 50000, 50000, 50000]),
        today: today,
        fromDay: 20,
      );
      expect(f.basis, ForecastBasis.history);
      expect(f.cycles, 6);
      expect(f.remainingMinor['groceries'], 50000);
      expect(f.confidence, ForecastConfidence.high);
      expect(f.note, 'Based on your last 6 months of spending');
      expect(f.volatile, isFalse);
    });

    test('spend before the cap day is ignored', () {
      final h = monthly([50000, 50000, 50000], day: 10);
      final f = forecastRemainingSpend(history: h, today: today, fromDay: 20);
      expect(f.totalMinor, 0);
    });

    test('the month of the first spend is partial and not counted', () {
      final f = forecastRemainingSpend(
        history: [
          const LedgerSpend(CalDate(2026, 9, 3), 10000, 'groceries'),
          const LedgerSpend(CalDate(2026, 10, 25), 50000, 'groceries'),
        ],
        today: today,
        fromDay: 20,
      );
      // Only October is a full month: fewer than two, so a fallback.
      expect(f.basis, isNot(ForecastBasis.history));
    });

    test('two to three months: medium confidence', () {
      final f = forecastRemainingSpend(
        history: monthly([40000, 60000]),
        today: today,
        fromDay: 20,
      );
      expect(f.cycles, 2);
      expect(f.remainingMinor['groceries'], 50000);
      expect(f.confidence, ForecastConfidence.medium);
    });

    test('short history uses this month pace and says so', () {
      final f = forecastRemainingSpend(
        history: [
          for (final d in [2, 5, 9, 14])
            LedgerSpend(CalDate(2026, 11, d), 20000, 'groceries'),
        ],
        today: today,
        fromDay: 20,
      );
      expect(f.basis, ForecastBasis.runRate);
      expect(f.confidence, ForecastConfidence.low);
      expect(f.note, contains('not enough history'));
      // 800 AED in 20 days, 10 days left.
      expect(f.remainingMinor['groceries'], 40000);
    });

    test('no history: budget, then typical', () {
      final b = forecastRemainingSpend(
        history: const [],
        today: today,
        budgetMinor: {'dining': 90000},
      );
      expect(b.basis, ForecastBasis.budget);
      expect(b.remainingMinor['dining'], 30000);
      expect(b.note, contains('budget'));
      final t = forecastRemainingSpend(history: const [], today: today);
      expect(t.basis, ForecastBasis.typical);
      expect(t.confidence, ForecastConfidence.low);
    });

    test('volatile spend gives the cautious (lower quartile) figure', () {
      final f = forecastRemainingSpend(
        history: monthly([20000, 200000, 30000, 180000, 25000]),
        today: today,
        fromDay: 20,
      );
      expect(f.volatile, isTrue);
      expect(f.remainingMinor['groceries'], 25000);
      expect(f.confidence, ForecastConfidence.medium);
      expect(f.note, contains('cautious'));
    });
  });

  group('next best', () {
    // The cap is hit on the held card, which earns nothing more this month.
    final sib = card('sib', cats: {'groceries': 0.1}, cap: 300);
    final heldSib = held(sib, spends: [const Spend(400000, 'groceries')]);
    final rta = card(
      'rta',
      issuer: 'EI',
      cats: {'groceries': 0.10},
      minSpend: 100000,
    );
    final adib = card(
      'adib',
      issuer: 'ADIB',
      cats: {'groceries': 0.04},
      fee: 10395,
      minSalary: 500000,
    );

    SpendForecast usually500() => forecastRemainingSpend(
      history: monthly([50000, 50000, 50000, 50000]),
      today: today,
      fromDay: 20,
    );

    test('forecast AED 500 after the cap: RTA needs 1,000, so ADIB wins', () {
      final plan = rankNextBest(
        forecast: usually500(),
        held: [heldSib],
        catalog: [sib, rta, adib],
        heldCatalogIds: {'sib'},
        salaryMinor: 1000000,
      );
      expect(plan.heldValueMinor, 0);
      expect(plan.top!.card.id, 'adib');
      expect(plan.getCards.map((o) => o.card.id), isNot(contains('rta')));
      expect(plan.skippedForMinSpend!.id, 'rta');
      expect(
        plan.reason,
        'You usually spend about AED 500 a month after the cap. EI rta needs AED 1,000 a month to earn anything, so ADIB adib is the better fit.',
      );
      // 4% of 500 = 20 a month; 240 a year less the 103.95 fee.
      expect(plan.top!.monthlyValueMinor, 2000);
      expect(plan.top!.netYearlyMinor, 24000 - 10395);
      expect(plan.top!.salaryNote, 'Needs a salary of AED 5,000 a month');
      expect(plan.top!.eligibility, Eligibility.confirmed);
    });

    test('forecast AED 1,500: RTA now clears its minimum and wins', () {
      final f = forecastRemainingSpend(
        history: monthly([150000, 150000, 150000, 150000]),
        today: today,
        fromDay: 20,
      );
      final plan = rankNextBest(
        forecast: f,
        held: [heldSib],
        catalog: [sib, rta, adib],
        heldCatalogIds: {'sib'},
        salaryMinor: 1000000,
      );
      expect(plan.top!.card.id, 'rta');
      expect(plan.top!.monthlyValueMinor, 15000);
      expect(plan.skippedForMinSpend, isNull);
    });

    test('a salary below the minimum removes the card', () {
      final plan = rankNextBest(
        forecast: usually500(),
        held: [heldSib],
        catalog: [adib],
        heldCatalogIds: {'sib'},
        salaryMinor: 400000,
      );
      expect(plan.getCards, isEmpty);
      expect(plan.reason, contains('no card in the catalog beats'));
    });

    test('unknown salary is flagged unconfirmed, never invented', () {
      final plan = rankNextBest(
        forecast: usually500(),
        held: [heldSib],
        catalog: [adib],
        heldCatalogIds: {'sib'},
      );
      expect(plan.top!.eligibility, Eligibility.unconfirmed);
    });

    test('volatile spend: the cautious forecast stays under the minimum', () {
      final f = forecastRemainingSpend(
        history: monthly([20000, 200000, 30000, 180000, 25000]),
        today: today,
        fromDay: 20,
      );
      final plan = rankNextBest(
        forecast: f,
        held: [heldSib],
        catalog: [sib, rta],
        heldCatalogIds: {'sib'},
      );
      expect(plan.getCards, isEmpty);
      expect(plan.skippedForMinSpend!.id, 'rta');
    });

    test('a held card with spend left beats getting a new one', () {
      final other = card('other', cats: {'groceries': 0.05});
      final plan = rankNextBest(
        forecast: usually500(),
        held: [heldSib, held(other)],
        catalog: [sib, other, adib],
        heldCatalogIds: {'sib', 'other'},
      );
      expect(plan.heldByCategory['groceries']!.card.id, 'other');
      expect(plan.heldValueMinor, 2500);
      expect(plan.getCards, isEmpty);
    });

    test(
      'a held card under its own minimum spend earns nothing in the forecast',
      () {
        final lowMin = card(
          'lowmin',
          cats: {'groceries': 0.05},
          minSpend: 100000,
        );
        final plan = rankNextBest(
          forecast: usually500(),
          held: [held(lowMin)],
          catalog: [lowMin, adib],
          heldCatalogIds: {'lowmin'},
        );
        expect(plan.heldValueMinor, 0);
        expect(plan.top!.card.id, 'adib');
      },
    );

    test(
      'fee against benefit: small spend does not cover the fee, large does',
      () {
        final paid = card(
          'paid',
          issuer: 'Paid',
          cats: {'groceries': 0.05},
          fee: 30000,
        );
        final base = card('base', base: 0.01);
        SpendForecast f(int m) => forecastRemainingSpend(
          history: monthly([m, m, m, m]),
          today: today,
          fromDay: 20,
        );
        // 400 AED: 5% = 20, held 1% = 4, gain 16 x 12 = 192 < 300 fee.
        var plan = rankNextBest(
          forecast: f(40000),
          held: [held(base)],
          catalog: [paid, base],
          heldCatalogIds: {'base'},
        );
        expect(plan.getCards, isEmpty);
        // 1,500 AED: gain 60 x 12 = 720 - 300.
        plan = rankNextBest(
          forecast: f(150000),
          held: [held(base)],
          catalog: [paid, base],
          heldCatalogIds: {'base'},
        );
        expect(plan.top!.netYearlyMinor, 72000 - 30000);
        expect(plan.top!.feeWaivedByForecast, isFalse);
      },
    );

    test('fee waiver reached by the forecast spend is not charged', () {
      final paid = card(
        'paid',
        issuer: 'Paid',
        cats: {'groceries': 0.05},
        fee: 30000,
        perks: {
          'fee_waiver': {
            'spend_minor': 1000000,
            'period': 'year',
            'text': 'Waived with AED 10,000 a year',
          },
        },
      );
      final base = card('base', base: 0.01);
      final f = forecastRemainingSpend(
        history: monthly([100000, 100000, 100000, 100000]),
        today: today,
        fromDay: 20,
      );
      final plan = rankNextBest(
        forecast: f,
        held: [held(base)],
        catalog: [paid, base],
        heldCatalogIds: {'base'},
      );
      expect(plan.top!.feeWaivedByForecast, isTrue);
      expect(plan.top!.netYearlyMinor, 40 * 100 * 12);
      expect(plan.top!.feeWaiverText, 'Waived with AED 10,000 a year');
    });

    test('data gaps are listed, welcome offer only while live', () {
      final c = card(
        'gap',
        cats: {'groceries': 0.08},
        fee: 10000,
        verified: false,
        perks: {
          'confidence': 'low',
          'welcome_offer': {
            'text': 'AED 100 back',
            'value_aed_est': 100,
            'valid_until': '2020-01-01',
          },
        },
      );
      final plan = rankNextBest(
        forecast: usually500(),
        held: [heldSib],
        catalog: [c],
        heldCatalogIds: {'sib'},
      );
      final o = plan.top!;
      expect(
        o.caveats,
        containsAll([
          'Figures not yet verified against the issuer',
          'Minimum salary is not in our data',
          'Low-confidence data for this card',
          'Fee waiver terms are not in our data',
        ]),
      );
      expect(o.welcomeText, isNull);
    });

    test('dismissed and held cards are never suggested', () {
      final plan = rankNextBest(
        forecast: usually500(),
        held: [heldSib],
        catalog: [adib],
        heldCatalogIds: {'sib'},
        dismissedIds: {'adib'},
      );
      expect(plan.getCards, isEmpty);
    });

    test('empty forecast says so', () {
      final plan = rankNextBest(
        forecast: const SpendForecast(
          remainingMinor: {},
          basis: ForecastBasis.typical,
          cycles: 0,
          volatile: false,
          confidence: ForecastConfidence.low,
          note: '',
        ),
        held: [heldSib],
        catalog: [adib],
      );
      expect(plan.reason, contains('Not enough spending'));
    });
  });
}
