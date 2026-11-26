import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart' show AccessibilityFeatures;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/features/budgets/budget_chart_pager.dart';
import 'package:pulse/features/coach/coach_progress.dart';
import 'package:pulse/features/tour/tour_progress.dart';

MemoryKvStore _kv([Map<String, String> extra = const {}]) {
  final kv = MemoryKvStore()..data['tour.seen'] = '1';
  for (final s in CoachScreen.values) {
    kv.data['coach.seen.${s.key}'] = '1';
  }
  kv.data.addAll(extra);
  return kv;
}

Future<void> _pump(
  WidgetTester tester, {
  MemoryKvStore? kv,
  Size size = const Size(390, 844),
  double dpr = 3,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  }
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tourKvProvider.overrideWithValue(kv ?? _kv()),
        repositoryProvider.overrideWithValue(
          MockPulseRepository(latency: Duration.zero),
        ),
        analyticsProvider.overrideWithValue(NoopAnalytics()),
        sessionProvider.overrideWith(
          (ref) => SessionController(
            onboarded: true,
            signedIn: true,
            connected: true,
          ),
        ),
      ],
      child: const PulseApp(initialLocation: '/budget'),
    ),
  );
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

class FakeAccessibilityFeatures implements AccessibilityFeatures {
  const FakeAccessibilityFeatures({this.disableAnimations = false});
  @override
  final bool disableAnimations;
  @override
  bool get accessibleNavigation => false;
  @override
  bool get boldText => false;
  @override
  bool get highContrast => false;
  @override
  bool get invertColors => false;
  @override
  bool get onOffSwitchLabels => false;
  @override
  bool get reduceMotion => disableAnimations;
  @override
  dynamic noSuchMethod(Invocation i) => false;
}

Future<void> _pumpMs(WidgetTester tester, [int ms = 600]) async {
  for (var t = 0; t < ms + 200; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String _title(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('chart_title'))).data!;

void main() {
  testWidgets('key numbers sit above one compact chart card with dots', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(const Key('budget_key_numbers')), findsOneWidget);
    expect(find.byKey(const Key('chart_pager')), findsOneWidget);
    final numbers = tester.getTopLeft(
      find.byKey(const Key('budget_key_numbers')),
    );
    final pager = tester.getTopLeft(find.byKey(const Key('chart_pager')));
    expect(numbers.dy, lessThan(pager.dy));
    expect(_title(tester), 'Spend by category');
    expect(find.byKey(const Key('category_donut')), findsOneWidget);
    for (final c in BudgetChart.values) {
      expect(find.byKey(Key('chart-dot-${c.key}')), findsOneWidget);
    }
    // The long sections are no longer stacked down the page.
    expect(find.byKey(const Key('sankey_section')), findsNothing);
  });

  testWidgets('swiping moves between charts and the last page is remembered', (
    tester,
  ) async {
    final kv = _kv();
    await _pump(tester, kv: kv);
    await tester.fling(
      find.byKey(const Key('chart_pages')),
      const Offset(-300, 0),
      1000,
    );
    await _pumpMs(tester);
    expect(_title(tester), 'Month trend');
    expect(kv.data[budgetChartPageKey], 'trend');
    final dot = find.byKey(const Key('chart-dot-flow'));
    await Scrollable.ensureVisible(tester.element(dot), alignment: 0.4);
    await _pumpMs(tester);
    await tester.tap(dot);
    await _pumpMs(tester, 900);
    expect(_title(tester), 'Where the money flows');
    expect(find.byKey(const Key('sankey_section')), findsOneWidget);
    expect(kv.data[budgetChartPageKey], 'flow');
  });

  testWidgets('reopens on the chart that was open last', (tester) async {
    await _pump(tester, kv: _kv({budgetChartPageKey: 'forecast'}));
    expect(_title(tester), 'Cash-flow forecast');
    expect(find.textContaining('Projected on'), findsOneWidget);
  });

  testWidgets('flex vs fixed shows the three groups', (tester) async {
    await _pump(tester, kv: _kv({budgetChartPageKey: 'flex'}));
    expect(_title(tester), 'Flex vs fixed');
    expect(find.byKey(const Key('flex_vs_fixed')), findsOneWidget);
    expect(find.text('Fixed'), findsWidgets);
    expect(find.text('Flexible'), findsWidgets);
  });

  testWidgets('reduced motion jumps straight to the chart', (tester) async {
    await _pump(tester, reduceMotion: true);
    await tester.tap(find.byKey(const Key('chart-dot-forecast')));
    // One frame is enough: there is no page animation to wait for.
    await tester.pump();
    await tester.pump();
    expect(_title(tester), 'Cash-flow forecast');
  });

  for (final dark in [false, true]) {
    testWidgets(
      'every chart fits 360px at text scale 1.5 (${dark ? 'dark' : 'light'})',
      (tester) async {
        await _pump(
          tester,
          size: const Size(360, 640),
          dpr: 2,
          textScale: 1.5,
          brightness: dark ? Brightness.dark : Brightness.light,
        );
        expect(tester.takeException(), isNull);
        for (final c in BudgetChart.values) {
          final dot = find.byKey(Key('chart-dot-${c.key}'));
          await Scrollable.ensureVisible(tester.element(dot), alignment: 0.4);
          await tester.pump(const Duration(milliseconds: 600));
          await tester.tap(dot);
          await _pumpMs(tester, 600);
          expect(_title(tester), c.title);
          expect(tester.takeException(), isNull, reason: c.key);
        }
      },
    );
  }
}
