import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/spend_report.dart';
import 'package:pulse/core/engine/treemap.dart';
import 'package:pulse/core/engine/dates.dart';

void expectLayout(List<TreemapInput> items, double w, double h) {
  final tiles = layoutTreemap(items, w, h);
  final positive = items.where((i) => i.value > 0).toList();
  expect(tiles, hasLength(positive.length));
  final total = positive.fold(0.0, (a, i) => a + i.value);
  const eps = 1e-6;
  for (final t in tiles) {
    // Inside the box.
    expect(t.left, greaterThanOrEqualTo(-eps));
    expect(t.top, greaterThanOrEqualTo(-eps));
    expect(t.right, lessThanOrEqualTo(w + eps));
    expect(t.bottom, lessThanOrEqualTo(h + eps));
    // Area is proportional to the value.
    final v = positive.firstWhere((i) => i.id == t.id).value;
    expect(t.area, closeTo(v / total * w * h, 1e-6 * w * h), reason: t.id);
  }
  // No two tiles overlap.
  for (var i = 0; i < tiles.length; i++) {
    for (var j = i + 1; j < tiles.length; j++) {
      final a = tiles[i], b = tiles[j];
      final ow = math.min(a.right, b.right) - math.max(a.left, b.left);
      final oh = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
      expect(ow > eps && oh > eps, isFalse, reason: '${a.id} overlaps ${b.id}');
    }
  }
  // Together they fill the box.
  expect(tiles.fold(0.0, (a, t) => a + t.area), closeTo(w * h, 1e-6 * w * h));
}

void main() {
  test(
    'a typical spend split lays out with no overlaps and proportional areas',
    () {
      expectLayout(
        const [
          TreemapInput('rent', 6250),
          TreemapInput('groceries', 1900),
          TreemapInput('dining', 1200),
          TreemapInput('transport', 640),
          TreemapInput('shopping', 560),
          TreemapInput('health', 310),
          TreemapInput('fun', 140),
        ],
        358,
        280,
      );
    },
  );

  test('holds for many random shapes and boxes', () {
    final rnd = math.Random(7);
    for (var k = 0; k < 60; k++) {
      final n = 1 + rnd.nextInt(14);
      final items = [
        for (var i = 0; i < n; i++)
          TreemapInput('i$i', 1 + rnd.nextDouble() * 5000),
      ];
      expectLayout(
        items,
        120 + rnd.nextDouble() * 400,
        80 + rnd.nextDouble() * 500,
      );
    }
  });

  test(
    'one item fills the box; zeros and negatives are left out; empty is empty',
    () {
      final one = layoutTreemap(const [TreemapInput('a', 5)], 100, 50);
      expect(
        [one.single.left, one.single.top, one.single.width, one.single.height],
        [0, 0, 100, 50],
      );
      expect(
        layoutTreemap(
          const [
            TreemapInput('a', 5),
            TreemapInput('b', 0),
            TreemapInput('c', -3),
          ],
          100,
          50,
        ),
        hasLength(1),
      );
      expect(layoutTreemap(const [], 100, 50), isEmpty);
      expect(layoutTreemap(const [TreemapInput('a', 5)], 0, 50), isEmpty);
    },
  );

  test(
    'the biggest item gets the biggest tile and tiles stay reasonably square',
    () {
      final tiles = layoutTreemap(
        [for (var i = 1; i <= 8; i++) TreemapInput('i$i', i * 100.0)],
        350,
        280,
      );
      final big = tiles.reduce((a, b) => a.area >= b.area ? a : b);
      expect(big.id, 'i8');
      for (final t in tiles) {
        expect(
          math.max(t.width / t.height, t.height / t.width),
          lessThan(6),
          reason: t.id,
        );
      }
    },
  );

  group('spend report', () {
    final rows = [
      SpendRow(
        date: const CalDate(2026, 11, 2),
        amountMinor: 1000,
        categoryId: 'dining',
        owner: 'a',
      ),
      SpendRow(
        date: const CalDate(2026, 11, 9),
        amountMinor: 3000,
        categoryId: 'groceries',
        owner: 'b',
      ),
      SpendRow(
        date: const CalDate(2026, 11, 12),
        amountMinor: 500,
        categoryId: 'dining',
        owner: 'a',
      ),
      SpendRow(
        date: const CalDate(2026, 10, 30),
        amountMinor: 700,
        categoryId: 'dining',
        owner: 'a',
      ),
      SpendRow(
        date: const CalDate(2026, 11, 13),
        amountMinor: -400,
        categoryId: 'groceries',
        owner: 'b',
      ),
    ];

    test('by category, largest first, refunds netted, range respected', () {
      final s = spendByCategory(
        rows,
        ReportRange.month(const CalDate(2026, 11, 15)),
      );
      expect(
        [for (final x in s) (x.id, x.totalMinor, x.count)],
        [('groceries', 2600, 2), ('dining', 1500, 2)],
      );
      final three = spendByCategory(
        rows,
        ReportRange.lastMonths(const CalDate(2026, 11, 15), 3),
      );
      expect(three.firstWhere((x) => x.id == 'dining').totalMinor, 2200);
    });

    test('previous range is the same length right before', () {
      final r = ReportRange.month(const CalDate(2026, 11, 15));
      expect(r.previous.end, const CalDate(2026, 10, 31));
      expect(r.previous.start, const CalDate(2026, 10, 1));
    });

    test('small categories fold into other, totals unchanged', () {
      final slices = [
        const SpendSlice('a', 5000, 5),
        const SpendSlice('b', 3000, 3),
        const SpendSlice('c', 200, 1),
        const SpendSlice('d', 100, 1),
      ];
      final f = foldSmall(slices, minShare: 0.05);
      expect(f.map((s) => s.id), ['a', 'b', 'other']);
      expect(f.last.totalMinor, 300);
      expect(f.fold(0, (a, s) => a + s.totalMinor), 8300);
    });
  });
}
