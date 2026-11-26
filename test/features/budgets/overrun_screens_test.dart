import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/engine/budget_overrun.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/budget_plan_service.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/overrun_providers.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/features/coach/coach_progress.dart';
import 'package:pulse/features/tour/tour_progress.dart';

OverrunReport _report() => OverrunReport([
  OverrunItem(
    const CategoryOverrun(
      categoryId: 'dining',
      kind: OverrunKind.oneOff,
      reason: OverrunReason.singleMonth,
      month: '2026-11-01',
      plannedMinor: 50000,
      spentMinor: 63000,
      monthsCompared: 5,
      monthsOver: 1,
      contributors: [],
    ),
    SpendCategory.dining,
    null,
  ),
]);

Future<void> _pump(WidgetTester t, String route, OverrunReport report) async {
  PulseTheme.useGoogleFonts = false;
  t.view.physicalSize = const Size(360 * 3, 800 * 3);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  final kv = MemoryKvStore()..data['tour.seen'] = '1';
  for (final s in CoachScreen.values) {
    kv.data['coach.seen.${s.key}'] = '1';
  }
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        tourKvProvider.overrideWithValue(kv),
        repositoryProvider.overrideWithValue(
          MockPulseRepository(latency: Duration.zero),
        ),
        analyticsProvider.overrideWithValue(NoopAnalytics()),
        overrunKvProvider.overrideWithValue(MemoryKvStore()),
        overrunReportProvider.overrideWith((ref) async => report),
        sessionProvider.overrideWith(
          (ref) => SessionController(
            onboarded: true,
            signedIn: true,
            connected: true,
          ),
        ),
      ],
      child: PulseApp(initialLocation: route),
    ),
  );
  for (var i = 0; i < 25; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  testWidgets('Budget shows the over-budget section when something is over', (
    t,
  ) async {
    await _pump(t, '/budget', _report());
    await t.scrollUntilVisible(
      find.byKey(const Key('overrun_section')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Dining & Delivery is AED 130 over'), findsOneWidget);
    expect(find.text('One-off'), findsOneWidget);
  });

  testWidgets('Budget has no over-budget section when nothing is over', (
    t,
  ) async {
    await _pump(t, '/budget', OverrunReport.empty);
    expect(find.byKey(const Key('overrun_section')), findsNothing);
  });

  testWidgets('Home shows one calm line and it opens the budget', (t) async {
    await _pump(t, '/home', _report());
    await t.scrollUntilVisible(
      find.byKey(const Key('overrun_home_line')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Dining & Delivery is over budget'), findsOneWidget);
    await t.tap(find.byKey(const Key('overrun_home_line')));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('Budget'), findsWidgets);
  });

  testWidgets('Home has no line when nothing is over', (t) async {
    await _pump(t, '/home', OverrunReport.empty);
    expect(find.byKey(const Key('overrun_home_line')), findsNothing);
  });
}
