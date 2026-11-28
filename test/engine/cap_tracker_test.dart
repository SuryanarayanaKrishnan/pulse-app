import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/cap_tracker.dart';
import 'package:pulse/core/engine/catalog.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/rewards.dart';

CatalogCard bundled(String id) {
  final j = jsonDecode(
    File('assets/catalog/cards.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final cat = CardCatalog.fromJson(j);
  return cat.byId(id)!;
}

CardCapStatus statusOf(
  CatalogCard c,
  List<Spend> spends, {
  int? stmt,
  CalDate? today,
}) {
  final t = today ?? const CalDate(2026, 11, 20);
  final spec = c.spec;
  final (a, b, basis) = resolveCycle(spec, t, stmt);
  return cardCapStatus(
    cardId: c.id,
    title: '${c.issuer} ${c.name}',
    spec: spec,
    spends: spends,
    cycleStart: a,
    cycleEnd: b,
    basis: basis,
  );
}

void main() {
  final sib = bundled('sib-cashback');
  final tabby = bundled('tabby-card');

  group('one card', () {
    test('SIB: AED 300 cap is reached at AED 3,000 of online spend', () {
      final s = statusOf(sib, [
        const Spend(150000, 'shopping'),
        const Spend(100000, 'dining'),
      ]);
      final m = s.meters.single;
      expect(m.capAed, 300);
      expect(m.earnedAed, 250);
      expect(m.capSpendAed, closeTo(3000, 0.01));
      expect(m.remainingAed, 50);
      expect(m.remainingSpendAed, closeTo(500, 0.01));
      expect(m.level, CapLevel.near);
    });

    test('cap hit, spend past the cap earns nothing more', () {
      final s = statusOf(sib, [const Spend(400000, 'shopping')]);
      final m = s.meters.single;
      expect(m.earnedAed, 300);
      expect(m.level, CapLevel.hit);
      expect(m.remainingSpendAed, 0);
      expect(m.spentAed, 4000);
    });

    test('under 80% is ok', () {
      expect(
        statusOf(sib, [const Spend(100000, 'shopping')]).level,
        CapLevel.ok,
      );
    });

    test('per-rule caps are separate: Dubai First style rules', () {
      final spec = parseStructure({
        'unit': 'cashback',
        'point_value_aed': 1,
        'base_rate': 0.005,
        'rules': [
          {
            'name': 'Dining',
            'categories': ['dining'],
            'rate': 0.05,
            'monthly_cap_units': 150,
          },
          {
            'name': 'Groceries',
            'categories': ['groceries'],
            'rate': 0.05,
            'monthly_cap_units': 150,
          },
        ],
      });
      final s = cardCapStatus(
        cardId: 'x',
        title: 'X',
        spec: spec,
        spends: [
          const Spend(300000, 'dining'),
          const Spend(100000, 'groceries'),
        ],
        cycleStart: const CalDate(2026, 11, 1),
        cycleEnd: const CalDate(2026, 11, 30),
        basis: CycleBasis.calendar,
      );
      final byId = {for (final m in s.meters) m.id: m};
      expect(byId['Dining']!.level, CapLevel.hit);
      expect(byId['Groceries']!.earnedAed, 50);
      expect(s.worst!.id, 'Dining');
    });

    test('shared card-wide cap binds across rules', () {
      final spec = parseStructure({
        'unit': 'cashback',
        'point_value_aed': 1,
        'base_rate': 0,
        'monthly_total_cap_units': 100,
        'rules': [
          {
            'name': 'Dining',
            'categories': ['dining'],
            'rate': 0.1,
            'monthly_cap_units': 80,
          },
          {
            'name': 'Fuel',
            'categories': ['transport'],
            'rate': 0.1,
            'monthly_cap_units': 80,
          },
        ],
      });
      final s = cardCapStatus(
        cardId: 'x',
        title: 'X',
        spec: spec,
        spends: [const Spend(80000, 'dining'), const Spend(80000, 'transport')],
        cycleStart: const CalDate(2026, 11, 1),
        cycleEnd: const CalDate(2026, 11, 30),
        basis: CycleBasis.calendar,
      );
      expect(s.earnedAed, 100);
      final total = s.meters.firstWhere((m) => m.isTotal);
      expect(total.level, CapLevel.hit);
      expect(s.isExhausted, isTrue);
      expect(s.meters.firstWhere((m) => m.id == 'Fuel').earnedAed, 20);
    });

    test('points cards are converted to AED', () {
      final spec = parseStructure({
        'unit': 'points',
        'point_value_aed': 0.01,
        'base_rate': 1,
        'rules': [
          {
            'name': 'Travel',
            'categories': ['travel'],
            'rate': 10,
            'monthly_cap_units': 5000,
          },
        ],
      });
      final s = cardCapStatus(
        cardId: 'x',
        title: 'X',
        spec: spec,
        spends: [const Spend(30000, 'travel')],
        cycleStart: const CalDate(2026, 11, 1),
        cycleEnd: const CalDate(2026, 11, 30),
        basis: CycleBasis.calendar,
      );
      final m = s.meters.single;
      expect(m.capAed, 50);
      expect(m.earnedAed, 30);
      expect(m.capSpendAed, closeTo(500, 0.01));
    });
  });

  group('cycle', () {
    test('SIB is calendar even when a statement day is set', () {
      final s = statusOf(sib, const [], stmt: 17);
      expect(s.basis, CycleBasis.calendar);
      expect(s.cycleStart, const CalDate(2026, 11, 1));
    });

    test('statement day is used when the issuer is silent', () {
      final c = bundled('adib-cashback-covered');
      final s = statusOf(
        c,
        const [],
        stmt: 17,
        today: const CalDate(2026, 11, 20),
      );
      expect(s.basis, CycleBasis.statement);
      expect(s.cycleStart, const CalDate(2026, 11, 18));
      expect(s.cycleEnd, const CalDate(2026, 12, 17));
    });

    test('no statement day: calendar month, marked assumed', () {
      final c = bundled('adib-cashback-covered');
      expect(statusOf(c, const []).basis, CycleBasis.calendarAssumed);
    });

    test('ADIB cashback covered has its AED 1,000 overall cap', () {
      final c = bundled('adib-cashback-covered');
      final s = statusOf(c, [
        const Spend(900000, 'groceries'),
        const Spend(900000, 'transport'),
        const Spend(900000, 'education'),
        const Spend(700000, 'dining'),
      ]);
      expect(s.earnedAed, 1000);
      expect(s.isExhausted, isTrue);
    });
  });

  group('Tabby + SIB stack', () {
    CardCapStatus tabbyStatus(List<Spend> sp) => statusOf(tabby, sp);

    test('one AED 300 quota; Tabby adds none', () {
      final stack = stackCapStatus('Tabby+SIB', [
        tabbyStatus([const Spend(50000, 'shopping')]),
        statusOf(sib, [const Spend(350000, 'shopping')]),
      ]);
      expect(stack.quotaAed, 300);
      expect(stack.earnedAed, 300);
      expect(stack.level, CapLevel.hit);
      expect(stack.uncappedLegs, ['Tabby Tabby Card']);
      expect(stack.remainingSpendAed, 0);
    });

    test('at AED 2,500 spend the stack is near with AED 500 of spend left', () {
      final stack = stackCapStatus('Tabby+SIB', [
        tabbyStatus(const []),
        statusOf(sib, [const Spend(250000, 'shopping')]),
      ]);
      expect(stack.level, CapLevel.near);
      expect(stack.pct, closeTo(83.3, 0.1));
      expect(stack.remainingAed, 50);
      expect(stack.remainingSpendAed, closeTo(500, 0.01));
    });

    test('stack name from issuers', () {
      expect(stackLabel(['Tabby', 'SIB', 'SIB']), 'Tabby+SIB');
    });

    test('two capped legs add their quotas', () {
      final df = parseStructure({
        'unit': 'cashback',
        'point_value_aed': 1,
        'base_rate': 0,
        'rules': [
          {
            'name': 'Groc',
            'categories': ['groceries'],
            'rate': 0.05,
            'monthly_cap_units': 150,
          },
        ],
      });
      final a = cardCapStatus(
        cardId: 'df',
        title: 'DF',
        spec: df,
        spends: [const Spend(300000, 'groceries')],
        cycleStart: const CalDate(2026, 11, 1),
        cycleEnd: const CalDate(2026, 11, 30),
        basis: CycleBasis.calendar,
      );
      final stack = stackCapStatus('DF+SIB', [
        a,
        statusOf(sib, [const Spend(100000, 'shopping')]),
      ]);
      expect(stack.quotaAed, 450);
      expect(stack.earnedAed, 250);
      expect(stack.level, CapLevel.ok);
      expect(stack.remainingSpendAed, closeTo(2000, 0.01));
    });
  });

  group('alerts', () {
    test('hit message names the stack and the figures', () {
      final stack = stackCapStatus('Tabby+SIB', [
        statusOf(tabby, const []),
        statusOf(sib, [const Spend(400000, 'shopping')]),
      ]);
      final alerts = capAlerts([], stacks: [('tabby-sib', stack)]);
      expect(
        alerts.single.message,
        'Tabby+SIB cap reached: AED 300 of 300 this month',
      );
      expect(alerts.single.level, CapLevel.hit);
    });

    test('near and hit, keyed per cycle; muted cards are skipped; sent ones are not repeated', () {
      final near = statusOf(sib, [const Spend(250000, 'shopping')]);
      final a1 = capAlerts([near]);
      expect(a1.single.level, CapLevel.near);
      expect(capAlerts([near], muted: {near.cardId}), isEmpty);
      expect(unsentAlerts(a1, {a1.single.key}), isEmpty);
      final hit = statusOf(sib, [const Spend(400000, 'shopping')]);
      final a2 = capAlerts([hit]);
      expect(a2.single.key, isNot(a1.single.key));
      expect(unsentAlerts(a2, {a1.single.key}), hasLength(1));
      final nextMonth = statusOf(sib, [
        const Spend(400000, 'shopping'),
      ], today: const CalDate(2026, 12, 3));
      expect(capAlerts([nextMonth]).single.key, isNot(a2.single.key));
    });

    test('ok card raises nothing', () {
      expect(capAlerts([statusOf(sib, const [])]), isEmpty);
    });
  });
}
