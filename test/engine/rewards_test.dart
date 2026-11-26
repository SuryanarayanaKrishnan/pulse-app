import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/catalog.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/rewards.dart';

import 'fixtures.dart';

CardSpec spec([Map<String, Object?> over = const {}]) => parseStructure({
  'unit': 'cashback',
  'point_value_aed': 1,
  'base_rate': 0.01,
  'rules': [
    {'name': 'Dining', 'categories': ['dining'], 'rate': 0.05, 'monthly_cap_units': 100},
    {'name': 'Noon', 'merchants': ['noon'], 'rate': 0.10, 'monthly_cap_units': 50},
  ],
  'excluded_categories': ['fees'],
  ...over,
});

void main() {
  final catalog = CardCatalog.fromJson(
    jsonDecode(File('test/fixtures/catalog/cards_small.json').readAsStringSync()) as Map<String, Object?>,
  );

  group('catalog asset', () {
    test('has the 14 seeded cards, all parseable, honest about verification', () {
      expect(catalog.cards.length, 14);
      expect(catalog.version, greaterThanOrEqualTo(1));
      expect(catalog.cards.map((c) => c.id).toSet().length, 14);
      for (final c in catalog.cards) {
        expect(c.spec.rules, isNotEmpty, reason: c.id);
        expect(c.verified, isFalse, reason: 'seeded figures are unverified');
      }
      expect(catalog.notice, contains('verified_on'));
    });
    test('a malformed card is dropped, the rest stay', () {
      final c = CardCatalog.fromJson({
        'version': 2,
        'updated_on': '2027-01-01',
        'cards': [
          {'id': 'bad', 'issuer': 'x', 'name': 'y', 'reward_structure': {'unit': 'miles'}},
          {'id': 'ok', 'issuer': 'x', 'name': 'z', 'reward_structure': {'unit': 'cashback', 'base_rate': 0.01}},
        ],
      });
      expect(c.cards.map((e) => e.id), ['ok']);
      expect(c.version, 2);
    });
    test('round-trips through JSON', () {
      final again = CardCatalog.fromJson(jsonDecode(jsonEncode(catalog.toJson())) as Map<String, Object?>);
      expect(again.cards.length, catalog.cards.length);
      expect(again.cards.first.rewardStructure, catalog.cards.first.rewardStructure);
    });
  });

  group('Python parity on the 14 catalog cards', () {
    final fx = loadFixture('rewards.json')! as Map;
    for (final raw in fx['cards'] as List) {
      final c = Map<String, Object?>.from(raw as Map);
      test('${c['card']} / ${c['set']}', () {
        final card = catalog.byId(c['card']! as String)!;
        final s = card.spec;
        final spends = [
          for (final x in c['spends']! as List)
            Spend((x as List)[0] as int, x[1] as String?, x[2] as String?),
        ];
        final res = computeCycle(s, spends);
        expect(res.spendMinor, c['spend_minor']);
        expect(res.earnedUnits, closeTo(double.parse('${c['earned_units']}'), 1e-6));
        expect(res.earnedValueMinor(s), c['earned_value_minor']);
        expect(res.minSpendMet, c['min_spend_met']);
        final usage = Map<String, Object?>.from(c['usage']! as Map);
        expect(res.usage.keys.toSet(), usage.keys.toSet());
        for (final e in usage.entries) {
          final u = Map<String, Object?>.from(e.value! as Map);
          expect(res.usage[e.key]!.usedUnits, closeTo(double.parse('${u['used']}'), 1e-6));
          expect(res.usage[e.key]!.capUnits, u['cap'] == null ? isNull : closeTo(double.parse('${u['cap']}'), 1e-9));
        }
        for (final q in c['quotes']! as List) {
          final m = Map<String, Object?>.from(q as Map);
          final sp = m['spend']! as List;
          final got = quote(s, res, Spend(sp[0] as int, sp[1] as String?, sp[2] as String?));
          expect(got.units, closeTo(double.parse('${m['units']}'), 1e-6), reason: '$sp');
          expect(got.valueMinor, m['value_minor'], reason: '$sp');
          expect(got.rule, m['rule']);
          expect(got.capped, m['capped']);
          expect(got.headroomUnits, m['headroom'] == null ? isNull : closeTo(double.parse('${m['headroom']}'), 1e-6));
        }
      });
    }
    test('cycle bounds', () {
      for (final raw in fx['cycle_bounds'] as List) {
        final m = Map<String, Object?>.from(raw as Map);
        final (s, e) = cycleBounds(CalDate.parse(m['today']! as String), m['day'] as int?);
        expect(s.toIso(), m['start'], reason: '$m');
        expect(e.toIso(), m['end'], reason: '$m');
      }
    });
  });

  group('behaviour (backend test cases)', () {
    test('rule priority: merchant over category over base, exclusions earn nothing', () {
      final s = spec();
      expect(selectRule(s, 'dining', 'noon food')!.name, 'Noon');
      expect(selectRule(s, 'dining', 'carrefour')!.name, 'Dining');
      expect(selectRule(s, 'groceries', null)!.name, baseRuleName);
      expect(selectRule(s, 'fees', 'noon'), isNull);
    });
    test('cap binds chronologically and never goes negative', () {
      final res = computeCycle(spec(), [const Spend(1500000, 'dining'), const Spend(500000, 'dining')]);
      expect(res.earnedUnits, 100);
      expect(res.usage['Dining']!.remainingUnits, 0);
      expect(res.usage['Dining']!.pctUsed, 100);
    });
    test('min monthly spend zeroes the value until met', () {
      final s = spec({'min_monthly_spend_minor': 200000});
      final low = computeCycle(s, [const Spend(100000, 'dining')]);
      expect(low.minSpendMet, isFalse);
      expect(low.earnedValueMinor(s), 0);
      expect(low.earnedUnits, 50);
      final ok = computeCycle(s, [const Spend(250000, 'dining')]);
      expect(ok.earnedValueMinor(s), 10000);
    });
    test('quote respects headroom and is read-only', () {
      final s = spec();
      final state = computeCycle(s, [const Spend(180000, 'dining')]);
      final q = quote(s, state, const Spend(40000, 'dining'));
      expect((q.units, q.capped, q.headroomUnits, q.rule), (10.0, true, 10.0, 'Dining'));
      expect(state.earnedUnits, 90);
    });
    test('non-positive spend earns nothing', () {
      expect(computeCycle(spec(), [const Spend(0, 'dining'), const Spend(-500, 'dining')]).earnedUnits, 0);
    });
    test('garbage structures are rejected', () {
      for (final bad in <Map<String, Object?>>[
        {'unit': 'miles'},
        {'point_value_aed': 0},
        {'base_rate': -1},
        {'rules': [{'name': 'x', 'rate': 1}]},
      ]) {
        expect(() => parseStructure(bad), throwsFormatException);
      }
    });
  });

  group('ranking and nudges', () {
    RankableCard rc(String id, Map<String, Object?> over, List<Spend> spends, {int order = 0}) {
      final s = spec(over);
      return RankableCard(id: id, title: id, spec: s, state: computeCycle(s, spends), createdOrder: order);
    }

    test('best card by value, capped card drops, ties go to the older card', () {
      final a = rc('a', {}, [const Spend(2500000, 'dining')]); // dining cap used up
      final b = rc('b', {
        'base_rate': 0.02,
        'rules': [
          {'name': 'Dining', 'categories': ['dining'], 'rate': 0.03, 'monthly_cap_units': 100},
        ],
      }, [], order: 1);
      final ranked = rankCards([a, b], category: 'dining', amountMinor: 10000);
      expect(ranked.map((r) => r.card.id), ['b', 'a']);
      expect(ranked.first.quote.valueMinor, 300);
      final tie = rankCards([rc('y', {}, [], order: 2), rc('x', {}, [], order: 1)], category: 'groceries', amountMinor: 10000);
      expect(tie.map((r) => r.card.id), ['x', 'y']);
    });

    test('nudge when the cap is reached and another card earns more', () {
      final a = rc('a', {}, [const Spend(2500000, 'dining')]);
      final b = rc('b', {'base_rate': 0.02, 'rules': [
        {'name': 'Dining', 'categories': ['dining'], 'rate': 0.03, 'monthly_cap_units': 100},
      ]}, []);
      final n = nudgeFor(card: a, all: [a, b], cycleEnd: const CalDate(2026, 3, 31), category: 'dining')!;
      expect(n.level, 'capped');
      expect(n.suggestedCardId, 'b');
      expect(n.extraValueMinor, 300); // a capped rule earns nothing more (as in the backend)
      expect(n.message, contains('Use b for dining until 2026-03-31'));
    });
    test('no nudge below 80 percent, a plain note when nothing is better', () {
      final low = rc('a', {}, [const Spend(100000, 'dining')]); // 50 of 100
      expect(nudgeFor(card: low, all: [low], cycleEnd: const CalDate(2026, 3, 31), category: 'dining'), isNull);
      final near = rc('a', {}, [const Spend(180000, 'dining')]);
      final n = nudgeFor(card: near, all: [near], cycleEnd: const CalDate(2026, 3, 31), category: 'dining')!;
      expect(n.level, 'near_cap');
      expect(n.suggestedCardId, isNull);
      expect(n.message, contains('no other card of yours earns more'));
    });
    test('fee waiver progress', () {
      const w = FeeWaiver(120000, 12000000, 6000000);
      expect(w.progressPct, 50);
      expect(w.waived, isFalse);
    });
  });
}
