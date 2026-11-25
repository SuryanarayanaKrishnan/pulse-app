import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/investing.dart';

InvestRule rule({
  RuleFrequency f = RuleFrequency.monthly,
  int day = 5,
  CalDate? start,
  CalDate? end,
  bool active = true,
}) => InvestRule(
  id: 'r1',
  symbol: 'VOO',
  amountMinor: 20000,
  frequency: f,
  day: day,
  startDate: start ?? const CalDate(2026, 1, 1),
  endDate: end,
  active: active,
);

RuleOccurrence occ(CalDate d, OccurrenceStatus s) => RuleOccurrence(
  id: d.toIso(),
  ruleId: 'r1',
  due: d,
  amountMinor: 20000,
  status: s,
);

void main() {
  group('schedule', () {
    test('monthly fires on the day, clamped to short months', () {
      final r = rule(day: 31, start: const CalDate(2026, 1, 1));
      final d = scheduledDates(
        r,
        const CalDate(2026, 1, 1),
        const CalDate(2026, 4, 30),
      );
      expect(d, [
        const CalDate(2026, 1, 31),
        const CalDate(2026, 2, 28),
        const CalDate(2026, 3, 31),
        const CalDate(2026, 4, 30),
      ]);
    });

    test('never before the start or after the end', () {
      final r = rule(
        start: const CalDate(2026, 3, 10),
        end: const CalDate(2026, 5, 31),
      );
      final d = scheduledDates(
        r,
        const CalDate(2026, 1, 1),
        const CalDate(2026, 12, 31),
      );
      expect(d, [const CalDate(2026, 4, 5), const CalDate(2026, 5, 5)]);
    });

    test('weekly fires on the weekday', () {
      final r = rule(
        f: RuleFrequency.weekly,
        day: 5,
        start: const CalDate(2026, 11, 1),
      ); // Friday
      final d = scheduledDates(
        r,
        const CalDate(2026, 11, 1),
        const CalDate(2026, 11, 30),
      );
      expect(d, [
        const CalDate(2026, 11, 6),
        const CalDate(2026, 11, 13),
        const CalDate(2026, 11, 20),
        const CalDate(2026, 11, 27),
      ]);
    });

    test('next due, and nothing for a paused rule', () {
      expect(
        nextDue(rule(), const CalDate(2026, 11, 25)),
        const CalDate(2026, 12, 5),
      );
      expect(
        nextDue(rule(), const CalDate(2026, 11, 5)),
        const CalDate(2026, 11, 5),
      );
      expect(nextDue(rule(active: false), const CalDate(2026, 11, 25)), isNull);
    });
  });

  group('expected buys', () {
    test('past due and unrecorded become pending candidates', () {
      final r = rule(start: const CalDate(2026, 8, 1));
      final due = dueButUnrecorded(r, {
        const CalDate(2026, 10, 5),
      }, const CalDate(2026, 11, 25));
      expect(due, [const CalDate(2026, 11, 5)]);
    });

    test('looks back a limited window so an old rule does not flood', () {
      final r = rule(start: const CalDate(2020, 1, 1));
      final due = dueButUnrecorded(r, {}, const CalDate(2026, 11, 25));
      expect(due.length, lessThanOrEqualTo(3));
      expect(due.last, const CalDate(2026, 11, 5));
    });

    test('a paused rule adds nothing', () {
      expect(
        dueButUnrecorded(rule(active: false), {}, const CalDate(2026, 11, 25)),
        isEmpty,
      );
    });
  });

  group('adherence', () {
    test('counts, streak and invested total', () {
      final a = adherenceOf([
        occ(const CalDate(2026, 7, 5), OccurrenceStatus.confirmed),
        occ(const CalDate(2026, 8, 5), OccurrenceStatus.skipped),
        occ(const CalDate(2026, 9, 5), OccurrenceStatus.confirmed),
        occ(const CalDate(2026, 10, 5), OccurrenceStatus.confirmed),
        occ(const CalDate(2026, 11, 5), OccurrenceStatus.pending),
      ]);
      expect((a.confirmed, a.skipped, a.pending), (3, 1, 1));
      expect(a.streak, 2); // pending neither breaks nor extends
      expect(a.investedMinor, 60000);
      expect(a.pct, closeTo(60, 0.001));
      expect(a.summary, '3 of 5 kept');
    });

    test('empty is honest', () {
      final a = adherenceOf(const []);
      expect(a.pct, isNull);
      expect(a.summary, 'No buys due yet');
    });
  });

  group('buying', () {
    test('weighted average cost', () {
      final r = applyBuy(units: 10, avgCost: 400, amount: 520, price: 520 / 1);
      expect(r.units, 11);
      expect(r.bought, 1);
      expect(r.avgCost, closeTo((4000 + 520) / 11, 1e-9));
    });

    test('first buy sets the average to the price', () {
      final r = applyBuy(units: 0, amount: 200, price: 500);
      expect((r.units, r.avgCost), (0.4, 500));
    });

    test('unknown cost stays unknown instead of inventing one', () {
      final r = applyBuy(units: 5, avgCost: null, amount: 200, price: 100);
      expect(r.avgCost, 0);
      expect(r.units, 7);
    });

    test('position P&L through the shared fund maths', () {
      final v = valuePosition(
        units: 2,
        price: 500,
        avgCost: 400,
        fxToAed: 3.6725,
      );
      expect(v.valueNativeMinor, 100000);
      expect(v.gainPct, closeTo(25, 1e-9));
      expect(v.valueAedMinor, 367250);
    });
  });

  group('rule text', () {
    test('"buy \$200 of VOO monthly"', () {
      final d = parseRuleText(r'buy $200 of VOO monthly')!;
      expect(
        (d.symbol, d.amountMinor, d.currency, d.frequency, d.day),
        ('VOO', 20000, 'USD', RuleFrequency.monthly, 1),
      );
    });

    test('currency, ticker and day of month', () {
      final d = parseRuleText('invest 500 AED in VTI every month on the 5th')!;
      expect(
        (d.symbol, d.amountMinor, d.currency, d.day),
        ('VTI', 50000, 'AED', 5),
      );
    });

    test('weekly on a named day', () {
      final d = parseRuleText('100 usd QQQ weekly on friday')!;
      expect((d.symbol, d.frequency, d.day), ('QQQ', RuleFrequency.weekly, 5));
    });

    test('lower-case ticker after "of"', () {
      expect(parseRuleText('buy 50 dollars of voo every month')!.symbol, 'VOO');
    });

    test('no amount or no ticker is not a rule', () {
      expect(parseRuleText('buy VOO monthly'), isNull);
      expect(parseRuleText(r'$200 monthly'), isNull);
    });

    test('ordinals and weekday names', () {
      expect(ordinal(1), '1st');
      expect(ordinal(12), '12th');
      expect(ordinal(23), '23rd');
      expect(weekdayName(5), 'Friday');
      expect(rule().cadenceLabel, 'every month on the 5th');
    });
  });
}
