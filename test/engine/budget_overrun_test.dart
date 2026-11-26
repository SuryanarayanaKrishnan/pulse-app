import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/budget_overrun.dart';

const cur = '2026-11-01';

/// Months before [cur], oldest first: m(1) is October.
String m(int back) {
  final i = 2026 * 12 + 10 - back;
  return '${(i ~/ 12).toString().padLeft(4, '0')}-${(i % 12 + 1).toString().padLeft(2, '0')}-01';
}

/// Spend in AED, oldest earlier month first, then the current month.
OverrunInput input(
  List<int> spendAed, {
  int plan = 1000,
  List<OverrunTx> txs = const [],
  Set<String> marked = const {},
}) {
  final n = spendAed.length;
  return OverrunInput(
    categoryId: 'dining',
    months: [
      for (var i = 0; i < n; i++)
        MonthAmount(m(n - 1 - i), plan * 100, spendAed[i] * 100),
    ],
    txs: txs,
    markedOneOff: marked,
  );
}

OverrunTx tx(String id, String merchant, int aed, {String month = cur}) =>
    OverrunTx(id: id, month: month, merchant: merchant, amountMinor: aed * 100);

void main() {
  group('one-off', () {
    test('one big purchase with normal months around it', () {
      final o = analyseOverrun(
        input(
          [900, 950, 800, 920, 870, 1700],
          txs: [
            tx('a', 'Noon', 800),
            tx('b', 'Talabat', 60),
            for (var i = 0; i < 8; i++) tx('c$i', 'Cafe', 50),
          ],
        ),
        currentMonth: cur,
      )!;
      expect(o.kind, OverrunKind.oneOff);
      expect(o.reason, OverrunReason.singlePurchase);
      expect(o.overMinor, 70000);
      expect(o.largest!.merchant, 'Noon');
      expect(o.contributors.first.merchant, 'Noon');
      expect(
        o.suggestedCeilingMinor,
        isNull,
        reason: 'a one-off never suggests a new ceiling',
      );
      expect(overrunSentence(o), contains('Noon'));
    });

    test('a single month over with many small payments is a one-off month', () {
      final o = analyseOverrun(
        input(
          [900, 950, 800, 920, 870, 1200],
          txs: [for (var i = 0; i < 12; i++) tx('c$i', 'Cafe $i', 100)],
        ),
        currentMonth: cur,
      )!;
      expect(o.kind, OverrunKind.oneOff);
      expect(o.reason, OverrunReason.singleMonth);
      expect(overrunSentence(o), contains('this month only'));
    });

    test('over by pennies is not an overrun', () {
      expect(
        analyseOverrun(input([900, 900, 900, 1005]), currentMonth: cur),
        isNull,
      );
      expect(
        analyseOverrun(input([900, 900, 900, 1025]), currentMonth: cur),
        isNull,
        reason: 'under the 3% tolerance',
      );
      expect(
        analyseOverrun(input([900, 900, 900, 1031]), currentMonth: cur),
        isNotNull,
      );
    });

    test('not over, or no plan, gives nothing', () {
      expect(
        analyseOverrun(input([900, 900, 900, 950]), currentMonth: cur),
        isNull,
      );
      expect(
        analyseOverrun(
          input([900, 900, 900, 5000], plan: 0),
          currentMonth: cur,
        ),
        isNull,
      );
    });
  });

  group('pattern', () {
    test('three months over: typical overrun and ceiling', () {
      // Over by 200, 300 and 250 in the last three months; fine before.
      final o = analyseOverrun(
        input([900, 950, 1200, 1300, 1250, 1250]),
        currentMonth: cur,
      )!;
      expect(o.kind, OverrunKind.pattern);
      expect(o.reason, OverrunReason.repeatedMonths);
      expect(o.monthsOver, 4);
      expect(o.typicalOverMinor, 25000);
      // Typical spend is the median of the months compared: 1200 or so.
      expect(o.suggestedCeilingMinor, 125000);
      expect(o.suggestedCeilingMinor! > o.plannedMinor, isTrue);
      expect(o.suggestedCeilingMinor! % 5000, 0, reason: 'a tidy number');
      expect(overrunSentence(o), contains('Over in 4 of the last 6 months'));
    });

    test(
      'exactly three of six months (this one plus two earlier) is a pattern',
      () {
        final o = analyseOverrun(
          input([900, 1200, 900, 1250, 900, 1300]),
          currentMonth: cur,
        )!;
        expect(o.kind, OverrunKind.pattern);
        expect(o.monthsOver, 3);
      },
    );

    test('every month since you started, with only two earlier months', () {
      final o = analyseOverrun(input([1200, 1250, 1300]), currentMonth: cur)!;
      expect(o.kind, OverrunKind.pattern);
      expect(o.monthsCompared, 2);
    });

    test('rising each month without being over earlier is a pattern', () {
      final o = analyseOverrun(
        input([600, 700, 800, 1100]),
        currentMonth: cur,
      )!;
      expect(o.kind, OverrunKind.pattern);
      expect(o.reason, OverrunReason.risingTrend);
      expect(
        o.suggestedCeilingMinor! >= 110000,
        isTrue,
        reason: 'covers this month on a climbing line',
      );
      expect(overrunSentence(o), contains('risen'));
    });

    test('one huge payment after a gentle rise is not a trend', () {
      final o = analyseOverrun(
        input(
          [800, 870, 920, 1900],
          txs: [
            tx('a', 'Noon', 900),
            for (var i = 0; i < 10; i++) tx('c$i', 'Cafe', 100),
          ],
        ),
        currentMonth: cur,
      )!;
      expect(o.reason, isNot(OverrunReason.risingTrend));
      expect(o.onePayment, isTrue);
    });

    test('a bumpy history is not a trend', () {
      final o = analyseOverrun(
        input([600, 900, 700, 1100]),
        currentMonth: cur,
      )!;
      expect(o.reason, isNot(OverrunReason.risingTrend));
    });

    test('months older than the window are ignored', () {
      // Eight months of history: the three oldest were over, the five most
      // recent were fine, then this month.
      final o = analyseOverrun(
        input([1300, 1300, 1300, 900, 900, 900, 900, 900, 1200]),
        currentMonth: cur,
      )!;
      expect(o.kind, OverrunKind.oneOff);
      expect(o.monthsCompared, overrunLookback);
    });
  });

  group('honest about short history', () {
    test('no earlier month: too early, never a verdict', () {
      final o = analyseOverrun(input([1500]), currentMonth: cur)!;
      expect(o.kind, OverrunKind.tooEarly);
      expect(o.reason, OverrunReason.shortHistory);
      expect(o.suggestedCeilingMinor, isNull);
      expect(overrunSentence(o), contains('Not enough months yet'));
    });

    test('one earlier month: still too early', () {
      final o = analyseOverrun(input([900, 1500]), currentMonth: cur)!;
      expect(o.kind, OverrunKind.tooEarly);
      expect(o.suggestedCeilingMinor, isNull);
    });

    test(
      'too early still names one payment when it explains the overspend',
      () {
        final o = analyseOverrun(
          input([900, 1500], txs: [tx('a', 'Noon', 700), tx('b', 'Cafe', 800)]),
          currentMonth: cur,
        )!;
        expect(o.kind, OverrunKind.tooEarly);
        expect(overrunSentence(o), contains('Too early to say'));
      },
    );

    test(
      'two earlier months, one over: two months running, too early to call',
      () {
        final p = analyseOverrun(input([1200, 900, 1300]), currentMonth: cur)!;
        expect(p.kind, OverrunKind.tooEarly);
        expect(p.reason, OverrunReason.twoMonthsRunning);
      },
    );

    test('months with no plan are not compared', () {
      final o = analyseOverrun(
        OverrunInput(
          categoryId: 'dining',
          months: [
            MonthAmount(m(3), 0, 5000),
            MonthAmount(m(2), 0, 5000),
            MonthAmount(m(1), 100000, 90000),
            MonthAmount(cur, 100000, 150000),
          ],
        ),
        currentMonth: cur,
      )!;
      expect(o.monthsCompared, 1);
      expect(o.kind, OverrunKind.tooEarly);
    });
  });

  group('watch', () {
    test('over now and once before, with several normal months', () {
      final o = analyseOverrun(
        input([900, 900, 1300, 900, 900, 1250]),
        currentMonth: cur,
      )!;
      expect(o.kind, OverrunKind.watch);
      expect(o.reason, OverrunReason.oneEarlierMonth);
      expect(o.suggestedCeilingMinor, isNull);
    });
  });

  group('marking a one-off', () {
    test('a marked current month is not reported', () {
      expect(
        analyseOverrun(
          input([900, 900, 900, 1500], marked: {cur}),
          currentMonth: cur,
        ),
        isNull,
      );
    });

    test('a marked earlier month is left out of the pattern count', () {
      // Over in two earlier months and now: a pattern. Mark one earlier month
      // as a one-off and it is no longer one.
      final unmarked = analyseOverrun(
        input([900, 900, 1300, 1300, 900, 1250]),
        currentMonth: cur,
      )!;
      expect(unmarked.kind, OverrunKind.pattern);
      final marked = analyseOverrun(
        input([900, 900, 1300, 1300, 900, 1250], marked: {m(3)}),
        currentMonth: cur,
      )!;
      expect(marked.kind, isNot(OverrunKind.pattern));
      expect(marked.monthsOver, 2);
    });

    test('marked months do not set the suggested ceiling', () {
      // A huge marked month would drag a typical spend up if counted.
      final a = analyseOverrun(
        input([900, 5000, 1300, 1300, 1250], marked: {m(3)}),
        currentMonth: cur,
      )!;
      expect(a.kind, OverrunKind.pattern);
      expect(a.suggestedCeilingMinor, lessThanOrEqualTo(135000));
    });
  });

  test(
    'a change of plan mid-history compares each month with its own plan',
    () {
      final o = analyseOverrun(
        OverrunInput(
          categoryId: 'dining',
          months: [
            MonthAmount(m(3), 50000, 90000), // over a low plan
            MonthAmount(m(2), 100000, 90000),
            MonthAmount(m(1), 100000, 95000),
            MonthAmount(cur, 100000, 130000),
          ],
        ),
        currentMonth: cur,
      )!;
      expect(o.monthsOver, 2);
      expect(o.kind, OverrunKind.watch);
    },
  );

  test('analyseOverruns skips fine categories and puts the biggest first', () {
    final out = analyseOverruns([
      OverrunInput(categoryId: 'a', months: [MonthAmount(cur, 100000, 120000)]),
      OverrunInput(categoryId: 'b', months: [MonthAmount(cur, 100000, 90000)]),
      OverrunInput(categoryId: 'c', months: [MonthAmount(cur, 100000, 180000)]),
    ], currentMonth: cur);
    expect([for (final o in out) o.categoryId], ['c', 'a']);
  });

  group('rounding and wording', () {
    test('niceCeilingMinor rounds up to a tidy step', () {
      expect(niceCeilingMinor(8120), 8500);
      expect(niceCeilingMinor(12000), 12000);
      expect(niceCeilingMinor(12001), 13000);
      expect(niceCeilingMinor(112300), 115000);
      expect(niceCeilingMinor(8120), 8500);
      expect(niceCeilingMinor(210000), 210000);
      expect(niceCeilingMinor(215001), 220000);
    });

    test('aedWhole groups thousands', () {
      expect(aedWhole(123456), 'AED 1,235');
      expect(aedWhole(100), 'AED 1');
      expect(aedWhole(250000000), 'AED 2,500,000');
    });

    test(
      'the caveat says these are estimates and nothing changes without a tap',
      () {
        expect(overrunCaveat, contains('Estimates'));
        expect(overrunCaveat, contains('nothing changes unless you tap'));
      },
    );
  });

  group('where the extra would come from', () {
    test('largest spare amounts first, skipping the over category', () {
      final h = fundingHint(
        extraMinor: 20000,
        exceptId: 'dining',
        slack: const [
          Slack('shopping', 15000),
          Slack('dining', 90000),
          Slack('travel', 12000),
          Slack('fun', 3000),
        ],
      );
      expect([for (final s in h.sources) s.categoryId], ['shopping', 'travel']);
      expect(h.covered, isTrue);
      expect(
        fundingSentence(h, (id) => id),
        contains(
          'could come from shopping (AED 150 unused) and travel (AED 120 unused)',
        ),
      );
    });

    test('a tight plan says how much is short', () {
      final h = fundingHint(
        extraMinor: 30000,
        exceptId: 'dining',
        slack: const [Slack('fun', 10000)],
      );
      expect(h.covered, isFalse);
      expect(h.shortMinor, 20000);
      expect(fundingSentence(h, (id) => id), contains('AED 200 short'));
    });

    test('nothing spare says so', () {
      final h = fundingHint(
        extraMinor: 30000,
        exceptId: 'dining',
        slack: const [],
      );
      expect(fundingSentence(h, (id) => id), contains('nothing spare'));
    });
  });
}
