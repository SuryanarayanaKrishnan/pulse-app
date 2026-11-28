import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/nw_history.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/data/recurring_providers.dart';
import 'package:pulse/features/auth/session.dart';

Future<void> open(
  WidgetTester tester, {
  List<NwPoint>? history,
  bool scroll = true,
}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(
          MockPulseRepository(latency: Duration.zero),
        ),
        analyticsProvider.overrideWithValue(NoopAnalytics()),
        kvStoreProvider.overrideWithValue(MemoryKvStore()),
        sessionProvider.overrideWith(
          (ref) => SessionController(
            onboarded: true,
            signedIn: true,
            connected: true,
          ),
        ),
        recurringTodayProvider.overrideWithValue(const CalDate(2026, 11, 24)),
        if (history != null)
          netWorthHistoryProvider.overrideWith((ref) async => history),
      ],
      child: const PulseApp(initialLocation: '/wealth'),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
  // The history sits under the grid of tiles.
  if (scroll) {
    await tester.scrollUntilVisible(
      find.byKey(const Key('nw_change')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }
}

String change(WidgetTester t) =>
    (t.widget(find.byKey(const Key('nw_change'))) as Text).data!;

void main() {
  testWidgets('range chips switch the window and the change over it', (
    tester,
  ) async {
    final today = const CalDate(2026, 11, 24);
    // Net worth climbs 100 AED a day for a year.
    final h = [
      for (var i = 364; i >= 0; i--)
        NwPoint(today.addDays(-i), (1000000 + (364 - i) * 10000), 0),
    ];
    await open(tester, history: h);
    expect(find.byKey(const Key('nw_ranges')), findsOneWidget);
    for (final l in ['1M', '3M', '6M', '1Y', 'All']) {
      expect(find.text(l), findsOneWidget);
    }
    // Default 6M.
    expect(change(tester), contains('over 6M'));
    final sixM = change(tester);
    await tester.tap(find.text('1M'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(change(tester), contains('over 1M'));
    expect(change(tester), isNot(sixM));
    expect(
      change(tester),
      contains('+AED 3,100'),
    ); // 31 days x AED 100, both ends of the window
    await tester.tap(find.text('All'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(change(tester), contains('over all time'));
    expect(change(tester), contains('+AED 36,400'));
    // The choice sticks while the app is open.
    expect(
      ProviderScope.containerOf(
        tester.element(find.byKey(const Key('nw_ranges'))),
      ).read(nwRangeProvider),
      NwRange.all,
    );
  });

  testWidgets('rebuilt days are flagged as estimates', (tester) async {
    const today = CalDate(2026, 11, 24);
    final h = [
      for (var i = 60; i >= 1; i--)
        NwPoint(today.addDays(-i), 500000, 0, estimated: true),
      const NwPoint(today, 520000, 0),
    ];
    await open(tester, history: h);
    expect(change(tester), contains('estimated from your payments'));
  });

  testWidgets(
    'a new install with one day of history falls back to the monthly line instead of an empty chart',
    (tester) async {
      await open(
        tester,
        history: [const NwPoint(CalDate(2026, 11, 24), 100000, 0)],
        scroll: false,
      );
      expect(find.byKey(const Key('nw_ranges')), findsNothing);
      expect(find.text('Net worth'), findsWidgets);
    },
  );

  testWidgets('assets and liabilities are shown stacked on one scale', (
    tester,
  ) async {
    await open(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('assets_vs_liabilities')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('assets_vs_liabilities')), findsOneWidget);
    final a = tester.getSize(find.byKey(const Key('bar_assets'))).width;
    final l = tester.getSize(find.byKey(const Key('bar_liabilities'))).width;
    expect(a, greaterThan(l));
    expect(l, greaterThan(0));
    expect(find.text('Assets and liabilities'), findsWidgets);
  });
}
