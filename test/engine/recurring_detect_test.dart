// Recurring detection on synthetic ledgers only (no real merchants' data).
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/recurring.dart';

const _today = CalDate(2026, 11, 20);

Charge c(CalDate d, int minor, [String key = 'acme tv']) => Charge(d, minor, key.toUpperCase(), key, 'entertainment');

/// [n] monthly charges on [day], newest in [lastMonth].
List<Charge> monthly(int n, int day, int amount, {String key = 'acme tv', int lastMonth = 10, int lastYear = 2026, int Function(int)? jitter, int Function(int)? drift}) => [
  for (var i = n - 1; i >= 0; i--)
    () {
      final idx = lastYear * 12 + lastMonth - 1 - i;
      final k = n - 1 - i;
      final d = addMonths(CalDate(idx ~/ 12, idx % 12 + 1, 1), 0, day + (jitter?.call(k) ?? 0));
      return c(d, amount + (drift?.call(k) ?? 0), key);
    }(),
];

void main() {
  test('a steady monthly subscription is found with its next date', () {
    final out = detect(monthly(6, 14, 4500), const CalDate(2026, 11, 16));
    expect(out, hasLength(1));
    final s = out.single;
    expect(s.cadence, 'monthly');
    expect(s.amountKind, 'fixed');
    expect(s.typicalAmountMinor, 4500);
    expect(s.lastChargeOn, const CalDate(2026, 10, 14));
    expect(s.nextExpectedOn, const CalDate(2026, 11, 14));
    expect(s.status, 'due');
    expect(s.occurrences, 6);
  });

  test('weekly, fortnightly, quarterly and yearly cadences', () {
    final weekly = [for (var i = 0; i < 8; i++) c(const CalDate(2026, 9, 1).addDays(7 * i), 2000, 'weekly box')];
    final fortnight = [for (var i = 0; i < 6; i++) c(const CalDate(2026, 8, 3).addDays(14 * i), 9000, 'fortnight box')];
    final quarterly = [for (var i = 0; i < 4; i++) c(addMonths(const CalDate(2026, 1, 10), 3 * i), 30000, 'quarter box')];
    final yearly = [c(const CalDate(2024, 11, 25), 36500, 'annual box'), c(const CalDate(2025, 11, 25), 36500, 'annual box')];
    final out = {for (final s in detect([...weekly, ...fortnight, ...quarterly, ...yearly], _today)) s.key: s};
    expect(out['weekly box']!.cadence, 'weekly');
    expect(out['fortnight box']!.cadence, 'fortnightly');
    expect(out['quarter box']!.cadence, 'quarterly');
    expect(out['annual box']!.cadence, 'yearly');
    expect(out['annual box']!.nextExpectedOn, const CalDate(2026, 11, 25));
    expect(out['annual box']!.status, 'active');
  });

  test('date jitter of a few days still reads as monthly, anchored on the usual day', () {
    final out = detect(monthly(6, 15, 7000, jitter: (k) => const [0, 2, -1, 1, 0, -2][k]), _today);
    expect(out.single.cadence, 'monthly');
    expect(out.single.anchorDay, 15);
  });

  test('amount drift: variable bills are variable, with a recent typical amount', () {
    final out = detect(monthly(6, 5, 30000, key: 'power co', drift: (k) => const [0, 4000, -3000, 9000, 15000, 12000][k]), _today);
    final s = out.single;
    expect(s.amountKind, 'variable');
    // Median of the last three: 39000, 45000, 42000.
    expect(s.typicalAmountMinor, 42000);
    expect(s.priceIncrease, isNull);
  });

  test('small amount noise (within 5%) stays fixed', () {
    final out = detect(monthly(5, 3, 10000, drift: (k) => const [0, 100, -150, 200, -50][k]), _today);
    expect(out.single.amountKind, 'fixed');
  });

  test('a price increase is flagged right after it happens', () {
    final ch = [...monthly(4, 9, 4000, lastMonth: 9), c(const CalDate(2026, 10, 9), 5000)];
    final s = detect(ch, _today).single;
    expect(s.priceIncrease, isNotNull);
    expect(s.priceIncrease!.fromMinor, 4000);
    expect(s.priceIncrease!.toMinor, 5000);
    expect(s.priceIncrease!.pct, 25.0);
    expect(s.typicalAmountMinor, 5000);
    expect(s.amountKind, 'fixed');
  });

  test('a price increase is still seen after the new price has been charged twice', () {
    final ch = [...monthly(4, 9, 4000, lastMonth: 8), c(const CalDate(2026, 9, 9), 4800), c(const CalDate(2026, 10, 9), 4800)];
    final s = detect(ch, _today).single;
    expect(s.priceIncrease, isNotNull);
    expect(s.priceIncrease!.fromMinor, 4000);
    expect(s.priceIncrease!.toMinor, 4800);
    expect(s.typicalAmountMinor, 4800);
  });

  test('a rise under the thresholds is not a hint', () {
    // +2% and under AED 1.
    final ch = [...monthly(4, 9, 4000, lastMonth: 9), c(const CalDate(2026, 10, 9), 4080)];
    expect(detect(ch, _today).single.priceIncrease, isNull);
  });

  test('a falling price is not a hint', () {
    final ch = [...monthly(4, 9, 4000, lastMonth: 9), c(const CalDate(2026, 10, 9), 3000)];
    expect(detect(ch, _today).single.priceIncrease, isNull);
  });

  test('two plans billed by one merchant are told apart by amount', () {
    // Same merchant key, interleaved on different days: AED 20 on the 5th, AED 90 on the 20th.
    final ch = [
      for (var i = 0; i < 5; i++) ...[
        c(addMonths(const CalDate(2026, 6, 5), i), 2000, 'bill co'),
        c(addMonths(const CalDate(2026, 6, 20), i), 9000, 'bill co'),
      ],
    ];
    final out = detect(ch, _today);
    expect(out, hasLength(2));
    expect(out.map((s) => s.key).toSet(), {'bill co#20', 'bill co#90'});
    expect(out.every((s) => s.cadence == 'monthly' && s.amountKind == 'fixed'), isTrue);
    expect(out.map((s) => s.typicalAmountMinor).toSet(), {2000, 9000});
  });

  test('irregular spending at one merchant is not recurring', () {
    final ch = [
      c(const CalDate(2026, 5, 2), 3000, 'cafe'),
      c(const CalDate(2026, 5, 19), 4100, 'cafe'),
      c(const CalDate(2026, 6, 3), 2500, 'cafe'),
      c(const CalDate(2026, 7, 28), 6000, 'cafe'),
      c(const CalDate(2026, 8, 1), 3300, 'cafe'),
      c(const CalDate(2026, 10, 17), 2900, 'cafe'),
    ];
    expect(detect(ch, _today), isEmpty);
  });

  test('two charges are not enough for a monthly series, three are', () {
    expect(detect(monthly(2, 14, 4500), _today), isEmpty);
    expect(detect(monthly(3, 14, 4500), _today), hasLength(1));
  });

  test('income, transfers and card payments are never recurring payments', () {
    final ch = [
      for (final cat in ['salary', 'transfer', 'cc_payment', 'savings'])
        for (final d in monthly(4, 1, 100000, key: 'x $cat')) Charge(d.postedOn, d.amountMinor, d.merchant, d.key, cat),
    ];
    expect(detect(ch, _today), isEmpty);
  });

  test('a series that stopped is lapsed and not projected', () {
    final s = detect(monthly(5, 14, 4500, lastMonth: 5), _today).single;
    expect(s.status, 'lapsed');
    expect(occurrencesBetween(s, const CalDate(2026, 11, 1), const CalDate(2026, 11, 30)), isEmpty);
  });

  test('split payments on one day count once and sum', () {
    final ch = [
      for (final d in monthly(4, 1, 5000, key: 'rent co')) ...[d, c(d.postedOn, 5000, 'rent co')],
    ];
    final s = detect(ch, _today).single;
    expect(s.occurrences, 4);
    expect(s.typicalAmountMinor, 10000);
  });

  test('month-end anchors clamp in short months', () {
    final ch = [c(const CalDate(2026, 8, 31), 1000), c(const CalDate(2026, 9, 30), 1000), c(const CalDate(2026, 10, 31), 1000)];
    expect(detect(ch, _today).single.nextExpectedOn, const CalDate(2026, 11, 30));
  });

  test('detection is deterministic: input order does not matter', () {
    final ch = monthly(6, 14, 4500);
    final a = detect(ch, _today).single;
    final b = detect(ch.reversed.toList(), _today).single;
    expect([a.key, a.nextExpectedOn, a.typicalAmountMinor], [b.key, b.nextExpectedOn, b.typicalAmountMinor]);
  });
}
