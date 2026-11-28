import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/sankey.dart';

List<FlowItem> items(Map<String, int> m) => [
  for (final e in m.entries) FlowItem(e.key, e.key, e.value),
];

void expectSound(SankeyLayout l, {double min = 6, double gap = 8}) {
  for (final col in [0, 1]) {
    final ns = l.nodes.where((n) => n.column == col).toList()
      ..sort((a, b) => a.y.compareTo(b.y));
    for (var i = 0; i < ns.length; i++) {
      expect(ns[i].y, greaterThanOrEqualTo(-1e-9), reason: ns[i].id);
      expect(
        ns[i].bottom,
        lessThanOrEqualTo(l.height + 1e-9),
        reason: ns[i].id,
      );
      expect(ns[i].height, greaterThanOrEqualTo(min - 1e-9), reason: ns[i].id);
      if (i > 0)
        expect(
          ns[i].y,
          greaterThanOrEqualTo(ns[i - 1].bottom + gap - 1e-9),
          reason: 'overlap ${ns[i - 1].id}/${ns[i].id}',
        );
    }
  }
  for (final n in l.nodes) {
    final out = l.links.where((k) => k.sourceId == n.id),
        inn = l.links.where((k) => k.targetId == n.id);
    final links = n.column == 0 ? out : inn;
    expect(
      links.fold(0, (a, k) => a + k.valueMinor),
      n.valueMinor,
      reason: 'exact ${n.id}',
    );
    final thick = links.fold(
      0.0,
      (a, k) => a + (n.column == 0 ? k.sourceHeight : k.targetHeight),
    );
    expect(thick, closeTo(n.height, 1e-6), reason: 'thickness ${n.id}');
  }
  final left = l.nodes
      .where((n) => n.column == 0)
      .fold(0, (a, n) => a + n.valueMinor);
  final right = l.nodes
      .where((n) => n.column == 1)
      .fold(0, (a, n) => a + n.valueMinor);
  expect(left, right);
}

void main() {
  test('income splits into categories and what is left is Saved', () {
    final l = sankeyLayout(
      incomes: items({'salary': 2000000, 'side': 300000}),
      spends: items({'rent': 900000, 'groceries': 450000, 'dining': 200000}),
      width: 340,
      height: 360,
    );
    expectSound(l);
    expect(l.node(sankeySavedId).valueMinor, 2300000 - 1550000);
    expect(l.nodes.where((n) => n.kind == SankeyKind.deficit), isEmpty);
    expect(l.totalMinor, 2300000);
  });

  test('spending above income shows a From savings source', () {
    final l = sankeyLayout(
      incomes: items({'salary': 100000}),
      spends: items({'rent': 150000}),
      width: 300,
      height: 300,
    );
    expectSound(l);
    expect(l.node(sankeyDeficitId).valueMinor, 50000);
    expect(l.nodes.where((n) => n.kind == SankeyKind.saved), isEmpty);
  });

  test('exact balance has neither Saved nor a deficit', () {
    final l = sankeyLayout(
      incomes: items({'a': 500}),
      spends: items({'b': 500}),
      width: 300,
      height: 300,
    );
    expectSound(l);
    expect(l.nodes.length, 2);
  });

  test('many small categories fold into Other with exact totals and never go under the minimum height', () {
    final spends = {for (var i = 0; i < 20; i++) 'c$i': 1000 + i * 37};
    final l = sankeyLayout(
      incomes: items({'salary': 1000000}),
      spends: items(spends),
      width: 340,
      height: 300,
    );
    expectSound(l);
    final right = l.nodes.where((n) => n.column == 1).toList();
    expect(right.length, lessThanOrEqualTo(7 + 1));
    final other = right.firstWhere((n) => n.kind == SankeyKind.other);
    expect(other.members.length, 20 - 6);
    expect(
      right
          .where((n) => n.kind != SankeyKind.saved)
          .fold(0, (a, n) => a + n.valueMinor),
      spends.values.fold(0, (a, b) => a + b),
    );
  });

  test('a tiny flow next to a huge one stays visible and nothing overlaps', () {
    final l = sankeyLayout(
      incomes: items({'salary': 100000000}),
      spends: items({'rent': 99999000, 'coffee': 5, 'tip': 1}),
      width: 300,
      height: 200,
    );
    expectSound(l);
    expect(l.node('coffee').height, greaterThanOrEqualTo(6));
  });

  test('odd minor units stay exact across several sources and sinks', () {
    final l = sankeyLayout(
      incomes: items({'a': 333333, 'b': 333334, 'c': 1}),
      spends: items({'x': 100001, 'y': 99999, 'z': 400000, 'w': 66667}),
      width: 320,
      height: 280,
    );
    expectSound(l);
    expect(l.links.fold(0, (a, k) => a + k.valueMinor), 666668);
  });

  test('ribbons do not cross', () {
    final l = sankeyLayout(
      incomes: items({'a': 700, 'b': 300, 'c': 100}),
      spends: items({'x': 500, 'y': 300, 'z': 200, 'w': 50}),
      width: 300,
      height: 300,
    );
    for (var i = 1; i < l.links.length; i++) {
      final a = l.links[i - 1], b = l.links[i];
      expect(
        b.sourceY >= a.sourceY - 1e-9 && b.targetY >= a.targetY - 1e-9,
        isTrue,
      );
    }
  });

  test('empty and zero input give an empty layout; zero items are dropped', () {
    expect(
      sankeyLayout(
        incomes: const [],
        spends: const [],
        width: 300,
        height: 300,
      ).isEmpty,
      isTrue,
    );
    expect(
      sankeyLayout(
        incomes: items({'a': 0}),
        spends: items({'b': 0}),
        width: 300,
        height: 300,
      ).isEmpty,
      isTrue,
    );
    final l = sankeyLayout(
      incomes: const [],
      spends: items({'b': 100}),
      width: 300,
      height: 300,
    );
    expectSound(l);
    expect(l.nodes.length, 2);
  });

  test('layout is deterministic and ties order by label', () {
    List<String> ids() => sankeyLayout(
      incomes: items({'a': 20}),
      spends: items({'q': 5, 'p': 5}),
      width: 300,
      height: 300,
    ).nodes.map((n) => n.id).toList();
    expect(ids(), ids());
    expect(ids(), ['a', 'p', 'q', sankeySavedId]);
  });

  test('left and right Other nodes keep distinct ids', () {
    final l = sankeyLayout(
      incomes: items({for (var i = 0; i < 10; i++) 'i$i': 100 + i}),
      spends: items({for (var i = 0; i < 10; i++) 'c$i': 100 + i}),
      width: 300,
      height: 400,
      maxPerColumn: 4,
    );
    expectSound(l);
    expect(l.nodes.map((n) => n.id).toSet().length, l.nodes.length);
  });
}
