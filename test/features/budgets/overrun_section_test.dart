import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/engine/budget_overrun.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/budget_plan_service.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/overrun_providers.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/budgets/overrun_section.dart';

class _Rec implements Analytics {
  final events = <AnalyticsEvent>[];
  @override
  void track(AnalyticsEvent e) => events.add(e);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Repo extends MockPulseRepository {
  _Repo() : super(latency: Duration.zero);
  final budgets = <(String, double)>[];
  @override
  Future<void> setBudget(SpendCategory category, double monthly) async =>
      budgets.add((category.id, monthly));
}

const _cur = '2026-11-01';

CategoryOverrun _o(
  String id,
  OverrunKind kind,
  OverrunReason reason, {
  int planned = 50000,
  int spent = 63000,
  int? ceiling,
  List<Contributor> who = const [],
}) => CategoryOverrun(
  categoryId: id,
  kind: kind,
  reason: reason,
  month: _cur,
  plannedMinor: planned,
  spentMinor: spent,
  monthsCompared: 5,
  monthsOver: kind == OverrunKind.pattern ? 4 : 1,
  contributors: who,
  typicalOverMinor: kind == OverrunKind.pattern ? 15000 : null,
  suggestedCeilingMinor: ceiling,
);

OverrunReport _report() => OverrunReport([
  OverrunItem(
    _o(
      'dining',
      OverrunKind.pattern,
      OverrunReason.repeatedMonths,
      ceiling: 65000,
      who: const [
        Contributor('Cafe A', 30000, 3),
        Contributor('Cafe B', 20000, 2),
      ],
    ),
    SpendCategory.dining,
    fundingHint(
      extraMinor: 15000,
      slack: const [Slack('groceries', 60000)],
      exceptId: 'dining',
    ),
  ),
  OverrunItem(
    _o(
      'shopping',
      OverrunKind.oneOff,
      OverrunReason.singleMonth,
      planned: 40000,
      spent: 52000,
    ),
    SpendCategory.shopping,
    null,
  ),
]);

Future<(_Repo, _Rec, ProviderContainer)> _pump(
  WidgetTester t, {
  OverrunReport? report,
  Brightness b = Brightness.light,
  double scale = 1,
  Widget child = const OverrunSection(),
}) async {
  PulseTheme.useGoogleFonts = false;
  t.view.physicalSize = const Size(360 * 3, 900 * 3);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  final repo = _Repo();
  final rec = _Rec();
  final container = ProviderContainer(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      analyticsProvider.overrideWithValue(rec),
      overrunKvProvider.overrideWithValue(MemoryKvStore()),
      overrunReportProvider.overrideWith((ref) async => report ?? _report()),
    ],
  );
  addTearDown(container.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: b == Brightness.dark ? PulseTheme.dark : PulseTheme.light,
        builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: w!,
        ),
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) =>
                  Scaffold(body: SingleChildScrollView(child: child)),
            ),
            GoRoute(
              path: '/budget',
              builder: (_, _) => const Scaffold(body: Text('budget page')),
            ),
          ],
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return (repo, rec, container);
}

