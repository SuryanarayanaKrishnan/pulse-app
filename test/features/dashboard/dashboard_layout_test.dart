import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/analytics/event_schema.dart';
import 'package:pulse/features/home/dashboard/dashboard_layout.dart';

List<DashKind> kinds(Dashboard d) => [for (final w in d.widgets) w.kind];

void main() {
  const a = DashKind.netWorth, b = DashKind.cashFlow, c = DashKind.savingsRate;
  Dashboard three() => const Dashboard(
    id: 'x',
    name: 'X',
  ).add(a).add(b).add(c, WidgetSize.compact);

  group('widgets', () {
    test('add appends, defaults to regular, ignores duplicates', () {
      final d = const Dashboard(
        id: 'x',
        name: 'X',
      ).add(a).add(a, WidgetSize.compact);
      expect(d.widgets, [const DashWidget(a)]);
    });

    test('remove drops only that kind', () {
      expect(kinds(three().remove(b)), [a, c]);
      expect(kinds(three().remove(DashKind.safeToSpend)), [a, b, c]);
    });

    test('available lists what is not on the dashboard', () {
      final d = three();
      expect(d.available.length, DashKind.values.length - 3);
      expect(d.available, isNot(contains(a)));
    });

    test('reorder moves to the reported index (onReorderItem semantics)', () {
      expect(kinds(three().reorder(0, 2)), [b, c, a]);
      expect(kinds(three().reorder(2, 0)), [c, a, b]);
      expect(kinds(three().reorder(1, 1)), [a, b, c]);
    });

    test('reorder clamps and ignores bad indexes', () {
      expect(kinds(three().reorder(0, 99)), [b, c, a]);
      expect(kinds(three().reorder(7, 0)), [a, b, c]);
      expect(kinds(three().reorder(-1, 0)), [a, b, c]);
    });

    test('resize changes only that widget', () {
      final d = three().resize(a, WidgetSize.compact);
      expect(d.widgets.map((w) => w.size), [
        WidgetSize.compact,
        WidgetSize.regular,
        WidgetSize.compact,
      ]);
      expect(
        three().resize(DashKind.safeToSpend, WidgetSize.compact).widgets,
        three().widgets,
      );
    });
  });

  group('dashboards', () {
    test('defaults: Everyday and Month end, Everyday active', () {
      final l = DashboardLayout.defaults();
      expect(l.dashboards.map((d) => d.name), ['Everyday', 'Month end']);
      expect(l.active.name, 'Everyday');
      for (final d in l.dashboards) {
        expect(kinds(d).toSet().length, d.widgets.length);
      }
    });

    test('edits apply to the active dashboard only', () {
      var l = DashboardLayout.defaults();
      final month = l.dashboards[1];
      l = l.removeWidget(DashKind.recentCaptures).select('month_end');
      expect(l.dashboards[1], month);
      expect(l.dashboards[0].has(DashKind.recentCaptures), isFalse);
      l = l.addWidget(DashKind.recentCaptures);
      expect(l.dashboards[1].has(DashKind.recentCaptures), isTrue);
    });

    test('select ignores an unknown id', () {
      final l = DashboardLayout.defaults();
      expect(l.select('nope'), l);
    });

    test('add makes the new dashboard active, names are tidied', () {
      final l = DashboardLayout.defaults().addDashboard(
        '  Trip   to   Rome and back again ok ',
        id: 't',
      );
      expect(l.activeId, 't');
      expect(l.active.widgets, isEmpty);
      expect(
        l.active.name.length,
        lessThanOrEqualTo(DashboardLayout.maxNameLength),
      );
      expect(l.active.name, startsWith('Trip to Rome'));
    });

    test('a clashing id is made unique; the count is capped', () {
      var l = DashboardLayout.defaults();
      l = l.addDashboard('A', id: 'everyday');
      expect(l.dashboards.map((d) => d.id).toSet().length, 3);
      l = l
          .addDashboard('B', id: 'b')
          .addDashboard('C', id: 'c')
          .addDashboard('D', id: 'd');
      expect(l.dashboards.length, DashboardLayout.maxDashboards);
      expect(l.canAddDashboard, isFalse);
    });

    test('rename and blank names', () {
      var l = DashboardLayout.defaults().renameActive('Daily');
      expect(l.active.name, 'Daily');
      l = l.renameActive('   ');
      expect(l.active.name, 'Dashboard');
    });

    test('delete moves to a neighbour and never removes the last', () {
      var l = DashboardLayout.defaults().select('month_end').deleteActive();
      expect(l.dashboards.length, 1);
      expect(l.activeId, 'everyday');
      expect(l.deleteActive(), l);
      expect(l.canDeleteDashboard, isFalse);
    });
  });

  group('serialise and migrate', () {
    test('round trips', () {
      final l = DashboardLayout.defaults()
          .resizeWidget(DashKind.upcoming, WidgetSize.compact)
          .reorderWidget(0, 3)
          .select('month_end');
      final back = DashboardLayout.decode(l.encode());
      expect(back, l);
      expect(back.activeId, 'month_end');
      expect(jsonDecode(l.encode())['v'], DashboardLayout.schemaVersion);
    });

    test('null, empty and garbage fall back to defaults', () {
      final d = DashboardLayout.defaults();
      for (final raw in [
        null,
        '',
        'not json',
        '[]',
        '"x"',
        '{"v":2}',
        '{"v":2,"dashboards":[]}',
      ]) {
        expect(DashboardLayout.decode(raw), d, reason: '$raw');
      }
    });

    test('a layout from a newer app is not guessed at', () {
      final raw = jsonEncode({
        'v': 99,
        'dashboards': [
          {'id': 'z', 'name': 'Z', 'widgets': []},
        ],
      });
      expect(DashboardLayout.decode(raw), DashboardLayout.defaults());
    });

    test('v1 (one flat list of kinds) becomes a single Everyday dashboard', () {
      final raw = jsonEncode({
        'widgets': ['net_worth', 'gone_kind', 'cash_flow', 'net_worth', 7],
      });
      final l = DashboardLayout.decode(raw);
      expect(l.dashboards.length, 1);
      expect(l.active.name, 'Everyday');
      expect(kinds(l.active), [DashKind.netWorth, DashKind.cashFlow]);
      expect(
        l.active.widgets.every((w) => w.size == WidgetSize.regular),
        isTrue,
      );
      // And it re-saves in the current shape.
      expect(jsonDecode(l.encode())['v'], DashboardLayout.schemaVersion);
    });

    test('v2 drops unknown kinds, duplicates and malformed entries', () {
      final raw = jsonEncode({
        'v': 2,
        'active': 'missing',
        'dashboards': [
          {
            'id': 'a',
            'name': 'A',
            'widgets': [
              {'kind': 'net_worth', 'size': 'compact'},
              {'kind': 'net_worth', 'size': 'regular'},
              {'kind': 'hologram'},
              'junk',
              {'kind': 'cash_flow', 'size': 'huge'},
            ],
          },
          {'id': 'a', 'name': 'Duplicate id'},
          'junk',
          {'id': '', 'name': 'No id'},
        ],
      });
      final l = DashboardLayout.decode(raw);
      expect(l.dashboards.length, 1);
      expect(l.activeId, 'a');
      expect(l.active.widgets, [
        const DashWidget(DashKind.netWorth, WidgetSize.compact),
        const DashWidget(DashKind.cashFlow),
      ]);
    });

    test('an empty dashboard is kept (the user cleared it on purpose)', () {
      final l = DashboardLayout.defaults().addDashboard('Blank', id: 'blank');
      expect(DashboardLayout.decode(l.encode()).active.widgets, isEmpty);
    });
  });

  test(
    'kind keys match the analytics allow-list and are short fixed choices',
    () {
      expect(DashKind.keys, AnalyticsSchema.dashboardWidgetKinds);
      expect(DashKind.keys.toSet().length, DashKind.values.length);
      for (final k in DashKind.keys) {
        expect(k.length, lessThan(24));
      }
    },
  );

  group('calm default', () {
    test(
      'a new install shows only safe to spend, everything else is opt-in',
      () {
        final l = DashboardLayout.defaults();
        expect(l.active.widgets.map((w) => w.kind), [DashKind.safeToSpend]);
        expect(l.active.available, contains(DashKind.review));
        expect(l.active.available, contains(DashKind.health));
      },
    );

    test('legacy extras keep an older Home looking the same, once', () {
      final once = DashboardLayout.defaults().withLegacyExtras();
      final kinds = once.active.widgets.map((w) => w.kind).toList();
      expect(kinds.first, DashKind.safeToSpend);
      expect(kinds, containsAll([DashKind.review, DashKind.health]));
      expect(once.withLegacyExtras(), once, reason: 'idempotent');
    });
  });
}
