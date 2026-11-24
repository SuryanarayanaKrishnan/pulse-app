import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/nw_history.dart';

const _today = CalDate(2026, 11, 24);

NwPoint p(CalDate d, int net) => NwPoint(d, net + 1000, 1000);

void main() {
  final pts = [
    p(const CalDate(2025, 9, 1), 100),
    p(const CalDate(2026, 3, 1), 200),
    p(const CalDate(2026, 8, 20), 300),
    p(const CalDate(2026, 10, 30), 400),
    p(const CalDate(2026, 11, 24), 500),
  ];

  test('ranges cut the history at the window start and carry the held value in', () {
    final m1 = pointsFor(pts, NwRange.m1, _today);
    expect(m1.map((x) => x.date), [const CalDate(2026, 10, 25), const CalDate(2026, 10, 30), const CalDate(2026, 11, 24)]);
    expect(m1.first.netMinor, 300); // held from 20 Aug
    final y1 = pointsFor(pts, NwRange.y1, _today);
    expect(y1.first.date, const CalDate(2025, 11, 24));
    expect(y1.first.netMinor, 100);
    expect(pointsFor(pts, NwRange.all, _today), pts);
  });

  test('a range with nothing before it starts at its first point', () {
    final r = pointsFor([p(const CalDate(2026, 11, 20), 10), p(const CalDate(2026, 11, 24), 30)], NwRange.m3, _today);
    expect(r.first.date, const CalDate(2026, 11, 20));
  });

  test('change is first to last, in minor units and percent', () {
    final ch = changeOver(pointsFor(pts, NwRange.m6, _today));
    expect(ch.deltaMinor, 500 - 200);
    expect(ch.pct, closeTo(150, 1e-9));
    expect(changeOver([p(_today, 5)]).deltaMinor, 0);
    expect(changeOver([p(const CalDate(2026, 1, 1), 0), p(_today, 5)]).pct, 0);
  });

  test('sampling keeps the ends and at most max points', () {
    final many = [for (var i = 0; i < 365; i++) p(const CalDate(2025, 11, 24).addDays(i), i)];
    final s = sample(many, 60);
    expect(s, hasLength(60));
    expect(s.first, many.first);
    expect(s.last, many.last);
    expect(sample(many.take(10).toList(), 60), hasLength(10));
  });

  group('backfill', () {
    // Today: assets 10,000.00 and liabilities 2,000.00 (minor units).
    const assetsNow = 1000000, liabNow = 200000;

    test('walks transactions back out of today, day by day', () {
      final flows = [
        NwFlow(const CalDate(2026, 11, 20), -30000, isCard: false), // spent 300 from the bank
        NwFlow(const CalDate(2026, 11, 22), 500000, isCard: false), // salary in
        NwFlow(const CalDate(2026, 11, 21), -50000, isCard: true), // 500 on the card
      ];
      final out = backfill(assetsNowMinor: assetsNow, liabilitiesNowMinor: liabNow, flows: flows, today: _today, firstSnapshot: _today);
      final by = {for (final x in out) x.date: x};
      // End of 22 Nov: nothing after it.
      expect(by[const CalDate(2026, 11, 23)]!.assetsMinor, assetsNow);
      expect(by[const CalDate(2026, 11, 22)]!.assetsMinor, assetsNow);
      // End of 21 Nov: the salary of the 22nd is not in yet.
      expect(by[const CalDate(2026, 11, 21)]!.assetsMinor, assetsNow - 500000);
      // The card spend of the 21st raised liabilities; before it they were lower.
      expect(by[const CalDate(2026, 11, 21)]!.liabilitiesMinor, liabNow);
      expect(by[const CalDate(2026, 11, 20)]!.liabilitiesMinor, liabNow - 50000);
      // End of 19 Nov: the 300 had not left yet.
      expect(by[const CalDate(2026, 11, 19)]!.assetsMinor, assetsNow - 500000 + 30000);
      expect(by.keys.reduce((a, b) => a < b ? a : b), const CalDate(2026, 11, 19));
      expect(out.every((x) => x.estimated), isTrue);
      // Sorted oldest first and strictly before the first snapshot.
      expect(out.first.date, const CalDate(2026, 11, 19));
      expect(out.last.date, const CalDate(2026, 11, 23));
    });

    test('a card payment moves cash and debt together: net worth is unchanged by it', () {
      final flows = [
        NwFlow(const CalDate(2026, 11, 10), -100000, isCard: false),
        NwFlow(const CalDate(2026, 11, 10), 100000, isCard: true),
      ];
      final out = backfill(assetsNowMinor: assetsNow, liabilitiesNowMinor: liabNow, flows: flows, today: _today, firstSnapshot: _today);
      final before = out.firstWhere((x) => x.date == const CalDate(2026, 11, 9));
      final after = out.firstWhere((x) => x.date == const CalDate(2026, 11, 10));
      expect(before.netMinor, after.netMinor);
      expect(before.assetsMinor, assetsNow + 100000);
      expect(before.liabilitiesMinor, liabNow + 100000);
    });

    test('stops before the first stored snapshot and never goes past the cap', () {
      final flows = [NwFlow(const CalDate(2024, 1, 1), -100, isCard: false), NwFlow(const CalDate(2026, 11, 1), -100, isCard: false)];
      final out = backfill(assetsNowMinor: assetsNow, liabilitiesNowMinor: liabNow, flows: flows, today: _today, firstSnapshot: const CalDate(2026, 11, 10), maxDays: 100);
      expect(out.last.date, const CalDate(2026, 11, 9));
      expect(out.first.date.compareTo(_today.addDays(-100)) >= 0, isTrue);
    });

    test('no flows, or none before the first snapshot, gives nothing', () {
      expect(backfill(assetsNowMinor: 1, liabilitiesNowMinor: 0, flows: const [], today: _today), isEmpty);
      expect(
        backfill(assetsNowMinor: 1, liabilitiesNowMinor: 0, flows: [NwFlow(const CalDate(2026, 11, 24), 5, isCard: false)], today: _today, firstSnapshot: const CalDate(2026, 11, 1)),
        isEmpty,
      );
    });
  });
}