void main() {
  for (final b in Brightness.values) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'lists where you went over, labelled, at 360px ${b.name} x$scale',
        (t) async {
          await _pump(t, b: b, scale: scale);
          expect(find.text('Over budget'), findsOneWidget);
          expect(
            find.text('Dining & Delivery is AED 130 over'),
            findsOneWidget,
          );
          expect(find.text('Recurring'), findsOneWidget);
          expect(find.text('One-off'), findsOneWidget);
          expect(
            find.textContaining('Over in 4 of the last 6 months'),
            findsOneWidget,
          );
          expect(find.text('Mostly Cafe A and Cafe B.'), findsOneWidget);
          expect(find.text('Raise to AED 650'), findsOneWidget);
          expect(
            find.byKey(const Key('overrun_funding_dining')),
            findsOneWidget,
          );
          expect(
            find.textContaining('Groceries (AED 600 unused)'),
            findsOneWidget,
          );
          expect(find.byKey(const Key('overrun_caveat')), findsOneWidget);
          expect(find.textContaining('Estimates'), findsOneWidget);
          // A one-off has no raise button.
          expect(find.byKey(const Key('overrun_raise_shopping')), findsNothing);
          expect(t.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('Raise changes the budget on one tap and Undo puts it back', (
    t,
  ) async {
    final (repo, rec, _) = await _pump(t);
    await t.tap(find.byKey(const Key('overrun_raise_dining')));
    await t.pump();
    expect(repo.budgets, [('dining', 650.0)]);
    expect(rec.events.map((e) => e.name), contains('overrun_ceiling_raised'));
    expect(find.textContaining('budget is now AED 650'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.text('Undo'));
    await t.pump();
    expect(repo.budgets.last, ('dining', 500.0));
    expect(rec.events.map((e) => e.name), contains('overrun_raise_undone'));
  });

  testWidgets('nothing changes until the tap', (t) async {
    final (repo, _, _) = await _pump(t);
    expect(repo.budgets, isEmpty);
  });

  testWidgets(
    'Mark as one-off records the month and leaves the budget alone, with Undo',
    (t) async {
      final (repo, rec, c) = await _pump(t);
      await t.tap(find.byKey(const Key('overrun_oneoff_shopping')));
      await t.pump();
      expect(c.read(overrunMarksProvider)['shopping'], {_cur});
      expect(repo.budgets, isEmpty);
      expect(
        find.textContaining('Your Shopping budget is unchanged'),
        findsOneWidget,
      );
      expect(rec.events.map((e) => e.name), contains('overrun_marked_one_off'));
      await t.pump(const Duration(milliseconds: 500));
      await t.tap(find.text('Undo'));
      await t.pump();
      expect(c.read(overrunMarksProvider)['shopping'], isEmpty);
    },
  );

  test('marks survive a restart', () async {
    final kv = MemoryKvStore();
    final c1 = ProviderContainer(
      overrides: [overrunKvProvider.overrideWithValue(kv)],
    );
    addTearDown(c1.dispose);
    c1.read(overrunMarksProvider);
    await c1.read(overrunMarksProvider.notifier).mark('dining', _cur);
    final c2 = ProviderContainer(
      overrides: [overrunKvProvider.overrideWithValue(kv)],
    );
    addTearDown(c2.dispose);
    c2.read(overrunMarksProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c2.read(overrunMarksProvider)['dining'], {_cur});
  });

  testWidgets('the view is reported once per kind, with no amounts or names', (
    t,
  ) async {
    final (_, rec, _) = await _pump(t);
    final viewed = rec.events.where((e) => e.name == 'overrun_viewed').toList();
    expect(viewed.map((e) => e.properties['kind']).toSet(), {
      'pattern',
      'one_off',
    });
    expect(viewed, hasLength(2));
    for (final e in viewed) {
      expect(e.properties.keys.toSet(), {'kind', 'surface'});
    }
  });

  testWidgets('short history reads honestly and offers no raise', (t) async {
    await _pump(
      t,
      report: OverrunReport([
        OverrunItem(
          _o('dining', OverrunKind.tooEarly, OverrunReason.shortHistory),
          SpendCategory.dining,
          null,
        ),
      ]),
    );
    expect(find.text('Too early'), findsOneWidget);
    expect(find.textContaining('too early to tell'), findsOneWidget);
    expect(find.byKey(const Key('overrun_raise_dining')), findsNothing);
    expect(find.byKey(const Key('overrun_oneoff_dining')), findsOneWidget);
  });

  testWidgets('shows three and lets you expand the rest', (t) async {
    final items = [
      for (final (i, c) in [
        SpendCategory.dining,
        SpendCategory.shopping,
        SpendCategory.groceries,
        SpendCategory.travel,
      ].indexed)
        OverrunItem(
          _o(
            c.id,
            OverrunKind.oneOff,
            OverrunReason.singleMonth,
            spent: 90000 - i * 1000,
          ),
          c,
          null,
        ),
    ];
    await _pump(t, report: OverrunReport(items));
    expect(find.byKey(const Key('overrun_travel')), findsNothing);
    await t.tap(find.byKey(const Key('overrun_more')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('overrun_travel')), findsOneWidget);
  });

  testWidgets('nothing over: the section is absent', (t) async {
    await _pump(t, report: OverrunReport.empty);
    expect(find.text('Over budget'), findsNothing);
  });

  group('home line', () {
    testWidgets('one calm line that opens the budget', (t) async {
      await _pump(
        t,
        child: const OverrunHomeLine(),
        report: OverrunReport([_report().items.first]),
      );
      expect(find.text('Dining & Delivery is over budget'), findsOneWidget);
      expect(find.text('Keeps happening. See why'), findsOneWidget);
      await t.tap(find.byKey(const Key('overrun_home_line')));
      await t.pumpAndSettle();
      expect(find.text('budget page'), findsOneWidget);
    });

    testWidgets('several categories fold into one line, 1.5x dark at 360px', (
      t,
    ) async {
      await _pump(
        t,
        child: const OverrunHomeLine(),
        b: Brightness.dark,
        scale: 1.5,
      );
      expect(find.text('2 categories are over budget'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('absent when nothing is over', (t) async {
      await _pump(
        t,
        child: const OverrunHomeLine(),
        report: OverrunReport.empty,
      );
      expect(find.byKey(const Key('overrun_home_line')), findsNothing);
    });
  });
}
